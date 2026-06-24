import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  late AudioPlayer _audioPlayer;
  int _currentVerseIndex = 0; // تتبع الآية الحالية المقروءة لتظليلها
  bool _isPlaying = false;
  final ScrollController _scrollController = ScrollController();

  // أوضاع الشاشة: 0 = عادي (فاتح)، 1 = حماية العين (سيبيا)، 2 = وضع ليلي
  int _themeMode = 0; 

  // قائمة القراء بروابط صوتية مباشرة ومستقرة (آية آية) للتشغيل الآلي المتابع
  final List<Map<String, String>> _reciters = [
    {"name": "مشاري راشد العفاسي", "subfolder": "Alafasy_128kbps"},
    {"name": "عبد الباسط (مرتل)", "subfolder": "Abdul_Basit_Murattal_192kbps"},
    {"name": "سعد الغامدي", "subfolder": "Ghamadi_40kbps"},
    {"name": "محمد صديق المنشاوي", "subfolder": "Minshawi_Murattal_128kbps"},
  ];
  
  late Map<String, String> _selectedReciter;

  // 🔴 ملاحظة: استبدل هذه المصفوفة التجريبية ببيانات نصوص الآيات الحقيقية القادمة من قاعدة بياناتك
  late List<String> versesTextList;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _selectedReciter = _reciters[0]; // العفاسي افتراضياً

    // توليد نصوص تجريبية متوافقة مع عدد الآيات
    versesTextList = List.generate(
      widget.versesCount, 
      (index) => "يَا أَيُّهَا النَّاسُ اتَّقُوا رَبَّكُمُ الَّذِي خَلَقَكُم مِّن نَّفْسٍ وَاحِدَةٍ"
    );

    _initAudioSource();

    // الاستماع لتغير الآية الحالية لتحديث التظليل والتمرير الآلي
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        setState(() {
          _currentVerseIndex = index;
        });
        _scrollToVerse(index);
      }
    });

    // الاستماع لحالة تشغيل الصوت لتحديث شكل الأزرار
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  // إعداد قائمة تشغيل السورة (آية تلو الأخرى لتوفير القراءة الآلية المتتابعة)
  Future<void> _initAudioSource() async {
    List<AudioSource> audioSources = [];
    String formattedSurah = widget.surahId.toString().padLeft(3, '0');

    for (int i = 1; i <= widget.versesCount; i++) {
      String formattedVerse = i.toString().padLeft(3, '0');
      String url = "https://everyayah.com/data/${_selectedReciter['subfolder']}/$formattedSurah$formattedVerse.mp3";
      audioSources.add(AudioSource.uri(Uri.parse(url)));
    }

    try {
      await _audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
      );
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  // دالة تغيير القارئ مع الحفاظ على موقع القراءة الحالي
  void _changeReciter(Map<String, String> reciter) async {
    setState(() {
      _selectedReciter = reciter;
    });
    final lastIndex = _currentVerseIndex;
    await _initAudioSource();
    await _audioPlayer.seek(Duration.zero, index: lastIndex);
    if (_isPlaying) _audioPlayer.play();
  }

  // تحريك الشاشة تلقائياً للآية المقروءة لتظل واضحة للمستخدم
  void _scrollToVerse(int index) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * 85.0, // حسابه تقريبية لموقع السطر البرمجي للآية
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // ألوان السمات (العادي، حماية العين، الليلي)
  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFF4ECD8); // لون السيبيا المريح للعين
    if (_themeMode == 2) return const Color(0xFF121212); // اللون الأسود الليلي
    return Colors.white;
  }

  Color _getTextColor(bool isCurrentActive) {
    if (isCurrentActive) return const Color(0xFF2E7D32); // اللون الأخضر عند تتبع القراءة
    if (_themeMode == 2) return const Color(0xFFE0E0E0); // نص أبيض خفيف في الوضع الليلي
    return const Color(0xFF2C3E50);
  }

  Color _getHighlightColor() {
    if (_themeMode == 2) return const Color(0xFF1B5E20).withOpacity(0.4); // تظليل ليلي غامق
    return const Color(0xFFE8F5E9); // تظليل أخضر فاتح عادي
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // نافذة اختيار القراء من الأسفل
  void _showRecitersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "اختر القارئ",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: _themeMode == 2 ? Colors.white : const Color(0xFF1B5E20)
                ),
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
                      title: Text(
                        reciter['name']!, 
                        style: TextStyle(
                          color: _themeMode == 2 ? Colors.whiteFE : Colors.blackDE,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )
                      ),
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
          title: Column(
            children: [
              Text("سُورَة ${widget.surahName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              Text("آياتها: ${widget.versesCount}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            // زر تبديل الأوضاع (عادي / حماية العين / ليلي)
            IconButton(
              icon: Icon(_themeMode == 0 ? Icons.wb_sunny : _themeMode == 1 ? Icons.remove_red_eye : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  _themeMode = (_themeMode + 1) % 3; // التبديل الدائري بين الأوضاع الثلاثة
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              onTap: _showRecitersBottomSheet,
            )
          ],
        ),
        body: Column(
          children: [
            // عرض النص القرآني المتناسق
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(18),
                itemCount: widget.versesCount + 1, // +1 من أجل البسملة المنعزلة في البداية
                itemBuilder: (context, index) {
                  // 1. عرض البسملة المنعزلة في السطر الأول (إن لم تكن سورة التوبة)
                  if (index == 0) {
                    if (widget.surahId == 9) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 25),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
                      decoration: BoxDecoration(
                        color: _themeMode == 2 ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                      ),
                      child: Text(
                        "بسم الله الرحمن الرحيم",
                        style: TextStyle(
                          fontFamily: 'bsm60', // خط البسملة المنعزل والمخصص
                          fontSize: 26,
                          color: _themeMode == 2 ? Colors.white : const Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // ضبط المؤشر الفعلي للآيات بعد سطر البسملة
                  final verseIndex = index - 1;
                  final isCurrentActive = verseIndex == _currentVerseIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentActive ? _getHighlightColor() : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrentActive
                          ? Border.all(color: const Color(0xFF2E7D32).withOpacity(0.4), width: 1)
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // خط الترقيم المنعزل داخل الرمز الدائري للآية
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrentActive ? const Color(0xFF2E7D32) : (_themeMode == 2 ? Colors.grey[800] : Colors.grey[200]),
                          ),
                          child: Text(
                            "${verseIndex + 1}",
                            style: TextStyle(
                              fontFamily: 'quran_num', // خط الترقيم المنعزل المخصص للأرقام الذكية
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCurrentActive ? Colors.white : (_themeMode == 2 ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // نص الآية بالخط العثماني المخصص
                        Expanded(
                          child: Text(
                            versesTextList[verseIndex],
                            style: TextStyle(
                              fontFamily: 'uthmani', // الخط العثماني المخصص لنصوص الآيات الكريمة
                              fontSize: 23,
                              height: 1.9,
                              color: _getTextColor(isCurrentActive),
                              fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // شريط التحكم بالصوت السفلي (يتكيف تلقائياً مع الأوضاع)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("القارئ الحالي", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        _selectedReciter['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Color(0xFF2E7D32), size: 28),
                        onPressed: () => _audioPlayer.seekToNext(), // قراءة آلية متتابعة للآية التالية
                      ),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2E7D32),
                        child: IconButton(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
                          onPressed: () {
                            if (_isPlaying) {
                              _audioPlayer.pause();
                            } else {
                              _audioPlayer.play();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Color(0xFF2E7D32), size: 28),
                        onPressed: () => _audioPlayer.seekToPrevious(), // الرجوع للآية السابقة
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.palette, color: Color(0xFF2E7D32)),
                    onPressed: () {
                      setState(() {
                        _themeMode = (_themeMode + 1) % 3;
                      });
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
