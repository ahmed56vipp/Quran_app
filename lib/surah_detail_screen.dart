import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;      // رقم السورة (مثال: 10)
  final String surahName;  // اسم السورة بالعربية
  final int versesCount;   // عدد الآيات
  final String surahType;  // مكية / مدنية
  final int initialJuz;    // رقم الجزء الافتراضي الممرر

  // قيم التحكم المربوطة بشاشة خيارات العرض والقراءة لديك
  final double initialFontSize;
  final bool isDarkMode;
  final bool isSepiaMode;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.initialJuz,
    this.initialFontSize = 24.0,
    this.isDarkMode = false,
    this.isSepiaMode = false,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  late AudioPlayer _audioPlayer;
  int _currentVerseIndex = -1; 
  bool _isPlaying = false;
  bool _isLoading = true; // حالة تحميل ملف الـ JSON
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _reciters = [
    {"name": "مشاري راشد العفاسي", "subfolder": "Alafasy_128kbps"},
    {"name": "عبد الباسط (مرتل)", "subfolder": "Abdul_Basit_Murattal_192kbps"},
    {"name": "سعد الغامدي", "subfolder": "Ghamadi_40kbps"},
    {"name": "محمد صديق المنشاوي", "subfolder": "Minshawi_Murattal_128kbps"},
  ];
  late Map<String, String> _selectedReciter;
  
  // هذه القائمة ستحمل نصوص الآيات الفعلية بعد معالجتها من ملف الـ JSON
  List<String> _versesTextList = [];
  int _currentJuz = 1;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _selectedReciter = _reciters[0];
    _currentJuz = widget.initialJuz;

    // بدء تحميل البيانات الحقيقية من المجلدات الموضحة في الصور
    _loadSurahData();
    _initAudioSource();

    // الاستماع لتدفق الصوت وتحديث التتبع التلقائي
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        setState(() {
          _currentVerseIndex = index;
        });
        _scrollToVerse(index);
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  // 🟢 دالة قراءة ملف الـ JSON الديناميكي من مسار assets/surah/ بناءً على رقم السورة
  Future<void> _loadSurahData() async {
    try {
      // تحميل الملف المطابق لرقم السورة الحالية
      String jsonString = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      Map<String, dynamic> localData = json.decode(jsonString);
      
      Map<String, dynamic> versesMap = localData['verse'];
      List<String> temporaryList = [];

      // ترتيب واستخراج الآيات بالتسلسل الصحيح (verse_1, verse_2...) وتخطي verse_0 (البسملة المدمجة إن وجدت)
      for (int i = 1; i <= widget.versesCount; i++) {
        String key = "verse_$i";
        if (versesMap.containsKey(key)) {
          temporaryList.add(versesMap[key].toString().trim());
        }
      }

      setState(() {
        _versesTextList = temporaryList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("خطأ أثناء قراءة ملف JSON السورة: $e");
      // في حال حدوث خطأ، ملء البيانات احتياطياً لتجنب توقف التطبيق
      setState(() {
        _versesTextList = List.generate(widget.versesCount, (index) => "خطأ في تحميل نص الآية");
        _isLoading = false;
      });
    }
  }

  Future<void> _initAudioSource() async {
    List<AudioSource> audioSources = [];
    String formattedSurah = widget.surahId.toString().padLeft(3, '0');

    for (int i = 1; i <= widget.versesCount; i++) {
      String formattedVerse = i.toString().padLeft(3, '0');
      String url = "https://everyayah.com/data/${_selectedReciter['subfolder']}/$formattedSurah$formattedVerse.mp3";
      audioSources.add(AudioSource.uri(Uri.parse(url)));
    }

    try {
      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: audioSources));
    } catch (e) {
      debugPrint("Audio Source Error: $e");
    }
  }

  void _changeReciter(Map<String, String> reciter) async {
    setState(() {
      _selectedReciter = reciter;
    });
    final lastIndex = _currentVerseIndex >= 0 ? _currentVerseIndex : 0;
    await _initAudioSource();
    await _audioPlayer.seek(Duration.zero, index: lastIndex);
    if (_isPlaying) _audioPlayer.play();
  }

  void _scrollToVerse(int index) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * 42.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Color _getBackgroundColor() {
    if (widget.isDarkMode) return const Color(0xFF121212);
    if (widget.isSepiaMode) return const Color(0xFFF4ECD8);
    return Colors.white;
  }

  Color _getTextColor(bool isCurrentActive) {
    if (isCurrentActive) return const Color(0xFF2E7D32); 
    if (widget.isDarkMode) return const Color(0xFFE0E0E0);
    return const Color(0xFF2C3E50);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showRecitersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "اختر القارئ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : const Color(0xFF2E7D32)),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _reciters.length,
                  itemBuilder: (context, index) {
                    final reciter = _reciters[index];
                    final isSelected = reciter['name'] == _selectedReciter['name'];
                    return ListTile(
                      title: Text(reciter['name']!, style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _changeReciter(reciter);
                      },
                    );
                  },
                ),
              )
            ],
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
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. عرض الجزء الحالي من خط jzu12 بالأرقام الصريحة المحددة
              Text(
                _currentJuz.toString(),
                style: const TextStyle(
                  fontFamily: 'jzu12',
                  fontSize: 26,
                  color: Color(0xFFFFD700), 
                ),
              ),
              const SizedBox(width: 25),
              // 2. اسم السورة الداخلي بخط nam المخصص لأسماء السور
              Text(
                widget.surahName,
                style: const TextStyle(
                  fontFamily: 'nam',
                  fontSize: 28,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () {
                // فتح شاشة التخصيص والخيارات الخاصة بك
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // 3. إطار البسملة المخصص: طباعة الرمز "19" ليعمل بالخط bsm60 المخصص
                          if (widget.surahId != 9)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 25),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFFFDF6),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.2),
                              ),
                              child: Text(
                                "19", 
                                style: TextStyle(
                                  fontFamily: 'bsm60',
                                  fontSize: 32,
                                  color: widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // 4. عرض نصوص السورة الحقيقية بشكل متصل ومستمر دون تفكيك
                          RichText(
                            textAlign: TextAlign.justify,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              children: List.generate(_versesTextList.length, (index) {
                                final isCurrentActive = index == _currentVerseIndex;
                                final verseDisplayNum = index + 1; // الأرقام الإنجليزية المخصصة لخطوط الترقيم الزخرفية

                                return TextSpan(
                                  children: [
                                    // متن الآية بالخط العثماني الداخلي nss المعتمد في الـ pubspec لديك
                                    TextSpan(
                                      text: "${_versesTextList[index]} ",
                                      style: TextStyle(
                                        fontFamily: 'nss', 
                                        fontSize: widget.initialFontSize,
                                        height: 2.2,
                                        color: _getTextColor(isCurrentActive),
                                        fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                                        backgroundColor: isCurrentActive 
                                            ? const Color(0xFF2E7D32).withOpacity(0.12)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    // 5. رقم الآية ممرر مباشرة بالصيغة الإنجليزية لخط quran_num (123456.ttf) ليرسم الأقواس المزخرفة تلقائياً
                                    TextSpan(
                                      text: " $verseDisplayNum ",
                                      style: TextStyle(
                                        fontFamily: 'quran_num', 
                                        fontSize: widget.initialFontSize * 0.8,
                                        color: isCurrentActive 
                                            ? const Color(0xFF2E7D32) 
                                            : (widget.isDarkMode ? Colors.white70 : const Color(0xFF2E7D32).withOpacity(0.7)),
                                      ),
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

                  // شريط التحكم السفلي الأصلي والمنسق بالكامل ومطابق لواجهتك
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -4))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF2E7D32),
                          child: IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            onPressed: () {
                              if (_isPlaying) {
                                _audioPlayer.pause();
                              } else {
                                _audioPlayer.play();
                              }
                            },
                          ),
                        ),
                        Text(
                          "تلاوة سورة ${widget.surahName}",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.audiotrack, color: Color(0xFF2E7D32), size: 26),
                          onPressed: _showRecitersBottomSheet,
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
