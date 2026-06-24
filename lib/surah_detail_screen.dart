import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<dynamic> juzData = []; // لتخزين بيانات ملف juz.json
  bool isLoading = true;
  int currentJuz = 1;
  
  // متغيرات حالة الصوت والتشغيل
  bool isPlaying = false;
  int? activeVerseIndex; 

  // متغيرات الإعدادات والتبويب
  double _fontSize = 24.0;
  int _themeMode = 0; // 0: فاتح، 1: دافئ، 2: ليلي
  bool _autoScroll = false;

  // قائمة القراء المتعددين
  final List<Map<String, String>> reciters = [
    {"name": "عبد الباسط عبد الصمد", "sub": "Murattal"},
    {"name": "مشاري راشد العفاسي", "sub": "Murattal"},
    {"name": "محمد صديق المنشاوي", "sub": "Murattal"},
    {"name": "سعد الغامدي", "sub": "Murattal"},
    {"name": "أحمد بن علي العجمي", "sub": "Murattal"},
    {"name": "أبو بكر الشاطري", "sub": "Murattal"},
  ];
  int selectedReciterIndex = 1; // العفاسي افتراضياً

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. تحميل ملف juz.json المنظم الموجود في مشروعك
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      // 2. تحميل ملف السورة
      final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final data = json.decode(response);
      final Map<String, dynamic> verseMap = data['verse'];
      
      List<String> loadedVerses = [];
      for (int i = 0; i < verseMap.length; i++) {
        if (verseMap.containsKey('verse_$i')) {
          loadedVerses.add(verseMap['verse_$i'].toString());
        }
      }

      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
      
      // تحديث الجزء الافتراضي لأول آية في السورة
      _updateJuzForVerse(0);
    } catch (e) {
      setState(() {
        verses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
        isLoading = false;
      });
    }
  }

  // 🟢 دالة سحرية لمطابقة الآية الحالية مع ملف juz.json لتحديد الجزء بدقة وموثوقية
  void _updateJuzForVerse(int verseIdx) {
    if (juzData.isEmpty) return;

    int targetSurah = widget.surahId;
    int targetVerse = verseIdx + 1; // تحويل من index الصفر إلى رقم الآية الفعلي

    for (var juz in juzData) {
      try {
        int startSurah = int.parse(juz['start']['index']);
        // تنظيف نص الآية وتحويله لرقم (مثال: verse_142 تصبح 142)
        int startVerse = int.parse(juz['start']['verse'].toString().replaceAll('verse_', ''));
        
        int endSurah = int.parse(juz['end']['index']);
        int endVerse = int.parse(juz['end']['verse'].toString().replaceAll('verse_', ''));
        int juzIndex = int.parse(juz['index']);

        // التحقق مما إذا كانت السورة والآية تقع في نطاق هذا الجزء
        bool inside = false;
        if (targetSurah > startSurah && targetSurah < endSurah) {
          inside = true;
        } else if (targetSurah == startSurah && targetSurah == endSurah) {
          if (targetVerse >= startVerse && targetVerse <= endVerse) inside = true;
        } else if (targetSurah == startSurah) {
          if (targetVerse >= startVerse) inside = true;
        } else if (targetSurah == endSurah) {
          if (targetVerse <= endVerse) inside = true;
        }

        if (inside) {
          setState(() {
            currentJuz = juzIndex;
          });
          break;
        }
      } catch (_) {}
    }
  }

  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFFBF7EE);
    if (_themeMode == 2) return const Color(0xFF121212);
    return Colors.white;
  }

  Color _getTextColor() {
    if (_themeMode == 2) return Colors.white;
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 12),
                    Text("حجم خط القراءة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Slider(
                      value: _fontSize, min: 20, max: 40, divisions: 10,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        setModalState(() => _fontSize = v);
                      },
                    ),
                    const Divider(),
                    Text("وضع العرض:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(label: const Text("فاتح"), selected: _themeMode == 0, onSelected: (s) { setState(() => _themeMode = 0); setModalState(() {}); }),
                        ChoiceChip(label: const Text("دافئ"), selected: _themeMode == 1, onSelected: (s) { setState(() => _themeMode = 1); setModalState(() {}); }),
                        ChoiceChip(label: const Text("ليلي"), selected: _themeMode == 2, onSelected: (s) { setState(() => _themeMode = 2); setModalState(() {}); }),
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

  void _showRecitersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView.builder(
            itemCount: reciters.length,
            itemBuilder: (context, idx) {
              final isSelected = idx == selectedReciterIndex;
              return ListTile(
                leading: Icon(Icons.person, color: isSelected ? const Color(0xFF2E7D32) : Colors.grey),
                title: Text(reciters[idx]['name']!, style: TextStyle(color: _themeMode == 2 ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
                onTap: () {
                  setState(() => selectedReciterIndex = idx);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        appBar: AppBar(
          title: Column(
            children: [
              Text("سُورَةُ ${widget.surahName}", style: const TextStyle(fontFamily: 'nam', fontSize: 24)),
              Text("الجزء ${toArabicNumerals(currentJuz)}", style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.tune), onPressed: _showSettingsBottomSheet),
            IconButton(icon: const Icon(Icons.group), onPressed: _showRecitersBottomSheet),
          ],
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]))),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (widget.surahId != 1 && widget.surahId != 9) ...[
                            const Center(child: Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", style: TextStyle(fontFamily: 'bsm60', fontSize: 32, color: Color(0xFF2E7D32)), textAlign: TextAlign.center)),
                            const SizedBox(height: 20),
                          ],
                          RichText(
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              children: List.generate(verses.length, (index) {
                                // 🟢 التحكم بالترميز: يظهر فقط عند تفعيل زر التشغيل الصوتي وحالة التشغيل مفعلة
                                final bool isCurrentActive = isPlaying && activeVerseIndex == index;

                                return TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${verses[index]} ",
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        fontFamily: 'nss',
                                        color: isCurrentActive ? const Color(0xFF2E7D32) : _getTextColor(),
                                        fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                                        backgroundColor: isCurrentActive ? const Color(0xFFE8F5E9).withOpacity(0.7) : Colors.transparent,
                                      ),
                                    ),
                                    TextSpan(
                                      text: " ﴿${toArabicNumerals(index + 1)}﴾ ",
                                      style: const TextStyle(fontFamily: 'quran_num', fontSize: 20, color: Color(0xFFC19A6B)),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // شريط التحكم السفلي بالتلاوة والقراء
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(color: _themeMode == 2 ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5), border: const Border(top: BorderSide(color: Colors.black12))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: Icon(Icons.person, color: _themeMode == 2 ? Colors.white70 : Colors.black54), onPressed: _showRecitersBottomSheet),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Color(0xFF2E7D32)),
                              onPressed: () {
                                if (activeVerseIndex != null && activeVerseIndex! < verses.length - 1) {
                                  setState(() {
                                    activeVerseIndex = activeVerseIndex! + 1;
                                    _updateJuzForVerse(activeVerseIndex!);
                                  });
                                }
                              },
                            ),
                            FloatingActionButton(
                              mini: true,
                              backgroundColor: const Color(0xFF2E7D32),
                              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  isPlaying = !isPlaying;
                                  if (isPlaying && activeVerseIndex == null) {
                                    activeVerseIndex = 0;
                                    _updateJuzForVerse(0);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: Color(0xFF2E7D32)),
                              onPressed: () {
                                if (activeVerseIndex != null && activeVerseIndex! > 0) {
                                  setState(() {
                                    activeVerseIndex = activeVerseIndex! - 1;
                                    _updateJuzForVerse(activeVerseIndex!);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        Text("القارئ: ${reciters[selectedReciterIndex]['name']}", style: TextStyle(fontSize: 12, color: _themeMode == 2 ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
