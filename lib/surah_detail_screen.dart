import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'utils.dart';

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
  int currentJuz = 1;
  int selectedVerseIndex = 0;

  // متغيرات التمرير التلقائي وسرعته
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  double _scrollSpeed = 0.8; // سرعة افتراضية قابلة للتعديل

  final ScrollController _scrollController = ScrollController();
  double _fontSize = 20.0; // تصغير الخط قليلاً ليكون مناسباً كالمصحف
  int _themeMode = 0; 

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // تشغيل وإيقاف التمرير التلقائي بالسرعة المحددة
  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _autoScrollTimer?.cancel();
      setState(() => _isAutoScrolling = false);
    } else {
      setState(() => _isAutoScrolling = true);
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.offset;
          if (currentScroll >= maxScroll) {
            _autoScrollTimer?.cancel();
            setState(() => _isAutoScrolling = false);
          } else {
            _scrollController.jumpTo(currentScroll + _scrollSpeed);
          }
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      String response = '';
      try {
        response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}-json');
      } catch (_) {
        try {
          response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
        } catch (_) {}
      }

      Map<String, dynamic> verseMap = {};
      if (response.isNotEmpty) {
        final data = json.decode(response);
        if (data is Map) {
          if (data.containsKey('verse')) {
            var vData = data['verse'];
            if (vData is Map) {
              verseMap = Map<String, dynamic>.from(vData);
            } else if (vData is List) {
              for (int i = 0; i < vData.length; i++) {
                verseMap['verse_$i'] = vData[i];
              }
            }
          } else {
            verseMap = Map<String, dynamic>.from(data);
          }
        }
      }

      List<String> loadedVerses = [];
      var entries = verseMap.entries.toList();

      if (entries.isNotEmpty) {
        entries.sort((a, b) {
          int numA = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          int numB = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return numA.compareTo(numB);
        });

        for (int i = 0; i < entries.length; i++) {
          var entry = entries[i];
          String text = entry.value.toString().trim();
          if (text.isEmpty) continue;

          if (widget.surahId != 1 && widget.surahId != 9) {
            if (text.contains("بِسْمِ") || text.contains("بسم")) {
              continue; 
            }
          }
          loadedVerses.add(text);
        }
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
      }

      // تحميل التفسير الميسر المنفصل
      try {
        String tafsirResponse = '';
        List<String> possiblePaths = [
          'assets/translation/ar/ar_translation_${widget.surahId}-json',
          'assets/translation/ar/ar_translation_${widget.surahId}.json',
          'assets/translation/ar/surah_${widget.surahId}-json',
          'assets/translation/ar/surah_${widget.surahId}.json',
        ];
        
        for (var path in possiblePaths) {
          try {
            tafsirResponse = await rootBundle.loadString(path);
            if (tafsirResponse.isNotEmpty) break;
          } catch (_) {}
        }

        if (tafsirResponse.isNotEmpty) {
          final tafsirData = json.decode(tafsirResponse);
          Map<String, dynamic> tafsirMap = {};
          if (tafsirData is Map) {
            if (tafsirData.containsKey('verse')) {
              var tData = tafsirData['verse'];
              if (tData is Map) {
                tafsirMap = Map<String, dynamic>.from(tData);
              } else if (tData is List) {
                for (int i = 0; i < tData.length; i++) {
                  tafsirMap['verse_${i + 1}'] = tData[i];
                }
              }
            } else {
              tafsirMap = Map<String, dynamic>.from(tafsirData);
            }
          }

          var tafsirEntries = tafsirMap.entries.toList();
          tafsirEntries.sort((a, b) {
            int numA = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int numB = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return numA.compareTo(numB);
          });
          
          tafsirVerses = tafsirEntries.map((e) => e.value.toString().trim()).toList();
        }
      } catch (e) {
        debugPrint("خطأ في جلب التفسير: $e");
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
    if (_themeMode == 1) return const Color(0xFFFDF6E3); 
    if (_themeMode == 2) return const Color(0xFF121212); 
    return const Color(0xFFF8F9FA); 
  }

  Color _getTextColor() {
    if (_themeMode == 2) return const Color(0xFFE0E0E0);
    if (_themeMode == 1) return const Color(0xFF5B4636);
    return const Color(0xFF2C3E50);
  }

  // نافذة الذهاب إلى آية مع التمرير الفعلي الفوري
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
          title: Text("الذهاب إلى آية", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "أدخل رقم الآية (1 - ${verses.length})",
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () {
                int? vNum = int.tryParse(controller.text);
                if (vNum != null && vNum >= 1 && vNum <= verses.length) {
                  Navigator.pop(context);
                  setState(() => selectedVerseIndex = vNum - 1);
                  // حساب موقع تقريبي والانتقال إليه بسلاسة
                  if (_scrollController.hasClients) {
                    double targetOffset = (vNum / verses.length) * _scrollController.position.maxScrollExtent;
                    _scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              child: const Text("انتقال", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // حفظ العلامة المرجعية الفعالة مع رسالة واضحة
  Future<void> _saveBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_verse', selectedVerseIndex + 1);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("تم حفظ علامة مرجعية في سورة ${widget.surahName} - الآية ${selectedVerseIndex + 1}"),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // شاشة التفسير المنفصلة
  void _openTafsirScreen() {
    final isDark = _themeMode == 2;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                Text("التفسير الميسر - سورة ${widget.surahName}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2E7D32))),
                const Divider(height: 20),
                Expanded(
                  child: tafsirVerses.isEmpty
                      ? const Center(child: Text("التفسير غير متوفر لهذه السورة حالياً", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: tafsirVerses.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("الآية (${index + 1}):", style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    tafsirVerses[index],
                                    style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // قائمة الإعدادات والتحكم بالسرعة والخطوط
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
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("حجم خط القراءة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.white70 : const Color(0xFF2E7D32)),
                              onPressed: () {
                                if (_fontSize > 14) {
                                  setState(() => _fontSize -= 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                            Text(toArabicNumerals(_fontSize.round()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white70 : const Color(0xFF2E7D32)),
                              onPressed: () {
                                if (_fontSize < 36) {
                                  setState(() => _fontSize += 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 20),
                    // التحكم في سرعة التمرير التلقائي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("سرعة التمرير التلقائي:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                        Slider(
                          value: _scrollSpeed,
                          min: 0.2,
                          max: 3.0,
                          divisions: 14,
                          activeColor: const Color(0xFF2E7D32),
                          inactiveColor: Colors.grey[300],
                          label: _scrollSpeed.toStringAsFixed(1),
                          onChanged: (val) {
                            setState(() => _scrollSpeed = val);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book, color: Color(0xFF2E7D32)),
                      title: Text("فتح التفسير الميسر", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: const Text("عرض تفسير السورة بشكل منفصل", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        _openTafsirScreen();
                      },
                    ),
                    const Divider(height: 20),
                    Text("وضع العرض والوضوح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(
                          label: const Text("فاتح"), 
                          selected: _themeMode == 0, 
                          selectedColor: const Color(0xFFE8F5E9),
                          labelStyle: TextStyle(color: _themeMode == 0 ? const Color(0xFF2E7D32) : Colors.grey, fontWeight: FontWeight.bold),
                          onSelected: (s) { setState(() => _themeMode = 0); setModalState(() {}); }
                        ),
                        ChoiceChip(
                          label: const Text("دافئ"), 
                          selected: _themeMode == 1, 
                          selectedColor: const Color(0xFFFFECB3),
                          labelStyle: TextStyle(color: _themeMode == 1 ? const Color(0xFF5B4636) : Colors.grey, fontWeight: FontWeight.bold),
                          onSelected: (s) { setState(() => _themeMode = 1); setModalState(() {}); }
                        ),
                        ChoiceChip(
                          label: const Text("ليلي"), 
                          selected: _themeMode == 2, 
                          selectedColor: const Color(0xFF37474F),
                          labelStyle: TextStyle(color: _themeMode == 2 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                          onSelected: (s) { setState(() => _themeMode = 2); setModalState(() {}); }
                        ),
                      ],
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
              Expanded(
                child: Row(
                  children: [
                    // فرض استخدام خط surah_nam لاسم السورة النصي (مثل الفاتحة، البقرة)
                    Text(
                      widget.surahName,
                      style: const TextStyle(fontSize: 24, fontFamily: 'surah_nam', color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "(${widget.versesCount})", 
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // دمج جميع الإضافات داخل الشريط العلوي
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_isAutoScrolling ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFFFFD700), size: 22),
                    tooltip: _isAutoScrolling ? "إيقاف التمرير" : "التمرير التلقائي",
                    onPressed: _toggleAutoScroll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white, size: 20),
                    tooltip: "حفظ علامة مرجعية",
                    onPressed: _saveBookmark,
                  ),
                  IconButton(
                    icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 20),
                    tooltip: "الذهاب إلى آية",
                    onPressed: _showGoToVerseDialog,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentJuz.toString(), 
                      style: const TextStyle(fontSize: 15, fontFamily: 'jzu12', color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white, size: 20),
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
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.surahId != 9) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            "27", 
                            style: TextStyle(
                              fontFamily: 'bsm60',
                              fontSize: 55,
                              color: const Color(0xFF2E7D32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Card(
                      elevation: isDark ? 0 : 3,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              for (int i = 0; i < verses.length; i++) ...[
                                TextSpan(
                                  text: "${verses[i]} ",
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    fontFamily: 'nss', 
                                    height: 2.4,
                                    color: selectedVerseIndex == i ? const Color(0xFF2E7D32) : _getTextColor(),
                                    fontWeight: selectedVerseIndex == i ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: " ${(i + 1)} ", 
                                  style: TextStyle(
                                    fontFamily: 'quran_num', 
                                    fontSize: _fontSize * 0.9, 
                                    color: isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ]
                            ],
                          ),
                          textAlign: TextAlign.justify,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
