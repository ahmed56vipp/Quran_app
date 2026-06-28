import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'surah_detail_screen.dart'; 

const String kSurahNameFont = 'nam';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  int _currentIndex = 0; // 0 تعني أن التطبيق سيفتح تلقائياً على الفهرس
  
  // إعدادات مشغل الصوتيات
  late AudioPlayer _audioPlayer;
  int? _currentPlayingSurahId;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // إعدادات التطبيق الافتراضية
  String _currentLanguage = 'ar'; // ar, en, tr
  String _selectedReciter = 'afs'; // القارئ الافتراضي
  double _globalFontSize = 24.0; // حجم الخط العام للتطبيق

  // قائمة القراء المتاحين وروابط سيرفراتهم المباشرة
  final List<Map<String, String>> recitersList = const [
    {"id": "afs", "name": "مشاري راشد العفاسي"},
    {"id": "shrt", "name": "سعود الشريم"},
    {"id": "gmd", "name": "غمد الغامدي"},
    {"id": "basit", "name": "عبد الباسط عبد الصمد"},
    {"id": "hudhaifi", "name": "علي الحذيفي"},
  ];

  final List<Map<String, dynamic>> surahList = const [
    {"id": 1, "name": "الفاتحة", "type": "مكية", "verses": 7, "isMeccan": true, "juz": 1},
    {"id": 2, "name": "البقرة", "type": "مدنية", "verses": 286, "isMeccan": false, "juz": 1},
    {"id": 3, "name": "آل عمران", "type": "مدنية", "verses": 200, "isMeccan": false, "juz": 3},
    {"id": 4, "name": "النساء", "type": "مدنية", "verses": 176, "isMeccan": false, "juz": 4},
    {"id": 5, "name": "المائدة", "type": "مدنية", "verses": 120, "isMeccan": false, "juz": 6},
    {"id": 6, "name": "الأنعام", "type": "مكية", "verses": 165, "isMeccan": true, "juz": 7},
    {"id": 7, "name": "الأعراف", "type": "مكية", "verses": 206, "isMeccan": true, "juz": 8},
    {"id": 8, "name": "الأنفال", "type": "مدنية", "verses": 75, "isMeccan": false, "juz": 9},
    {"id": 9, "name": "التوبة", "type": "مدنية", "verses": 129, "isMeccan": false, "juz": 10},
    {"id": 10, "name": "يونس", "type": "مكية", "verses": 109, "isMeccan": true, "juz": 11},
    {"id": 11, "name": "هود", "type": "مكية", "verses": 123, "isMeccan": true, "juz": 11},
    {"id": 12, "name": "يوسف", "type": "مكية", "verses": 111, "isMeccan": true, "juz": 12},
    {"id": 13, "name": "الرعد", "type": "مدنية", "verses": 43, "isMeccan": false, "juz": 13},
    {"id": 14, "name": "إبراهيم", "type": "مكية", "verses": 52, "isMeccan": true, "juz": 13},
    {"id": 15, "name": "الحجر", "type": "مكية", "verses": 99, "isMeccan": true, "juz": 14},
    {"id": 16, "name": "النحل", "type": "مكية", "verses": 128, "isMeccan": true, "juz": 14},
    {"id": 17, "name": "الإسراء", "type": "مكية", "verses": 111, "isMeccan": true, "juz": 15},
    {"id": 18, "name": "الكهف", "type": "مكية", "verses": 110, "isMeccan": true, "juz": 15},
    {"id": 19, "name": "مريم", "type": "مكية", "verses": 98, "isMeccan": true, "juz": 16},
    {"id": 20, "name": "طه", "type": "مكية", "verses": 135, "isMeccan": true, "juz": 16},
    {"id": 21, "name": "الأنبياء", "type": "مكية", "verses": 112, "isMeccan": true, "juz": 17},
    {"id": 22, "name": "الحج", "type": "مدنية", "verses": 78, "isMeccan": false, "juz": 17},
    {"id": 23, "name": "المؤمنون", "type": "مكية", "verses": 118, "isMeccan": true, "juz": 18},
    {"id": 24, "name": "النور", "type": "مدنية", "verses": 64, "isMeccan": false, "juz": 18},
    {"id": 25, "name": "الفرقان", "type": "مكية", "verses": 77, "isMeccan": true, "juz": 18},
    {"id": 26, "name": "الشعراء", "type": "مكية", "verses": 227, "isMeccan": true, "juz": 19},
    {"id": 27, "name": "النمل", "type": "مكية", "verses": 93, "isMeccan": true, "juz": 19},
    {"id": 28, "name": "القصص", "type": "مكية", "verses": 88, "isMeccan": true, "juz": 20},
    {"id": 29, "name": "العنكبوت", "type": "مكية", "verses": 69, "isMeccan": true, "juz": 20},
    {"id": 30, "name": "الروم", "type": "مكية", "verses": 60, "isMeccan": true, "juz": 21},
    {"id": 31, "name": "لقمان", "type": "مكية", "verses": 34, "isMeccan": true, "juz": 21},
    {"id": 32, "name": "السجدة", "type": "مكية", "verses": 30, "isMeccan": true, "juz": 21},
    {"id": 33, "name": "الأحزاب", "type": "مدنية", "verses": 73, "isMeccan": false, "juz": 21},
    {"id": 34, "name": "سبأ", "type": "مكية", "verses": 54, "isMeccan": true, "juz": 22},
    {"id": 35, "name": "فاطر", "type": "مكية", "verses": 45, "isMeccan": true, "juz": 22},
    {"id": 36, "name": "يس", "type": "مكية", "verses": 83, "isMeccan": true, "juz": 22},
    {"id": 37, "name": "الصافات", "type": "مكية", "verses": 182, "isMeccan": true, "juz": 23},
    {"id": 38, "name": "ص", "type": "مكية", "verses": 88, "isMeccan": true, "juz": 23},
    {"id": 39, "name": "الزمر", "type": "مكية", "verses": 75, "isMeccan": true, "juz": 23},
    {"id": 40, "name": "غافر", "type": "مكية", "verses": 85, "isMeccan": true, "juz": 24},
    {"id": 41, "name": "فصلت", "type": "مكية", "verses": 54, "isMeccan": true, "juz": 24},
    {"id": 42, "name": "الشورى", "type": "مكية", "verses": 53, "isMeccan": true, "juz": 25},
    {"id": 43, "name": "الزخرف", "type": "مكية", "verses": 89, "isMeccan": true, "juz": 25},
    {"id": 44, "name": "الدخان", "type": "مكية", "verses": 59, "isMeccan": true, "juz": 25},
    {"id": 45, "name": "الجاثية", "type": "مكية", "verses": 37, "isMeccan": true, "juz": 25},
    {"id": 46, "name": "الأحقاف", "type": "مكية", "verses": 35, "isMeccan": true, "juz": 26},
    {"id": 47, "name": "محمد", "type": "مدنية", "verses": 38, "isMeccan": false, "juz": 26},
    {"id": 48, "name": "الفتح", "type": "مدنية", "verses": 29, "isMeccan": false, "juz": 26},
    {"id": 49, "name": "الحجرات", "type": "مدنية", "verses": 18, "isMeccan": false, "juz": 26},
    {"id": 50, "name": "ق", "type": "مكية", "verses": 45, "isMeccan": true, "juz": 26},
    {"id": 51, "name": "الذاريات", "type": "مكية", "verses": 60, "isMeccan": true, "juz": 26},
    {"id": 52, "name": "الطور", "type": "مكية", "verses": 49, "isMeccan": true, "juz": 27},
    {"id": 53, "name": "النجم", "type": "مكية", "verses": 62, "isMeccan": true, "juz": 27},
    {"id": 54, "name": "القمر", "type": "مكية", "verses": 55, "isMeccan": true, "juz": 27},
    {"id": 55, "name": "الرحمن", "type": "مدنية", "verses": 78, "isMeccan": false, "juz": 27},
    {"id": 56, "name": "الواقعة", "type": "مكية", "verses": 96, "isMeccan": true, "juz": 27},
    {"id": 57, "name": "الحديد", "type": "مدنية", "verses": 29, "isMeccan": false, "juz": 27},
    {"id": 58, "name": "المجادلة", "type": "مدنية", "verses": 22, "isMeccan": false, "juz": 28},
    {"id": 59, "name": "الحشر", "type": "مدنية", "verses": 24, "isMeccan": false, "juz": 28},
    {"id": 60, "name": "الممتحنة", "type": "مدنية", "verses": 13, "isMeccan": false, "juz": 28},
    {"id": 61, "name": "الصف", "type": "مدنية", "verses": 14, "isMeccan": false, "juz": 28},
    {"id": 62, "name": "الجمعة", "type": "مدنية", "verses": 11, "isMeccan": false, "juz": 28},
    {"id": 63, "name": "المنافقون", "type": "مدنية", "verses": 11, "isMeccan": false, "juz": 28},
    {"id": 64, "name": "التغابن", "type": "مدنية", "verses": 18, "isMeccan": false, "juz": 28},
    {"id": 65, "name": "الطلاق", "type": "مدنية", "verses": 12, "isMeccan": false, "juz": 28},
    {"id": 66, "name": "التحريم", "type": "مدنية", "verses": 12, "isMeccan": false, "juz": 28},
    {"id": 67, "name": "الملك", "type": "مكية", "verses": 30, "isMeccan": true, "juz": 29},
    {"id": 68, "name": "القلم", "type": "مكية", "verses": 52, "isMeccan": true, "juz": 29},
    {"id": 69, "name": "الحاقة", "type": "مكية", "verses": 52, "isMeccan": true, "juz": 29},
    {"id": 70, "name": "المعارج", "type": "مكية", "verses": 44, "isMeccan": true, "juz": 29},
    {"id": 71, "name": "نوح", "type": "مكية", "verses": 28, "isMeccan": true, "juz": 29},
    {"id": 72, "name": "الجن", "type": "مكية", "verses": 28, "isMeccan": true, "juz": 29},
    {"id": 73, "name": "المزمل", "type": "مكية", "verses": 20, "isMeccan": true, "juz": 29},
    {"id": 74, "name": "المدثر", "type": "مكية", "verses": 56, "isMeccan": true, "juz": 29},
    {"id": 75, "name": "القيامة", "type": "مكية", "verses": 40, "isMeccan": true, "juz": 29},
    {"id": 76, "name": "الإنسان", "type": "مدنية", "verses": 31, "isMeccan": false, "juz": 29},
    {"id": 77, "name": "المرسلات", "type": "مكية", "verses": 50, "isMeccan": true, "juz": 29},
    {"id": 78, "name": "النبأ", "type": "مكية", "verses": 40, "isMeccan": true, "juz": 30},
    {"id": 79, "name": "النازعات", "type": "مكية", "verses": 46, "isMeccan": true, "juz": 30},
    {"id": 80, "name": "عبس", "type": "مكية", "verses": 42, "isMeccan": true, "juz": 30},
    {"id": 81, "name": "التكوير", "type": "مكية", "verses": 29, "isMeccan": true, "juz": 30},
    {"id": 82, "name": "الانفطار", "type": "مكية", "verses": 19, "isMeccan": true, "juz": 30},
    {"id": 83, "name": "المطففين", "type": "مكية", "verses": 36, "isMeccan": true, "juz": 30},
    {"id": 84, "name": "الانشقاق", "type": "مكية", "verses": 25, "isMeccan": true, "juz": 30},
    {"id": 85, "name": "البروج", "type": "مكية", "verses": 22, "isMeccan": true, "juz": 30},
    {"id": 86, "name": "الطارق", "type": "مكية", "verses": 17, "isMeccan": true, "juz": 30},
    {"id": 87, "name": "الأعلى", "type": "مكية", "verses": 19, "isMeccan": true, "juz": 30},
    {"id": 88, "name": "الغاشية", "type": "مكية", "verses": 26, "isMeccan": true, "juz": 30},
    {"id": 89, "name": "الفجر", "type": "مكية", "verses": 30, "isMeccan": true, "juz": 30},
    {"id": 90, "name": "البلد", "type": "مكية", "verses": 20, "isMeccan": true, "juz": 30},
    {"id": 91, "name": "الشمس", "type": "مكية", "verses": 15, "isMeccan": true, "juz": 30},
    {"id": 92, "name": "الليل", "type": "مكية", "verses": 21, "isMeccan": true, "juz": 30},
    {"id": 93, "name": "الضحى", "type": "مكية", "verses": 11, "isMeccan": true, "juz": 30},
    {"id": 94, "name": "الشرح", "type": "مكية", "verses": 8, "isMeccan": true, "juz": 30},
    {"id": 95, "name": "التين", "type": "مكية", "verses": 8, "isMeccan": true, "juz": 30},
    {"id": 96, "name": "العلق", "type": "مكية", "verses": 19, "isMeccan": true, "juz": 30},
    {"id": 97, "name": "القدر", "type": "مكية", "verses": 5, "isMeccan": true, "juz": 30},
    {"id": 98, "name": "البينة", "type": "مدنية", "verses": 8, "isMeccan": false, "juz": 30},
    {"id": 99, "name": "الزلزلة", "type": "مدنية", "verses": 8, "isMeccan": false, "juz": 30},
    {"id": 100, "name": "العاديات", "type": "مكية", "verses": 11, "isMeccan": true, "juz": 30},
    {"id": 101, "name": "القارعة", "type": "مكية", "verses": 11, "isMeccan": true, "juz": 30},
    {"id": 102, "name": "التكاثر", "type": "مكية", "verses": 8, "isMeccan": true, "juz": 30},
    {"id": 103, "name": "العصر", "type": "مكية", "verses": 3, "isMeccan": true, "juz": 30},
    {"id": 104, "name": "الهمزة", "type": "مكية", "verses": 9, "isMeccan": true, "juz": 30},
    {"id": 105, "name": "الفيل", "type": "مكية", "verses": 5, "isMeccan": true, "juz": 30},
    {"id": 106, "name": "قريش", "type": "مكية", "verses": 4, "isMeccan": true, "juz": 30},
    {"id": 107, "name": "الماعون", "type": "مكية", "verses": 7, "isMeccan": true, "juz": 30},
    {"id": 108, "name": "الكوثر", "type": "مكية", "verses": 3, "isMeccan": true, "juz": 30},
    {"id": 109, "name": "الكافرون", "type": "مكية", "verses": 6, "isMeccan": true, "juz": 30},
    {"id": 110, "name": "النصر", "type": "مدنية", "verses": 3, "isMeccan": false, "juz": 30},
    {"id": 111, "name": "المسد", "type": "مكية", "verses": 5, "isMeccan": true, "juz": 30},
    {"id": 112, "name": "الإخلاص", "type": "مكية", "verses": 4, "isMeccan": true, "juz": 30},
    {"id": 113, "name": "الفلق", "type": "مكية", "verses": 5, "isMeccan": true, "juz": 30},
    {"id": 114, "name": "الناس", "type": "مكية", "verses": 6, "isMeccan": true, "juz": 30}
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadAppSettings();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
          }
        });
      }
    });

    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) {
        setState(() => _duration = d);
      }
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });
  }

  // تحميل الإعدادات من الذاكرة الدائمة عند فتح التطبيق
  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguage = prefs.getString('app_lang') ?? 'ar';
      _selectedReciter = prefs.getString('app_reciter') ?? 'afs';
      _globalFontSize = prefs.getDouble('font_size') ?? 24.0;
    });
  }

  // حفظ التحديثات في الذاكرة الدائمة تلقائياً
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getTranslatedTitle() {
    if (_currentLanguage == 'en') {
      if (_currentIndex == 0) return 'Holy Quran';
      if (_currentIndex == 1) return 'Audio Recitations';
      return 'Application Settings';
    } else if (_currentLanguage == 'tr') {
      if (_currentIndex == 0) return 'Kur\'an-ı Kerim';
      if (_currentIndex == 1) return 'Sesli Dinleme';
      return 'Uygulama Ayarları';
    }
    if (_currentIndex == 0) return 'القرآن الكريم';
    if (_currentIndex == 1) return 'الصوتيات والتلاوات';
    return 'إعدادات التطبيق';
  }

  Future<void> _playSurahAudio(int surahId) async {
    if (_currentPlayingSurahId == surahId) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
      return;
    }

    try {
      setState(() {
        _currentPlayingSurahId = surahId;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      String formattedId = surahId.toString().padLeft(3, '0');
      String serverName = "server8.mp3quran.net/afs";
      if (_selectedReciter == 'shrt') serverName = "server7.mp3quran.net/shur";
      if (_selectedReciter == 'gmd') serverName = "server8.mp3quran.net/gmd";
      if (_selectedReciter == 'basit') serverName = "server7.mp3quran.net/basit_mtwstr";
      if (_selectedReciter == 'hudhaifi') serverName = "server9.mp3quran.net/huzaifi";

      String audioUrl = "https://$serverName/$formattedId.mp3";

      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطأ في الاتصال بالشبكة أو تشغيل السورة")),
      );
    }
  }

  // التبويب الأول: الفهرس والمصحف للقراءة
  Widget _buildSurahListTab() {
    return ListView.builder(
      itemCount: surahList.length,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemBuilder: (context, index) {
        final surah = surahList[index];
        final String arabicId = toArabicNumerals(surah['id'] as int);
        final String arabicVerses = toArabicNumerals(surah['verses'] as int);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: const Color(0xFFE0E0E0).withOpacity(0.6), width: 1), 
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF9F9F6)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  arabicId,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              title: Text(
                "سورة ${surah['name']}", 
                style: const TextStyle(
                  fontFamily: kSurahNameFont,
                  fontSize: 26,
                  color: Color(0xFF2C3E50),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: surah['isMeccan'] ? const Color(0xFFFFF3E0) : const Color(0xFFE1F5FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            surah['isMeccan'] ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                            height: 16,
                            width: 16,
                            errorBuilder: (context, error, stackTrace) => Text(
                              surah['type'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: surConditionColor(surah['isMeccan']),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            surah['type'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: surConditionColor(surah['isMeccan']),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "• آياتها: $arabicVerses",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_left, size: 22, color: Color(0xFF2E7D32)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahDetailScreen(
                      surahId: surah['id'] as int,
                      surahName: surah['name'] as String,
                      versesCount: surah['verses'] as int,
                      surahType: surah['type'] as String,
                      initialJuz: surah['juz'] as int, 
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // التبويب الثاني: الاستماع الصوتي
  Widget _buildAudioTab() {
    return ListView.builder(
      itemCount: surahList.length,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemBuilder: (context, index) {
        final surah = surahList[index];
        final String arabicId = toArabicNumerals(surah['id'] as int);
        final bool isCurrentSurah = _currentPlayingSurahId == surah['id'];

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isCurrentSurah ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32).withOpacity(0.1),
              child: Text(
                arabicId,
                style: TextStyle(
                  color: isCurrentSurah ? Colors.white : const Color(0xFF2E7D32), 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            title: Text(
              "تلاوة سورة ${surah['name']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            subtitle: Text(
              isCurrentSurah && _isPlaying ? "جاري الاستماع الآن..." : "اضغط للاستماع للتلاوة العطرة",
              style: TextStyle(color: isCurrentSurah ? const Color(0xFF2E7D32) : Colors.grey[600], fontSize: 12),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: isCurrentSurah && _isPlaying ? Colors.orange : const Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  isCurrentSurah && _isPlaying ? Icons.pause : Icons.play_arrow, 
                  color: Colors.white, 
                  size: 20
                ),
              ),
            ),
            onTap: () => _playSurahAudio(surah['id'] as int),
          ),
        );
      },
    );
  }

  // التبويب الثالث الجديد: لوحة التحكم والإعدادات المتكاملة للتطبيق
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // قسم اللغة العامة للواجهات
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.language, color: Color(0xFF1B5E20)),
                    SizedBox(width: 8),
                    Text("لغة واجهة التطبيق / Interface Language", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _currentLanguage,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text("العربية")),
                    DropdownMenuItem(value: 'en', child: Text("English")),
                    DropdownMenuItem(value: 'tr', child: Text("Türkçe")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currentLanguage = val);
                      _saveSetting('app_lang', val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // قسم القارئ الافتراضي لقسم الصوتيات
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, color: Color(0xFF1B5E20)),
                    SizedBox(width: 8),
                    Text("القارئ الافتراضي للصوتيات", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedReciter,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: recitersList.map((r) {
                    return DropdownMenuItem(value: r['id'], child: Text(r['name']!));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedReciter = val);
                      _saveSetting('app_reciter', val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // قسم تخصيص الخط الافتراضي العام
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.text_fields, color: Color(0xFF1B5E20)),
                        SizedBox(width: 8),
                        Text("حجم الخط الافتراضي للمصحف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Text("${_globalFontSize.toInt()} pt", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _globalFontSize,
                  min: 20,
                  max: 40,
                  divisions: 10,
                  activeColor: const Color(0xFF2E7D32),
                  onChanged: (v) {
                    setState(() => _globalFontSize = v);
                    _saveSetting('font_size', v);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // قسم معلومات حول التطبيق وإخلاء المسؤولية
        const Center(
          child: Column(
            children: [
              Text("تطبيق المصحف الشريف الإلكتروني v1.0.0", style: TextStyle(color: Colors.grey, fontSize: 13)),
              SizedBox(height: 4),
              Text("جميع التلاوات الصوتية تعمل عبر خوادم شبكة MP3Quran المباشرة", style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMiniAudioPlayer() {
    if (_currentPlayingSurahId == null) return const SizedBox.shrink();

    final currentSurah = surahList.firstWhere((s) => s['id'] == _currentPlayingSurahId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, -2))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: Color(0xFFFFD700)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "المشغل الحالي: سورة ${currentSurah['name']}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 32),
                  onPressed: () => _playSurahAudio(_currentPlayingSurahId!),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () async {
                    await _audioPlayer.stop();
                    setState(() {
                      _currentPlayingSurahId = null;
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Expanded(
                  child: Slider(
                    activeColor: const Color(0xFFFFD700),
                    inactiveColor: Colors.white30,
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble() > 0 
                        ? _duration.inMilliseconds.toDouble() 
                        : 1.0,
                    onChanged: (value) async {
                      await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الواجهة البرمجية المناسبة حسب التبويب الحالي
    Widget currentTabWidget = _buildSurahListTab();
    if (_currentIndex == 1) currentTabWidget = _buildAudioTab();
    if (_currentIndex == 2) currentTabWidget = _buildSettingsTab();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _currentIndex == 0 ? Icons.menu_book : (_currentIndex == 1 ? Icons.headset : Icons.settings), 
                color: const Color(0xFFFFD700), 
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _getTranslatedTitle(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.black38,
        ),
        body: Column(
          children: [
            Expanded(child: currentTabWidget),
            _buildMiniAudioPlayer(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xFF1B5E20),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'المصحف للقراءة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.headset),
              label: 'الصوتيات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
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

Color surConditionColor(bool isMeccan) {
  return isMeccan ? const Color(0xFFE65100) : const Color(0xFF01579B);
}
