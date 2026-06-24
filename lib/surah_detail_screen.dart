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
  int _currentVerseIndex = 0; // مؤشر الآية الحالية المقروءة
  bool _isPlaying = false;
  final ScrollController _scrollController = ScrollController();

  // قائمة القرّاء المتاحين بروابط السيرفر المباشر لـ EverydayAyah
  final List<Map<String, String>> _reciters = [
    {"name": "مشاري راشد العفاسي", "subfolder": "Alafasy_128kbps"},
    {"name": "عبد الباسط (مرتل)", "subfolder": "Abdul_Basit_Murattal_192kbps"},
    {"name": "سعد الغامدي", "subfolder": "Ghamadi_40kbps"},
    {"name": "محمد صديق المنشاوي", "subfolder": "Minshawi_Murattal_128kbps"},
  ];
  
  late Map<String, String> _selectedReciter;

  @override
  void college() {
    super.initState();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _selectedReciter = _reciters[0]; // العفاسي افتراضياً

    _initAudioSource();

    // الاستماع لتغير الآية الحالية لتحديث التظليل وتحريك الشاشة
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        setState(() {
          _currentVerseIndex = index;
        });
        _scrollToVerse(index);
      }
    });

    // الاستماع لحالة التشغيل
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  // إعداد قائمة تشغيل السورة آية آية ديناميكياً
  Future<void> _initAudioSource() async {
    List<AudioSource> audioSources = [];
    String formattedSurah = widget.surahId.toString().padLeft(3, '0');

    for (int i = 1; i <= widget.versesCount; i++) {
      String formattedVerse = i.toString().padLeft(3, '0');
      // رابط آية آية الموحد والمستقر عالمياً
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

  // تغيير القارئ وإعادة بناء قائمة الصوت
  void _changeReciter(Map<String, String> reciter) async {
    setState(() {
      _selectedReciter = reciter;
    });
    final lastIndex = _currentVerseIndex;
    await _initAudioSource();
    // العودة إلى نفس الآية بعد تغيير القارئ
    await _audioPlayer.seek(Duration.zero, index: lastIndex);
    if (_isPlaying) _audioPlayer.play();
  }

  // تحريك الشاشة تلقائياً للآية المقروءة
  void _scrollToVerse(int index) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * 75.0, // تقدير تقريبي لارتفاع الآية في القائمة
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // عرض قائمة اختيار القراء من الأسفل
  void _showRecitersBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "اختر القارئ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
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
                      title: Text(reciter['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
        appBar: AppBar(
          title: Column(
            children: [
              Text("سُورَة ${widget.surahName}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("آياتها: ${widget.versesCount}", style: const TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              onTap: _showRecitersBottomSheet, // زر اختيار القارئ
            )
          ],
        ),
        body: Column(
          children: [
            // قائمة الآيات وتظليل الآية الحالية
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.versesCount,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final isCurrentActive = index == _currentVerseIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentActive 
                          ? const Color(0xFFE8F5E9) // لون التظليل الأخضر الفاتح عند القراءة
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrentActive
                          ? Border.all(color: const Color(0xFF2E7D32).withOpacity(0.5), width: 1)
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // رقم الآية
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isCurrentActive ? const Color(0xFF2E7D32) : Colors.grey[200],
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(
                              fontSize: 12, 
                              color: isCurrentActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // نص الآية الافتراضي (ضع هنا متغير جلب النص من البيانات الخاصة بك)
                        Expanded(
                          child: Text(
                            "نص الآية الكريمة رقم ${index + 1} من سورة ${widget.surahName}...",
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.8,
                              color: isCurrentActive ? const Color(0xFF1B5E20) : Colors.blackDE,
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
            // شريط التحكم بالصوت في الأسفل
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "القارئ: ${_selectedReciter['name']}",
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Color(0xFF2E7D32)),
                        onTap: () => _audioPlayer.seekToNext(),
                      ),
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
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Color(0xFF2E7D32)),
                        onTap: () => _audioPlayer.seekToPrevious(),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.list),
                    onTap: _showRecitersBottomSheet,
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
