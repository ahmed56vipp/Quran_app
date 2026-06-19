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
  double _fontSize = 24.0;
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _surahDataFuture;
  List<String> _currentVerses = [];
  String _errorMessage = '';
  String _currentJuzTitle = '';

  Map<String, dynamic>? _tafsirArData;
  Map<String, dynamic>? _translationEnData;
  Map<String, dynamic>? _translationIdData;

  // متغيرات الميزات الجديدة
  bool _isFullScreen = false;
  bool _isAutoScrolling = false;
  bool _showSidebar = false;
  double _scrollSpeed = 2.0; // سرعة التمرير (بكسل في الثانية)
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
    // إعادة النظام لوضعه الطبيعي عند الخروج من الصفحة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // تفعيل وإلغاء وضع ملء الشاشة
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

  // إدارة القراءة الآلية (التمرير التلقائي)
  void _startAutoScroll() {
    _stopAutoScroll();
    setState(() {
      _isAutoScrolling = true;
    });
    // تايمر يتكرر كل 50 ميلي ثانية لتوفير تمرير سلس ونظيف (Smooth Scroll)
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.position.pixels;
        
        if (currentScroll >= maxScroll) {
          _stopAutoScroll();
        } else {
          // حساب المسافة المقطوعة بناءً على السرعة المحددة
          double nextScroll = currentScroll + (_scrollSpeed * 0.05);
          _scrollController.jumpTo(nextScroll);
        }
      }
    });
  }

  void _stopAutoScroll() {
    if (_scrollTimer != null && _scrollTimer!.isActive) {
      _scrollTimer!.cancel();
    }
    if (mounted) {
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
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
        if (textData.containsKey('verse')) {
          versesMap = Map<String, dynamic>.from(textData['verse']);
        } else {
          versesMap = Map<String, dynamic>.from(textData);
        }
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

      if (allVerses.isEmpty && versesMap.isNotEmpty) {
        var sortedKeys = versesMap.keys.toList()..sort((a, b) {
          int intA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          int intB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return intA.compareTo(intB);
        });
        for (var key in sortedKeys) {
          allVerses.add(versesMap[key].toString().trim());
        }
      }
      
      String? basmalah;
      List<String> dynamicVerses = [];

      if (widget.surahId == 1 || widget.surahId == 9) {
        dynamicVerses = allVerses;
      } else {
        if (allVerses.isNotEmpty && (allVerses[0].contains("بِسْمِ") || allVerses[0].startsWith("بِسمِ"))) {
          basmalah = allVerses[0];
          dynamicVerses = allVerses.sublist(1);
        } else {
          dynamicVerses = allVerses;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentVerses = dynamicVerses;
            _updateJuzTitleBasedOnScroll();
          });
        }
      });

      return {
        'basmalah': basmalah,
        'verses': dynamicVerses,
      };
    } catch (e) {
      setState(() {
        _errorMessage = "لم يتم العثور على ملف السورة رقم ${widget.surahId}.";
      });
      return {'basmalah': null, 'verses': <String>[]};
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
      setState(() {
        _tafsirArData = json.decode(arString);
      });
    } catch (_) {}

    try {
      final enString = await rootBundle.loadString('assets/translation/en/en_translation_${widget.surahId}.json');
      setState(() {
        _translationEnData = json.decode(enString);
      });
    } catch (_) {}

    try {
      final idString = await rootBundle.loadString('assets/translation/id/id_translation_${widget.surahId}.json');
      setState(() {
        _translationIdData = json.decode(idString);
      });
    } catch (_) {}
  }

  String _getTafsirOrTranslationText(Map<String, dynamic>? data, int verseNum) {
    if (data == null) return "النص غير متوفر حالياً.";
    
    var verseMap = data['verse'] ?? data;
    if (verseMap is Map) {
      if (verseMap.containsKey('verse_$verseNum')) {
        return verseMap['verse_$verseNum'].toString();
      } else if (verseMap.containsKey('verse_${verseNum - 1}')) {
        return verseMap['verse_${verseNum - 1}'].toString();
      } else if (verseMap.containsKey(verseNum.toString())) {
        return verseMap[verseNum.toString()].toString();
      }
    } else if (verseMap is List && (verseNum - 1) < verseMap.length) {
      return verseMap[verseNum - 1].toString();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Text(
                        verseText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontFamily: 'ahmed', height: 1.8, color: Colors.black87),
                      ),
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
    return Row(
      children: [
        Icon(icon, color: Colors.green[700], size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700], fontFamily: 'ahmed'),
        ),
      ],
    );
  }

  Widget _buildSectionContent(String content, {required bool isArabic}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Text(
        content,
        textAlign: isArabic ? TextAlign.justify : TextAlign.left,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Colors.grey[800],
          fontFamily: isArabic ? 'ahmed' : null,
        ),
      ),
    );
  }

  void _goToVerse(int verseNumber) {
    if (_currentVerses.isEmpty) return;

    if (verseNumber < 1 || verseNumber > _currentVerses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم الآية غير صحيح! السورة تحتوي على ${_currentVerses.length} آية.', style: const TextStyle(fontFamily: 'ahmed'))),
      );
      return;
    }

    int totalCharacters = _currentVerses.fold(0, (sum, verse) => sum + verse.length);
    int targetCharacters = 0;
    for (int i = 0; i < verseNumber - 1; i++) {
      targetCharacters += _currentVerses[i].length;
    }

    double ratio = totalCharacters > 0 ? (targetCharacters / totalCharacters) : 0.0;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
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
          decoration: InputDecoration(
            hintText: 'أدخل رقم الآية (1 - ${_currentVerses.length})',
            hintStyle: const TextStyle(fontFamily: 'ahmed', fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'ahmed')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () {
              final int? verseNum = int.tryParse(inputController.text);
              Navigator.pop(context);
              if (verseNum != null) {
                _goToVerse(verseNum);
              }
            },
            child: const Text('ذهاب', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'ahmed')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // إخفاء الـ AppBar اختيارياً في وضع ملء الشاشة
      appBar: _isFullScreen ? null : AppBar(
        centerTitle: false, 
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        toolbarHeight: 85, 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "سورة ${widget.surahName}", 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  "(${widget.surahType})", 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, fontFamily: 'ahmed', color: Colors.white70),
                ),
                if (_currentJuzTitle.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    "| $_currentJuzTitle", 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.amber),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "آياتها: ${toArabicNumerals(widget.versesCount)}",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal, fontFamily: 'ahmed', color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showSidebar ? Icons.auto_stories : Icons.play_circle_outline, size: 26, color: Colors.white),
            tooltip: 'شريط القراءة الآلية',
            onPressed: () {
              setState(() {
                _showSidebar = !_showSidebar;
                if (!_showSidebar) _stopAutoScroll();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 26, color: Colors.white),
            tooltip: 'وضع ملء الشاشة',
            onPressed: _toggleFullScreen,
          ),
          IconButton(
            icon: const Icon(Icons.find_in_page, size: 26, color: Colors.white),
            tooltip: 'الذهاب إلى آية',
            onPressed: _currentVerses.isEmpty ? null : _showGoToVerseDialog,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.text_fields, size: 26, color: Colors.white),
              tooltip: 'إعدادات الخط',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
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
                    Icon(Icons.text_fields, color: Colors.green[800], size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'إعدادات الخط',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed'),
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1.2),
                Text(
                  'حجم خط القراءة الحالي: ${_fontSize.toInt()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'ahmed'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize += 2),
                      child: const Text('A+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize = (_fontSize > 16) ? _fontSize - 2 : _fontSize),
                      child: const Text('A-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      // تداخل العناصر لإتاحة وجود الشريط الجانبي والزر العائم الخاص بملء الشاشة
      body: Stack(
        children: [
          _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'ahmed'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : FutureBuilder<Map<String, dynamic>>(
                  future: _surahDataFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final basmalahText = snapshot.data!['basmalah'] as String?;
                    final versesList = snapshot.data!['verses'] as List<String>;

                    if (versesList.isEmpty && _errorMessage.isEmpty) {
                      return const Center(child: Text("جاري تحميل آيات السورة...", style: TextStyle(fontFamily: 'ahmed')));
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        _updateJuzTitleBasedOnScroll();
                        return false;
                      },
                      child: SingleChildScrollView(
                        key: const Key('surah_scroll'), // تم نقله هنا بنجاح لإصلاح الخطأ
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: _showSidebar ? 80 : 20, // إضافة مساحة إضافية حتى لا يغطي الشريط الجانبي على النص الكريّم
                          right: 20, 
                          top: _isFullScreen ? 40 : 24, 
                          bottom: 40
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (basmalahText != null)
                              GestureDetector(
                                onTap: () => _showTafsirBottomSheet(basmalahText, 1),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4EDE2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                                  ),
                                  child: Text(
                                    basmalahText,
                                    style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text.rich(
                                TextSpan(
                                  children: List.generate(versesList.length, (index) {
                                    final int actualVerseNum = (basmalahText != null) ? (index + 2) : (index + 1);
                                    final String rawVerseText = versesList[index];

                                    return TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "$rawVerseText ",
                                          style: TextStyle(
                                            fontSize: _fontSize, 
                                            fontFamily: 'ahmed', 
                                            height: 2.3, 
                                            color: Colors.black87
                                          ),
                                        ),
                                        TextSpan(
                                          text: "﴿${toArabicNumerals(actualVerseNum)}﴾ ",
                                          style: TextStyle(
                                            fontSize: _fontSize - 3, 
                                            fontFamily: 'ahmed', 
                                            color: Colors.green[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 1. الشريط الجانبي الذكي للقراءة الآلية (Sidebar Control)
          if (_showSidebar)
            Positioned(
              left: 10,
              top: MediaQuery.of(context).size.height * 0.25,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(30),
                color: Colors.green[800]!.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر التشغيل والإيقاف المؤقت
                      IconButton(
                        icon: Icon(_isAutoScrolling ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36, color: Colors.white),
                        onPressed: _toggleAutoScroll,
                      ),
                      const SizedBox(height: 12),
                      // زر تسريع التمرير
                      IconButton(
                        icon: const Icon(Icons.fast_forward, size: 26, color: Colors.white),
                        tooltip: 'تسريع القراءة الآلية',
                        onPressed: () {
                          setState(() {
                            _scrollSpeed = (_scrollSpeed < 15.0) ? _scrollSpeed + 1.0 : _scrollSpeed;
                            if (_isAutoScrolling) _startAutoScroll(); // إعادة التشغيل بالسرعة الجديدة
                          });
                        },
                      ),
                      // مؤشر السرعة الحالية
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          "${_scrollSpeed.toInt()}x",
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      // زر تبطئ القراءة
                      IconButton(
                        icon: const Icon(Icons.fast_rewind, size: 26, color: Colors.white),
                        tooltip: 'تبطئة القراءة الآلية',
                        onPressed: () {
                          setState(() {
                            _scrollSpeed = (_scrollSpeed > 1.0) ? _scrollSpeed - 1.0 : _scrollSpeed;
                            if (_isAutoScrolling) _startAutoScroll();
                          });
                        },
                      ),
                      const Divider(color: Colors.white54, height: 20, thickness: 1),
                      // زر لإغلاق الشريط الجانبي بسرعة
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _showSidebar = false;
                            _stopAutoScroll();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. زر عائم صغير وشفاف يظهر فقط في وضع ملء الشاشة للخروج منه وإظهار الـ AppBar مجدداً
          if (_isFullScreen)
            Positioned(
              right: 16,
              top: 16,
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
    );
  }
}
