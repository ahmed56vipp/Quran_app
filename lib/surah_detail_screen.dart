import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final List<dynamic> juzData;

  const SurahDetailScreen({
    super.key, 
    required this.surahId, 
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.juzData,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  
  double _fontSize = 24.0;
  late Future<Map<String, dynamic>> _surahDataFuture;
  List<String> _currentVerses = [];
  String _errorMessage = '';
  String _currentJuzTitle = '';

  Map<String, dynamic>? _tafsirArData;
  Map<String, dynamic>? _translationEnData;
  Map<String, dynamic>? _translationIdData;

  // متغيرات ميزة القراءة الآلية المتطورة
  bool _isFullScreen = false;
  bool _isAutoScrolling = false;
  double _baseScrollSpeed = 1.2; // السرعة القياسية الأساسية
  double _scrollSpeedMultiplier = 0.1; // تبدأ السرعة الآن من 0.1 كحد أدنى بدلاً من 1.0
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _saveLastReadPosition();
    _surahDataFuture = loadSurahData();
    _preloadTafsirAndTranslations();
    
    _scrollController.addListener(() {
      _updateJuzTitleBasedOnScroll();
    });
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
    });
  }

  // تشغيل المحرك الديناميكي للقراءة الآلية
  void _startAutoScroll() {
    _scrollTimer?.cancel();
    setState(() {
      _isAutoScrolling = true;
    });
    
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_scrollController.hasClients && _isAutoScrolling) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.position.pixels;
        
        if (currentScroll >= maxScroll) {
          _stopAutoScroll();
        } else {
          // السرعة النهائية = السرعة الأساسية مضروبة في المعامل المتغير (يبدأ التأثير السلس من 0.1)
          double finalSpeed = _baseScrollSpeed * _scrollSpeedMultiplier;
          _scrollController.jumpTo(currentScroll + finalSpeed);
        }
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    if (mounted) {
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  Future<void> _saveLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_verses_count', widget.versesCount);
    await prefs.setString('last_surah_type', widget.surahType);
  }

  Future<Map<String, dynamic>> loadSurahData() async {
    try {
      final textResponse = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final textData = json.decode(textResponse);
      
      Map<String, dynamic> versesMap = {};
      if (textData is Map) {
        versesMap = textData.containsKey('verse') 
            ? Map<String, dynamic>.from(textData['verse']) 
            : Map<String, dynamic>.from(textData);
      }

      List<String> allVerses = [];
      for (int i = 1; i <= widget.versesCount; i++) {
        String keyStr = i.toString();
        String keyVerseStr = 'verse_$i';
        
        if (versesMap.containsKey(keyStr)) {
          allVerses.add(versesMap[keyStr].toString().trim());
        } else if (versesMap.containsKey(keyVerseStr)) {
          allVerses.add(versesMap[keyVerseStr].toString().trim());
        }
      }

      if (allVerses.isNotEmpty && widget.surahId != 1 && widget.surahId != 9) {
        String firstVerse = allVerses[0];
        final basmalahPattern = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ";
        if (firstVerse.startsWith(basmalahPattern)) {
          allVerses[0] = firstVerse.substring(basmalahPattern.length).trim();
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentVerses = allVerses;
            _updateJuzTitleBasedOnScroll();
          });
        }
      });

      return {
        'verses': allVerses,
      };
    } catch (e) {
      setState(() {
        _errorMessage = "لم يتم العثور على ملف السورة رقم ${widget.surahId}.";
      });
      return {'verses': <String>[]};
    }
  }

  void _updateJuzTitleBasedOnScroll() {
    if (_currentVerses.isEmpty || widget.juzData.isEmpty) return;

    double offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    double maxExtent = _scrollController.hasClients ? _scrollController.position.maxScrollExtent : 1.0;
    if (maxExtent <= 0) maxExtent = 1.0;

    double ratio = offset / maxExtent;
    int estimatedIndex = (ratio * _currentVerses.length).floor();
    if (estimatedIndex >= _currentVerses.length) estimatedIndex = _currentVerses.length - 1;
    if (estimatedIndex < 0) estimatedIndex = 0;

    int currentVerseNum = estimatedIndex + 1;
    String detectedJuz = '';

    for (var juz in widget.juzData) {
      int startSurah = int.tryParse(juz['start']['index'].toString()) ?? 0;
      int endSurah = int.tryParse(juz['end']['index'].toString()) ?? 0;
      
      String startVerseRaw = juz['start']['verse'].toString().replaceAll('verse_', '');
      String endVerseRaw = juz['end']['verse'].toString().replaceAll('verse_', '');
      int startVerse = int.tryParse(startVerseRaw) ?? 0;
      int endVerse = int.tryParse(endVerseRaw) ?? 0;
      
      int juzIndex = int.tryParse(juz['index'].toString()) ?? 0;

      if (widget.surahId > startSurah && widget.surahId < endSurah) {
        detectedJuz = "الجزء ${toArabicNumerals(juzIndex)}";
        break;
      } else if (widget.surahId == startSurah && widget.surahId == endSurah) {
        if (currentVerseNum >= startVerse && currentVerseNum <= endVerse) {
          detectedJuz = "الجزء ${toArabicNumerals(juzIndex)}";
          break;
        }
      } else if (widget.surahId == startSurah) {
        if (currentVerseNum >= startVerse) {
          detectedJuz = "الجزء ${toArabicNumerals(juzIndex)}";
          break;
        }
      } else if (widget.surahId == endSurah) {
        if (currentVerseNum <= endVerse) {
          detectedJuz = "الجزء ${toArabicNumerals(juzIndex)}";
          break;
        }
      }
    }

    if (detectedJuz.isNotEmpty && detectedJuz != _currentJuzTitle) {
      setState(() {
        _currentJuzTitle = detectedJuz;
      });
    }
  }

  Future<void> _preloadTafsirAndTranslations() async {
    try {
      final arString = await rootBundle.loadString('assets/translation/ar/ar_translation_${widget.surahId}.json');
      _tafsirArData = json.decode(arString);
    } catch (_) {}
    try {
      final enString = await rootBundle.loadString('assets/translation/en/en_translation_${widget.surahId}.json');
      _translationEnData = json.decode(enString);
    } catch (_) {}
    try {
      final idString = await rootBundle.loadString('assets/translation/id/id_translation_${widget.surahId}.json');
      _translationIdData = json.decode(idString);
    } catch (_) {}
  }

  String _getTafsirOrTranslationText(Map<String, dynamic>? data, int verseNum) {
    if (data == null) return "النص غير متوفر حالياً.";
    var verseMap = data['verse'] ?? data;
    if (verseMap is Map) {
      if (verseMap.containsKey('verse_$verseNum')) {
        return verseMap['verse_$verseNum'].toString();
      } else if (verseMap.containsKey(verseNum.toString())) {
        return verseMap[verseNum.toString()].toString();
      }
    }
    return "النص غير متوفر لهذه الآية.";
  }

  void _showTafsirBottomSheet(String verseText, int verseNum) {
    final String tafsirAr = _getTafsirOrTranslationText(_tafsirArData, verseNum);
    final String transEn = _getTafsirOrTranslationText(_translationEnData, verseNum);
    final String transId = _getTafsirOrTranslationText(_translationIdData, verseNum);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "الآية (${toArabicNumerals(verseNum)})",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFDFBF7), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.2))),
                      child: Text(verseText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontFamily: 'ahmed', height: 1.8, color: Colors.black87)),
                    ),
                    const Divider(height: 30, thickness: 1),
                    _buildSectionTitle('التفسير الميسر', Icons.menu_book),
                    _buildSectionContent(tafsirAr, isArabic: true),
                    const SizedBox(height: 18),
                    _buildSectionTitle('English Translation', Icons.g_translate),
                    _buildSectionContent(transEn, isArabic: false),
                    const SizedBox(height: 18),
                    _buildSectionTitle('Terjemahan Indonesia', Icons.translate),
                    _buildSectionContent(transId, isArabic: false),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(children: [Icon(icon, color: Colors.green[700], size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700], fontFamily: 'ahmed'))]);
  }

  Widget _buildSectionContent(String content, {required bool isArabic}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Text(content, textAlign: isArabic ? TextAlign.justify : TextAlign.left, textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[800], fontFamily: isArabic ? 'ahmed' : null)),
    );
  }

  void _goToVerse(int verseNumber) {
    if (_currentVerses.isEmpty) return;
    if (verseNumber < 1 || verseNumber > _currentVerses.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رقم الآية غير صحيح! السورة تحتوي على ${_currentVerses.length} آية.', style: const TextStyle(fontFamily: 'ahmed'))));
      return;
    }
    int totalCharacters = _currentVerses.fold(0, (sum, verse) => sum + verse.length);
    int targetCharacters = 0;
    for (int i = 0; i < verseNumber - 1; i++) {
      targetCharacters += _currentVerses[i].length;
    }
    double ratio = totalCharacters > 0 ? (targetCharacters / totalCharacters) : 0.0;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;
    _scrollController.animateTo(targetOffset, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
  }

  void _showGoToVerseDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الذهاب إلى آية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
        content: TextField(
          controller: inputController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(hintText: 'أدخل رقم الآية (1 - ${_currentVerses.length})', hintStyle: const TextStyle(fontFamily: 'ahmed', fontSize: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'ahmed'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () {
              final int? verseNum = int.tryParse(inputController.text);
              Navigator.pop(context);
              if (verseNum != null) _goToVerse(verseNum);
            },
            child: const Text('ذهاب', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'ahmed')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _isFullScreen ? null : AppBar(
          centerTitle: false, 
          backgroundColor: const Color(0xFF2E7D32), 
          foregroundColor: Colors.white,
          toolbarHeight: 90, 
          elevation: 2,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("سورة ${widget.surahName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.white)),
                  Text(" (${widget.surahType})", style: const TextStyle(fontSize: 14, fontFamily: 'ahmed', color: Colors.white70)),
                  if (_currentJuzTitle.isNotEmpty) ...[
                    const Text(" | ", style: TextStyle(fontSize: 16, color: Colors.white30)),
                    Text(_currentJuzTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.amber)),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Text("آياتها: ${toArabicNumerals(widget.versesCount)}", style: const TextStyle(fontSize: 14, fontFamily: 'ahmed', color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.find_in_page, size: 24),
              tooltip: 'الذهاب إلى آية',
              onPressed: _currentVerses.isEmpty ? null : _showGoToVerseDialog,
            ),
            IconButton(
              icon: const Icon(Icons.tune, size: 24),
              tooltip: 'لوحة التحكم والتبويب الجانبي',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
        
        endDrawer: Drawer(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: Colors.green[800], size: 28),
                      const SizedBox(width: 10),
                      Text('خيارات التحكم والإضافات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed')),
                    ],
                  ),
                  const Divider(height: 30, thickness: 1.2),
                  
                  // أولاً: إعداد حجم الخط
                  Text('حجم خط القراءة الحالي: ${_fontSize.toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                        onPressed: () => setState(() => _fontSize += 2),
                        child: const Text('A+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                        onPressed: () => setState(() => _fontSize = (_fontSize > 16) ? _fontSize - 2 : _fontSize),
                        child: const Text('A-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  // ثانياً: مفتاح التحكم الذكي بالقراءة الآلية ومؤشر السرعة المطور من 0.1
                  Row(
                    children: [
                      Text('▲ محرك التمرير الآلي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: Colors.grey[100],
                    leading: Icon(_isAutoScrolling ? Icons.pause_circle_filled : Icons.swipe_vertical, color: Colors.green[800]),
                    title: Text(_isAutoScrolling ? "إيقاف القراءة الحالية" : "حرك الشريط بالأسفل للبدء", style: const TextStyle(fontSize: 14, fontFamily: 'ahmed')),
                    onTap: () {
                      if (_isAutoScrolling) {
                        _stopAutoScroll();
                      } else {
                        // تلبية لطلبك: الضغط هنا لا يبدأ القراءة بل يوجه المستخدم لتحريك الشريط لبدء آمن وسلس
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى تحريك شريط السرعة في الأسفل لتبدأ القراءة تلقائياً.', style: TextStyle(fontFamily: 'ahmed')),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سرعة التمرير:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
                      Text(
                        "${_scrollSpeedMultiplier.toStringAsFixed(1)}x ${_scrollSpeedMultiplier >= 2.0 ? '(max x 2)' : ''}", 
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _scrollSpeedMultiplier >= 2.0 ? Colors.red : Colors.green[800], fontFamily: 'ahmed')
                      ),
                    ],
                  ),
                  Slider(
                    value: _scrollSpeedMultiplier,
                    min: 0.1, // تبدأ القراءة والسرعة من 0.1 تماماً
                    max: 2.0, // الحد الأقصى المتفق عليه 2x
                    divisions: 19, // تقسيم دقيق يضمن التنقل بمقدار 0.1 في كل خطوة
                    activeColor: Colors.green[800],
                    inactiveColor: Colors.grey[300],
                    label: "${_scrollSpeedMultiplier.toStringAsFixed(1)}x",
                    onChanged: (value) {
                      setState(() {
                        _scrollSpeedMultiplier = value;
                        // التعديل الجوهري: بمجرد تحريك الشريط تبدأ القراءة والتحريك الفوري دون الحاجة لزر التشغيل
                        if (!_isAutoScrolling) {
                          _startAutoScroll();
                        }
                      });
                    },
                  ),
                  const Divider(height: 30, thickness: 1.2),

                  // ثالثاً: وضع ملء الشاشة
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: Colors.grey[100],
                    leading: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.blueGrey),
                    title: Text(_isFullScreen ? "إلغاء ملء الشاشة" : "وضع ملء الشاشة الكامل", style: const TextStyle(fontSize: 14, fontFamily: 'ahmed')),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleFullScreen();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        body: Stack(
          children: [
            _errorMessage.isNotEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(_errorMessage, style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'ahmed'), textAlign: TextAlign.center)))
                : FutureBuilder<Map<String, dynamic>>(
                    future: _surahDataFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final versesList = snapshot.data!['verses'] as List<String>;

                      return GestureDetector(
                        onTap: () {
                          if (_isAutoScrolling) {
                            _stopAutoScroll();
                          }
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            _updateJuzTitleBasedOnScroll();
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: 20, 
                              right: 20, 
                              top: _isFullScreen ? 50 : 20, 
                              bottom: 60
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.surahId != 9)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 24, top: 10),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDFBF7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE0D0B0), width: 1),
                                    ),
                                    child: const Text(
                                      "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                                      style: TextStyle(fontSize: 26, fontFamily: 'ahmed', height: 1.8, color: Colors.black87),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                Text.rich(
                                  TextSpan(
                                    children: List.generate(versesList.length, (index) {
                                      final int actualVerseNum = index + 1;
                                      final String rawVerseText = versesList[index];

                                      return TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "$rawVerseText ",
                                            style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.3, color: Colors.black),
                                          ),
                                          TextSpan(
                                            text: " ﴿${toArabicNumerals(actualVerseNum)}﴾ ",
                                            style: TextStyle(fontSize: _fontSize - 4, fontFamily: 'ahmed', color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            if (_isFullScreen)
              Positioned(
                left: 20,
                top: 20,
                child: Opacity(
                  opacity: 0.5,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    onPressed: _toggleFullScreen,
                    child: const Icon(Icons.fullscreen_exit),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
