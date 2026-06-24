import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final List<dynamic> juzData; // نفترض أن العنصر الأول يحتوي على رقم الجزء الحقيقي كمثال
  
  // استقبال قيم التحكم من شاشة الإعدادات والعرض
  final double initialFontSize;
  final bool isDarkMode;
  final bool isSepiaMode;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.juzData,
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
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _reciters = [
    {"name": "مشاري راشد العفاسي", "subfolder": "Alafasy_128kbps"},
    {"name": "عبد الباسط (مرتل)", "subfolder": "Abdul_Basit_Murattal_192kbps"},
    {"name": "سعد الغامدي", "subfolder": "Ghamadi_40kbps"},
    {"name": "محمد صديق المنشاوي", "subfolder": "Minshawi_Murattal_128kbps"},
  ];
  late Map<String, String> _selectedReciter;
  late List<String> _versesTextList;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _selectedReciter = _reciters[0];

    // 🟢 تأكد من ربط هذه المصفوفة بنصوص السور الحقيقية المستخرجة من قاعدة بياناتك
    _versesTextList = List.generate(
      widget.versesCount,
      (index) => "إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ"
    );

    _initAudioSource();

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
    if (isCurrentActive) return const Color(0xFF2E7D32); // التظليل الأخضر التتبعي عند التلاوة
    if (widget.isDarkMode) return const Color(0xFFE0E0E0);
    return const Color(0xFF2C3E50);
  }

  String _getJuzNumberString() {
    // استخراج رقم الجزء الحقيقي ديناميكياً من بياناتك (إذا كان متاحاً في السورة)، أو نضع افتراضي كمثال
    if (widget.juzData.isNotEmpty && widget.juzData[0] != null) {
      return widget.juzData[0].toString(); 
    }
    return "30"; // مثال افتراضي إذا لم يتوفر الجزء
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
          // عرض اسم السورة ورقم الجزء بخطوطهم التزيينية المخصصة والمحددة في صورتك
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. الجزء الحالي بخط jzu12 ويعمل بالأرقام من 1 إلى 30
              Text(
                _getJuzNumberString(),
                style: const TextStyle(
                  fontFamily: 'jzu12',
                  fontSize: 26,
                  color: Color(0xFFFFD700), // اللون الأصفر الذهبي للخطوط العلوية
                ),
              ),
              const SizedBox(width: 25),
              // 2. اسم السورة بخط nam المخصص لأسماء السور داخل المصحف
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
                // فتح شاشة الخيارات الخاصة بك
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 3. إطار البسملة المنعزل: تم استبدال النص بالرقم "19" ليعمل بخط bsm60 المخصص
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
                          "19", // الرقم المفتاح لطباعة رسم البسملة الفاخر بخطك bsmla60.ttf
                          style: TextStyle(
                            fontFamily: 'bsm60',
                            fontSize: 32,
                            color: widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 4. عرض متن السورة متصل ومستمر بالكامل
                    RichText(
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                      text: TextSpan(
                        children: List.generate(widget.versesCount, (index) {
                          final isCurrentActive = index == _currentVerseIndex;
                          final verseDisplayNum = index + 1; // الأرقام الإنجليزية الصريحة المطلوبة للخط

                          return TextSpan(
                            children: [
                              // نص الآية القرآني بخط nss الأصلي لنصوص السورة الداخلي
                              TextSpan(
                                text: "${_versesTextList[index]} ",
                                style: TextStyle(
                                  fontFamily: 'nss', // خط نصوص السور من الـ pubspec الخاص بك
                                  fontSize: widget.initialFontSize,
                                  height: 2.2,
                                  color: _getTextColor(isCurrentActive),
                                  fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                                  backgroundColor: isCurrentActive 
                                      ? const Color(0xFF2E7D32).withOpacity(0.12)
                                      : Colors.transparent,
                                ),
                              ),
                              // 5. رمز ترقيم الآيات المخصص المعتمد على عائلة quran_num والأرقام الإنجليزية
                              TextSpan(
                                text: " $verseDisplayNum ",
                                style: TextStyle(
                                  fontFamily: 'quran_num', // يعتمد على خط 123456.ttf لطباعة الأقواس التزيينية تلقائياً
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

            // شريط التحكم السفلي الأصلي للتطبيق
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
