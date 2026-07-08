import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final int initialJuz;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.initialJuz,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  List<String> verses = [];
  List<String> tafsirVerses = [];
  List<dynamic> juzData = [];
  bool isLoading = true;
  bool _showTafsir = false;
  int currentJuz = 1;
  
  // التحكم في التصفح الورقي (صفحة تلو الأخرى)
  final PageController _pageController = PageController();
  Timer? _scrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 0.1; 

  // التحكم الديناميكي بحجم الخط
  double _fontSize = 24.0;
  int _themeMode = 0; 

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // تحديث الجزء الحالي ديناميكيًا عند تغيير الصفحة (الآية)
  void _onPageChanged(int index) {
    if (juzData.isEmpty || verses.isEmpty) return;

    int currentVerseNum = index + 1;

    for (var juz in juzData) {
      int juzNumber = int.tryParse(juz['juz_number'].toString()) ?? 1;
      var surahs = juz['surahs'] as Map<String, dynamic>?;
      
      if (surahs != null && surahs.containsKey(widget.surahId.toString())) {
        var range = surahs[widget.surahId.toString()] as List<dynamic>?;
        if (range != null && range.length == 2) {
          int startVerse = int.tryParse(range[0].toString()) ?? 1;
          int endVerse = int.tryParse(range[1].toString()) ?? widget.versesCount;

          if (currentVerseNum >= startVerse && currentVerseNum <= endVerse) {
            if (currentJuz != juzNumber) {
              setState(() {
                currentJuz = juzNumber;
              });
            }
            break;
          }
        }
      }
    }
  }

  // الانتقال السلس إلى آية محددة في العرض الورقي
  void _scrollToVerse(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  // نافذة اختيار رقم الآية للذهاب إليها بتصميم وألوان محسنة ومتناسقة
  void _showGoToVerseDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = _themeMode == 2;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "الذهاب إلى آية", 
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2C3E50)),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "أدخل رقم الآية (1 - ${verses.length})",
              hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                int? verseNum = int.tryParse(controller.text);
                if (verseNum != null && verseNum >= 1 && verseNum <= verses.length) {
                  Navigator.pop(context);
                  _scrollToVerse(verseNum - 1);
                }
              },
              child: const Text("اذهب الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // التمرير الآلي للصفحات تلقائياً بناءً على السرعة المحددة
  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      int durationMilliseconds = (3000 / _scrollSpeed).round();
      _scrollTimer = Timer.periodic(Duration(milliseconds: durationMilliseconds), (timer) {
        if (_pageController.hasClients) {
          int nextPage = _pageController.page!.round() + 1;
          if (nextPage >= verses.length) {
            timer.cancel();
            setState(() => _isAutoScrolling = false);
          } else {
            _pageController.animateToPage(
              nextPage,
              duration: const Duration(milliseconds: 800),
              curve: Curves.linear,
            );
          }
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  Future<void> _loadData() async {
    try {
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final data = json.decode(response);
      final Map<String, dynamic> verseMap = data['verse'];
      
      List<String> loadedVerses = [];
      for (int i = 0; i < verseMap.length; i++) {
        String key = 'verse_$i';
        if (verseMap.containsKey(key)) {
          String text = verseMap[key].toString().trim();
          
          if (widget.surahId != 1 && widget.surahId != 9) {
            final RegExp basmalahRegExp = RegExp(
              r'^بِ_?سْ_?مِ_?\s+اللَّ_?ه_?\s+الرَّ_?حْ_?مَ_?نِ_?\s+الرَّ_?حِ_?يمِ_?\s*|^بِسْمِ\s+اللَّهِ\s+الرَّحْمَنِ\s+الرَّحِيمِ\s*|^بِسْمِ\s+اللَّهِ\s+الرَّحْمَٰنِ\s+الرَّحِيمِ\s*',
              caseSensitive: false,
            );
            
            text = text.replaceAll("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ", "").trim();
            text = text.replaceAll("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", "").trim();
            text = text.replaceFirst(basmalahRegExp, "").trim();
          }
          
          if (text.isEmpty && i == 0) continue;
          loadedVerses.add(text);
        }
      }

      try {
        final String tafsirResponse = await rootBundle.loadString('assets/translation/ar/surah_${widget.surahId}.json');
        final tafsirData = json.decode(tafsirResponse);
        final Map<String, dynamic> tafsirMap = tafsirData['verse'] ?? {};
        List<String> loadedTafsir = [];
        
        for (int i = 0; i < tafsirMap.length; i++) {
          String key = 'verse_$i';
          if (tafsirMap.containsKey(key)) {
            loadedTafsir.add(tafsirMap[key].toString().trim());
          }
        }
        if (verseMap.containsKey('verse_0') && loadedTafsir.isNotEmpty && widget.surahId != 1 && widget.surahId != 9) {
          loadedTafsir.removeAt(0);
        }
        tafsirVerses = loadedTafsir;
      } catch (_) {
        tafsirVerses = [];
      }

      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        verses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
        isLoading = false;
      });
    }
  }

  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFFDF6E3); // دافئ (Sepia)
    if (_themeMode == 2) return const Color(0xFF121212); // ليلي
    return const Color(0xFFF8F9FA); // فاتح نقّي
  }

  Color _getTextColor() {
    if (_themeMode == 2) return const Color(0xFFE0E0E0);
    if (_themeMode == 1) return const Color(0xFF5B4636);
    return const Color(0xFF2C3E50);
  }

  String toArabicNumerals(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String input = number.toString();
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  // الواجهة السفلية المُحدثة والمُصلحة بالكامل للأيقونات وحجم الخط
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _themeMode == 2;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    
                    // تحجيم حجم الخط (+ / -) مع إصلاح تمرير الألوان
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("حجم خط القراءة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline, 
                                color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                              ),
                              onPressed: () {
                                if (_fontSize > 16) {
                                  setState(() => _fontSize -= 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                            Text(
                              toArabicNumerals(_fontSize.round()),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline, 
                                color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                              ),
                              onPressed: () {
                                if (_fontSize < 42) {
                                  setState(() => _fontSize += 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 16),
                    
                    // خيار عرض التفسير
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("وضع التفسير الميسر", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: const Text("عرض التفسير المعتمد أسفل كل آية كترجمة ميسرة", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: _showTafsir,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        setState(() => _showTafsir = val);
                        setModalState(() => _showTafsir = val);
                      },
                    ),
                    const Divider(height: 16),
                    
                    // خيار وضع القراءة والوضوح
                    Text("وضع القراءة والوضوح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(
                          label: const Text("فاتح"), 
                          selected: _themeMode == 0, 
                          selectedColor: const Color(0xFFE8F5E9),
                          labelStyle: TextStyle(color: _themeMode == 0 ? const Color(0xFF2E7D32) : Colors.grey),
                          onSelected: (s) { setState(() => _themeMode = 0); setModalState(() {}); }
                        ),
                        ChoiceChip(
                          label: const Text("دافئ"), 
                          selected: _themeMode == 1, 
                          selectedColor: const Color(0xFFFFECB3),
                          labelStyle: TextStyle(color: _themeMode == 1 ? const Color(0xFF5B4636) : Colors.grey),
                          onSelected: (s) { setState(() => _themeMode = 1); setModalState(() {}); }
                        ),
                        ChoiceChip(
                          label: const Text("ليلي"), 
                          selected: _themeMode == 2, 
                          selectedColor: const Color(0xFF37474F),
                          labelStyle: TextStyle(color: _themeMode == 2 ? Colors.white : Colors.grey),
                          onSelected: (s) { setState(() => _themeMode = 2); setModalState(() {}); }
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    
                    // خيار التمرير الآلي للصفحات الورقية
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("التقليب التلقائي للصفحات:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAutoScrolling ? Colors.red.shade700 : const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                          ),
                          onPressed: () {
                            _toggleAutoScroll();
                            setModalState(() {});
                          },
                          icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 18),
                          label: Text(_isAutoScrolling ? "إيقاف" : "تشغيل", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _scrollSpeed, min: 0.1, max: 1.0, divisions: 9,
                      activeColor: const Color(0xFF2E7D32),
                      inactiveColor: Colors.grey.shade300,
                      label: "السرعة: $_scrollSpeed",
                      onChanged: (v) {
                        setModalState(() => _scrollSpeed = v);
                        setState(() => _scrollSpeed = v);
                        if (_isAutoScrolling) {
                          _scrollTimer?.cancel();
                          _isAutoScrolling = false;
                          _toggleAutoScroll();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == 2;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.surahId == 2 ? 'البَقَرَةِ' : widget.surahName,
                    style: const TextStyle(fontFamily: 'nam', fontSize: 24, color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "آياتها: ${widget.versesCount}", 
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "الجزء $currentJuz", 
                    style: const TextStyle(fontFamily: 'jzu12', fontSize: 16, color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 22),
                    tooltip: "ذهاب إلى آية",
                    onPressed: _showGoToVerseDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    tooltip: "خيارات العرض",
                    onPressed: _showSettingsBottomSheet,
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
            ),
          ),
          elevation: 0,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: verses.length,
                itemBuilder: (context, index) {
                  final String arabicNum = toArabicNumerals(index + 1);
                  final String currentTafsir = (index < tafsirVerses.length) ? tafsirVerses[index] : "التفسير الميسر لهذه الآية غير متوفر حالياً.";

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index == 0 && widget.surahId != 1 && widget.surahId != 9) ...[
                          Center(
                            child: Text(
                              "19", 
                              style: TextStyle(fontFamily: 'bsm60', fontSize: 85, color: const Color(0xFF2E7D32).withOpacity(0.9)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        
                        Card(
                          elevation: isDark ? 0 : 2,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${verses[index]} ",
                                        style: TextStyle(
                                          fontSize: _fontSize,
                                          fontFamily: 'nss', 
                                          height: 2.3,
                                          color: _getTextColor(),
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      TextSpan(
                                        text: " ﴿$arabicNum﴾ ", 
                                        style: TextStyle(
                                          fontFamily: 'quran_num', 
                                          fontSize: 24, 
                                          color: isDark ? const Color(0xFFFFD700) : const Color(0xFFC19A6B)
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        if (_showTafsir) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B281E) : const Color(0xFFE8F5E9).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.transparent : const Color(0xFFC8E6C9).withOpacity(0.5),
                                width: 1
                              )
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "التفسير الميسر:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currentTafsir,
                                  style: TextStyle(
                                    fontSize: _fontSize - 6,
                                    height: 1.8,
                                    color: isDark ? Colors.white70 : const Color(0xFF37474F),
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
