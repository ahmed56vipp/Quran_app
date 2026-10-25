import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showTafsir = false;
  int currentJuz = 1;
  
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
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

          // حذف البسملة نهائياً من نصوص الآيات الأساسية
          if (widget.surahId != 1 && widget.surahId != 9 && (entry.key == 'verse_0' || entry.key == '0' || i == 0)) {
            text = text
                .replaceAll(RegExp(r'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ|بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ|بسم الله الرحمن الرحيم'), '')
                .trim();
            if (text.isEmpty) {
              continue; 
            }
          }
          loadedVerses.add(text);
        }
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
      }

      // تحميل التفسير الميسر بدقة لتلافي مشكلة عدم عمله
      try {
        String tafsirResponse = '';
        try {
          tafsirResponse = await rootBundle.loadString('assets/translation/ar/ar_translation_${widget.surahId}-json');
        } catch (_) {
          try {
            tafsirResponse = await rootBundle.loadString('assets/translation/ar/surah_${widget.surahId}-json');
          } catch (_) {
            tafsirResponse = await rootBundle.loadString('assets/translation/ar/surah_${widget.surahId}.json');
          }
        }

        final tafsirData = json.decode(tafsirResponse);
        Map<String, dynamic> tafsirMap = {};
        if (tafsirData is Map && tafsirData.containsKey('verse')) {
          var tData = tafsirData['verse'];
          if (tData is Map) {
            tafsirMap = Map<String, dynamic>.from(tData);
          } else if (tData is List) {
            for (int i = 0; i < tData.length; i++) {
              tafsirMap['verse_${i + 1}'] = tData[i];
            }
          }
        } else if (tafsirData is Map) {
          tafsirMap = Map<String, dynamic>.from(tafsirData);
        }

        var tafsirEntries = tafsirMap.entries.toList();
        tafsirEntries.sort((a, b) {
          int numA = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          int numB = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return numA.compareTo(numB);
        });
        
        tafsirVerses = tafsirEntries.map((e) => e.value.toString().trim()).toList();
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
                              icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white70 : const Color(0xFF2E7D32)),
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
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("وضع التفسير الميسر", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: const Text("عرض التفسير المعتمد بجانب الآيات", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _showTafsir,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        setState(() => _showTafsir = val);
                        setModalState(() => _showTafsir = val);
                      },
                    ),
                    const Divider(height: 24),
                    Text("وضع العرض والوضوح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),
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
                    // اسم السورة بخط surah_nam
                    Text(
                      widget.surahName,
                      style: const TextStyle(fontSize: 24, fontFamily: 'surah_nam', color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "آياتها: ${widget.versesCount}", 
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اسم الجزء بخط jzu12 عبر الرقم (مثال: currentJuz)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$currentJuz", 
                      style: const TextStyle(fontSize: 16, fontFamily: 'jzu12', color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white, size: 20),
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
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // رسمة البسملة عبر خط bsm60 بالرقم 27
                    if (widget.surahId != 1 && widget.surahId != 9) ...[
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

                    // كارد عرض الآيات والتفسير الجانبي المتناسق
                    Card(
                      elevation: isDark ? 0 : 3,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  for (int i = 0; i < verses.length; i++) ...[
                                    TextSpan(
                                      text: "${verses[i]} ",
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        fontFamily: 'nss', 
                                        height: 2.4,
                                        color: _getTextColor(),
                                        fontWeight: FontWeight.normal,
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

                            // التبويب الجانبي لعرض التفسير بجانب الآيات بشكل مرتب
                            if (_showTafsir) ...[
                              const Divider(height: 30, thickness: 1.5),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "التفسير الميسر (عرض جانبي):",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (int i = 0; i < verses.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "${i + 1}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              verses[i],
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'nss',
                                                color: isDark ? Colors.white60 : Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (i < tafsirVerses.length) ? tafsirVerses[i] : "التفسير غير متوفر",
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.6,
                                                color: isDark ? Colors.white : const Color(0xFF37474F),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
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
