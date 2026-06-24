import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
  List<dynamic> juzData = [];
  bool isLoading = true;
  int currentJuz = 1;
  
  bool isPlaying = false;
  int? activeVerseIndex; 

  double _fontSize = 24.0;
  int _themeMode = 0; // 0: فاتح، 1: دافئ، 2: ليلي

  // إدارة تحميل الصوتيات
  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool isAudioDownloaded = false;

  // قائمة القراء مع روابط الخوادم الصوتية الخاصة بهم (كمثال للتحميل)
  final List<Map<String, String>> reciters = [
    {"name": "عبد الباسط عبد الصمد", "server": "https://server7.mp3quran.net/basit/"},
    {"name": "مشاري راشد العفاسي", "server": "https://server8.mp3quran.net/afs/"},
    {"name": "محمد صديق المنشاوي", "server": "https://server10.mp3quran.net/minsh/"},
    {"name": "سعد الغامدي", "server": "https://server7.mp3quran.net/s_gmd/"},
    {"name": "أحمد بن علي العجمي", "server": "https://server11.mp3quran.net/ajm/"},
    {"name": "أبو بكر الشاطري", "server": "https://server11.mp3quran.net/shatri/"},
  ];
  int selectedReciterIndex = 1; // العفاسي افتراضياً

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  // التحقق من وجود الملف الصوتي محلياً في جهاز المستخدم
  Future<void> _checkAudioFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String folderName = reciters[selectedReciterIndex]['name']!;
      final String fileName = "${widget.surahId.toString().padLeft(3, '0')}.mp3";
      final file = File('${directory.path}/audio/$folderName/$fileName');
      
      setState(() {
        isAudioDownloaded = file.existsSync();
      });
    } catch (_) {}
  }

  // دالة تحميل وتخزين الصوتيات في الجهاز لأول مرة
  Future<void> _downloadAudio() async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final String folderName = reciters[selectedReciterIndex]['name']!;
      final String fileName = "${widget.surahId.toString().padLeft(3, '0')}.mp3";
      
      // إنشاء المجلد إذا لم يكن موجوداً
      final saveDir = Directory('${directory.path}/audio/$folderName');
      if (!saveDir.existsSync()) {
        saveDir.createSync(recursive: true);
      }

      final file = File('${saveDir.path}/$fileName');
      
      // رابط الملف الصوتي من السيرفر
      final String audioUrl = "${reciters[selectedReciterIndex]['server']}${widget.surahId.toString().padLeft(3, '0')}.mp3";

      // هنا يمكنك استخدام دالة التحميل الخاصة بـ HttpClient المدمج أو حزمة Dio
      // كمثال محاكاة للتحميل السريع والآمن:
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          downloadProgress = i / 10;
        });
      }

      // بعد اكتمال الكتابة بنجاح
      await file.writeAsString("audio_data_placeholder"); 

      setState(() {
        isDownloading = false;
        isAudioDownloaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تحميل سورة ${widget.surahName} بصوت الشيخ ${reciters[selectedReciterIndex]['name']} بنجاح!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل التحميل، يرجى التحقق من الاتصال بالشبكة"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadData() async {
    try {
      await _checkAudioFile();
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final data = json.decode(response);
      final Map<String, dynamic> verseMap = data['verse'];
      
      List<String> loadedVerses = [];
      for (int i = 0; i < verseMap.length; i++) {
        if (verseMap.containsKey('verse_$i')) {
          String text = verseMap['verse_$i'].toString().trim();
          
          if (widget.surahId != 1 && widget.surahId != 9 && i == 0) {
            final cleanText = text.replaceFirst("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", "").trim();
            if (cleanText.isNotEmpty) {
              loadedVerses.add(cleanText);
              continue;
            }
          }
          loadedVerses.add(text);
        }
      }

      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
      
      _updateJuzForVerse(0);
    } catch (e) {
      setState(() {
        verses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
        isLoading = false;
      });
    }
  }

  void _updateJuzForVerse(int verseIdx) {
    if (juzData.isEmpty) return;
    int targetSurah = widget.surahId;
    int targetVerse = verseIdx + 1;

    for (var juz in juzData) {
      try {
        int startSurah = int.parse(juz['start']['index']);
        int startVerse = int.parse(juz['start']['verse'].toString().replaceAll('verse_', ''));
        int endSurah = int.parse(juz['end']['index']);
        int endVerse = int.parse(juz['end']['verse'].toString().replaceAll('verse_', ''));
        int juzIndex = int.parse(juz['index']);

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
                  setState(() {
                    selectedReciterIndex = idx;
                  });
                  _checkAudioFile();
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
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "سُورَةُ ${widget.surahName}",
                    style: const TextStyle(fontFamily: 'nam', fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "آياتها: ${toArabicNumerals(widget.versesCount)}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "الجزء ${toArabicNumerals(currentJuz)}",
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
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
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
            ),
          ),
          elevation: 2,
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
                            const Center(
                              child: Text(
                                "19",
                                style: TextStyle(fontFamily: 'bsm60', fontSize: 55, color: Color(0xFF2E7D32)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          RichText(
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              children: List.generate(verses.length, (index) {
                                final bool isCurrentActive = isPlaying && activeVerseIndex == index;

                                return TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${verses[index]} ",
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        fontFamily: 'nss', // خط ترميز ومتن الآيات المخصص
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
                  // شريط التحكم السفلي المطور بالتحميل والحفظ
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _themeMode == 2 ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                      border: const Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.person_pin, color: _themeMode == 2 ? Colors.white70 : Colors.black54, size: 28),
                          onPressed: _showRecitersBottomSheet,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Color(0xFF2E7D32), size: 28),
                              onPressed: () {
                                if (activeVerseIndex != null && activeVerseIndex! < verses.length - 1) {
                                  setState(() {
                                    activeVerseIndex = activeVerseIndex! + 1;
                                    _updateJuzForVerse(activeVerseIndex!);
                                  });
                                }
                              },
                            ),
                            
                            // زر ذكي: يعرض حالة التحميل، أو التحميل لأول مرة، أو التشغيل المباشر في حال وجوده بالهاتف
                            isDownloading
                                ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(value: downloadProgress, color: const Color(0xFF2E7D32), strokeWidth: 3))
                                : !isAudioDownloaded
                                    ? IconButton(
                                        icon: const Icon(Icons.cloud_download, color: Colors.orange, size: 30),
                                        onPressed: _downloadAudio,
                                        tooltip: 'تحميل السورة للاستماع بدون إنترنت',
                                      )
                                    : FloatingActionButton(
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
                              icon: const Icon(Icons.skip_previous, color: Color(0xFF2E7D32), size: 28),
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
                        Expanded(
                          child: Text(
                            "القارئ: ${reciters[selectedReciterIndex]['name']}",
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 12, color: _themeMode == 2 ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

