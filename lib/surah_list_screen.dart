import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'surah_detail_screen.dart'; 
import 'utils.dart';

const String kSurahNameFont = 'surah_nam';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  late AudioPlayer _audioPlayer;
  int? _currentPlayingSurahId;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String _currentLanguage = 'ar'; 
  String _selectedReciterId = '123'; // القارئ الافتراضي

  List<dynamic> _recitersList = [];
  bool _isLoadingReciters = true;
  int? _lastReadSurahId;
  int _selectedTabIndex = 0;
  bool _isDarkMode = false;

  Color get _pageColor => _isDarkMode ? const Color(0xFF101713) : const Color(0xFFF7F5EC);
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1A2620) : Colors.white;
  Color get _textColor => _isDarkMode ? const Color(0xFFECEFEA) : const Color(0xFF20352A);
  Color get _mutedTextColor => _isDarkMode ? const Color(0xFFB8C5BC) : const Color(0xFF68766D);

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
    _loadRecitersData().then((_) {
      _loadAppSettings();
    });

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

  Future<void> _loadRecitersData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/data/readers.json');
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> data = [];
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map && decoded.containsKey('reciters')) {
        data = decoded['reciters'];
      } else if (decoded is Map) {
        data = decoded.values.firstWhere((v) => v is List, orElse: () => []) as List;
      }
      if (!mounted) return;
      setState(() {
        _recitersList = data;
        _isLoadingReciters = false;
      });
    } catch (e) {
      debugPrint("خطأ في قراءة ملف صوتيات القراء readers.json: $e");
      if (mounted) setState(() => _isLoadingReciters = false);
    }
  }

  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _currentLanguage = prefs.getString('app_lang') ?? 'ar';
      _selectedReciterId = prefs.getString('app_reciter') ?? '123';
      _lastReadSurahId = prefs.getInt('last_read_surah');
      _isDarkMode = prefs.getBool('app_dark_mode') ?? false;
    });
  }

  Future<void> _openSurah(Map<String, dynamic> surah) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSurahId = prefs.getInt('last_surah');
    final savedVerse = prefs.getInt('last_verse');
    int? initialVerse;
    Map<String, dynamic> targetSurah = surah;

    if (savedSurahId != null && savedVerse != null && savedVerse > 0) {
      final savedSurah = surahList.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == savedSurahId,
        orElse: () => null,
      );
      if (savedSurah != null) {
        final shouldResume = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('متابعة القراءة؟', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text('آخر موضع قراءة كان في سورة ${savedSurah['name']}، الآية ${toArabicNumerals(savedVerse)}. هل تريد الذهاب إليه؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لا، ابدأ من السورة المختارة')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('نعم، تابع القراءة')),
              ],
            ),
          ),
        );
        if (!mounted) return;
        if (shouldResume == true) {
          targetSurah = savedSurah;
          initialVerse = savedVerse;
        } else {
          initialVerse = 1;
        }
      }
    }

    final int id = targetSurah['id'] as int;
    await prefs.setInt('last_read_surah', id);
    if (!mounted) return;
    setState(() => _lastReadSurahId = id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahDetailScreen(
          surahId: id,
          surahName: targetSurah['name'] as String,
          versesCount: targetSurah['verses'] as int,
          surahType: targetSurah['type'] as String,
          initialJuz: targetSurah['juz'] as int,
          initialVerse: initialVerse,
        ),
      ),
    );
    final refreshed = await SharedPreferences.getInstance();
    if (mounted) setState(() => _lastReadSurahId = refreshed.getInt('last_read_surah'));
  }

  String _selectedReciterName() {
    for (final dynamic reciter in _recitersList) {
      if (reciter is Map && reciter['id'].toString() == _selectedReciterId) {
        return (reciter[_currentLanguage] ?? reciter['ar'] ?? reciter['en'] ?? reciter['name'] ?? 'قارئ غير معروف').toString();
      }
    }
    return 'القارئ المختار';
  }

  Widget _reciterPicker({bool compact = false}) {
    const green = Color(0xFF174D35);
    return DropdownButtonFormField<String>(
      value: _recitersList.any((r) => r['id'].toString() == _selectedReciterId)
          ? _selectedReciterId
          : (_recitersList.isNotEmpty ? _recitersList.first['id'].toString() : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: compact ? 'القارئ' : 'اختر القارئ',
        prefixIcon: const Icon(Icons.record_voice_over_rounded, color: green),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: _recitersList.map<DropdownMenuItem<String>>((dynamic r) {
        final name = r[_currentLanguage] ?? r['ar'] ?? r['en'] ?? r['name'] ?? 'قارئ غير معروف';
        return DropdownMenuItem<String>(value: r['id'].toString(), child: Text(name.toString(), overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        if (_currentPlayingSurahId != null) {
          await _audioPlayer.stop();
        }
        setState(() {
          _selectedReciterId = value;
          _currentPlayingSurahId = null;
          _position = Duration.zero;
          _duration = Duration.zero;
        });
        await _saveSetting('app_reciter', value);
      },
    );
  }

  // تم تصحيح الخطأ هنا عبر استخدام setString بدلاً من setInt للقيم النصية
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getTranslatedTitle(int index) {
    if (_currentLanguage == 'en') {
      if (index == 0) return 'Home';
      if (index == 1) return 'Holy Quran';
      if (index == 2) return 'Audio';
      return 'Settings';
    } else if (_currentLanguage == 'tr') {
      if (index == 0) return 'Ana Sayfa';
      if (index == 1) return 'Kur\'an';
      if (index == 2) return 'Sesli';
      return 'Ayarlar';
    }
    if (index == 0) return 'الرئيسية';
    if (index == 1) return 'القرآن الكريم';
    if (index == 2) return 'التلاوات';
    return 'الإعدادات';
  }

  Future<void> _playSurahAudio(int surahId) async {
    if (_currentPlayingSurahId == surahId && _isPlaying) {
      await _audioPlayer.pause();
      return;
    } else if (_currentPlayingSurahId == surahId && !_isPlaying) {
      await _audioPlayer.play();
      return;
    }

    try {
      setState(() {
        _currentPlayingSurahId = surahId;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      String audioUrl = '';

      try {
        String jsonString = await rootBundle.loadString('assets/audiourls/$_selectedReciterId.json');
        final dynamic decoded = jsonDecode(jsonString);
        if (decoded is List && decoded.isNotEmpty) {
          if (decoded.length >= surahId) {
            var item = decoded[surahId - 1];
            if (item is String) {
              audioUrl = item;
            } else if (item is Map) {
              final rawUrl = item['F2'] ?? item['url'] ?? item['server'];
              if (rawUrl is String) audioUrl = rawUrl;
            }
          }
        }
      } catch (_) {}

      if (audioUrl.isEmpty && _selectedReciterId == '123') {
        final formattedSurahNum = surahId.toString().padLeft(3, '0');
        audioUrl = 'https://server8.mp3quran.net/afs/$formattedSurahNum.mp3';
      }

      if (audioUrl.isNotEmpty) {
        await _audioPlayer.setUrl(Uri.encodeFull(audioUrl));
        await _audioPlayer.play();
      } else {
        throw Exception("رابط التلاوة فارغ");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذّر تشغيل التلاوة الصوتية")),
        );
      }
    }
  }

  Color surConditionColor(bool isMeccan) {
    return isMeccan ? const Color(0xFFE65100) : const Color(0xFF0277BD);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF174D35);
    const gold = Color(0xFFD6B45C);

    final theme = ThemeData(
      useMaterial3: true,
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: _pageColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF176344),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primary: const Color(0xFF176344),
        secondary: const Color(0xFFD6B45C),
        surface: _surfaceColor,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme,
        child: DefaultTabController(
        length: 4,
        child: Builder(
          builder: (tabContext) => Scaffold(
            backgroundColor: _pageColor,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: green,
              foregroundColor: Colors.white,
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, color: gold, size: 27),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _currentLanguage == 'ar'
                          ? 'مصحف المدينة المنورة'
                          : _currentLanguage == 'tr'
                              ? 'Medine Mushafı'
                              : 'Madinah Quran',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildHomeTab(tabContext),
                      _buildSurahListTab(),
                      _buildAudioTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                ),
                _buildMiniAudioPlayer(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedTabIndex,
              backgroundColor: _surfaceColor,
              indicatorColor: _isDarkMode ? const Color(0xFF294B3A) : const Color(0xFFE8F1E9),
              onDestinationSelected: (index) {
                setState(() => _selectedTabIndex = index);
                DefaultTabController.of(tabContext).animateTo(index);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'المصحف'),
                NavigationDestination(icon: Icon(Icons.headphones_outlined), selectedIcon: Icon(Icons.headphones_rounded), label: 'الصوتيات'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext tabContext) {
    const green = Color(0xFF174D35);
    const gold = Color(0xFFD6B45C);
    final last = surahList.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == _lastReadSurahId,
      orElse: () => null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: gold.withOpacity(.75), width: 1),
          ),
          child: Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.menu_book_rounded, color: gold, size: 30)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المصحف الشريف', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text('اقرأ، واستمع، واحفظ موضعك بسهولة', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('متابعة القراءة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: green.withOpacity(.25))),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F1E9), child: Icon(Icons.bookmark_added_rounded, color: green)),
            title: Text(last?['name'] as String? ?? 'ابدأ من سورة الفاتحة', style: TextStyle(fontFamily: kSurahNameFont, fontSize: 26, color: _isDarkMode ? const Color(0xFFE4D19A) : green)),
            subtitle: Text('سيظهر سؤال للرجوع إلى آخر آية قرأتها', style: TextStyle(color: _mutedTextColor)),
            trailing: const Icon(Icons.chevron_left_rounded, color: green),
            onTap: () => _openSurah(last ?? surahList.first),
          ),
        ),
        const SizedBox(height: 12),
        _homeAction(icon: Icons.headphones_rounded, title: 'الصوتيات والقراء', subtitle: 'اختر القارئ ثم السورة التي تريد سماعها', onTap: () { setState(() => _selectedTabIndex = 2); DefaultTabController.of(tabContext).animateTo(2); }),
        _homeAction(icon: Icons.library_books_rounded, title: 'قائمة السور', subtitle: 'انتقل مباشرة إلى أي سورة', onTap: () { setState(() => _selectedTabIndex = 1); DefaultTabController.of(tabContext).animateTo(1); }),
        _homeAction(icon: Icons.tune_rounded, title: 'الإعدادات', subtitle: 'لغة التطبيق وتفضيلات القراءة', onTap: () { setState(() => _selectedTabIndex = 3); DefaultTabController.of(tabContext).animateTo(3); }),
      ],
    );
  }

  Widget _homeAction({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    const green = Color(0xFF174D35);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE8F1E9), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: green)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? const Color(0xFFE4D19A) : green)),
        subtitle: Text(subtitle, style: TextStyle(color: _mutedTextColor)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSurahListTab() {
    const green = Color(0xFF174D35);
    const gold = Color(0xFFD6B45C);

    Map<String, dynamic>? lastSurah;
    for (final surah in surahList) {
      if (surah['id'] == _lastReadSurahId) {
        lastSurah = surah;
        break;
      }
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('quran_surah_list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF174D35), Color(0xFF287653)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: green.withOpacity(0.16),
                    blurRadius: 15,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -12,
                    top: -15,
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 115,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.waving_hand_rounded, color: gold, size: 23),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'أهلًا بك في رحاب القرآن الكريم',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'اقرأ، وتدبّر، واطمئن',
                        style: TextStyle(
                          color: gold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'سورة الرعد · الآية ٢٨',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: green,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          onPressed: () => _openSurah(surahList.first),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text(
                            'ابدأ القراءة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (lastSurah != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_rounded, color: green),
                      const SizedBox(width: 8),
                      Text(
                        'متابعة القراءة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? const Color(0xFFE4D19A) : green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    color: _surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: green.withOpacity(0.12)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F2E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.bookmark_added_rounded,
                          color: green,
                        ),
                      ),
                      title: Text(
                        lastSurah['name'] as String,
                        style: const TextStyle(
                          fontFamily: kSurahNameFont,
                          fontSize: 27,
                          color: green,
                        ),
                      ),
                      subtitle: const Text('آخر سورة فتحتها'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: green,
                        size: 18,
                      ),
                      onTap: () => _openSurah(lastSurah!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(Icons.library_books_rounded, color: green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'سور القرآن الكريم',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEE6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${toArabicNumerals(surahList.length)} سورة',
                    style: const TextStyle(
                      color: green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final surah = surahList[index];
                final int id = surah['id'] as int;
                final bool isMeccan = surah['isMeccan'] as bool;
                final bool isLastRead = id == _lastReadSurahId;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 9),
                  color: _surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                    side: BorderSide(
                      color: isLastRead
                          ? gold.withOpacity(0.9)
                          : Colors.black.withOpacity(0.045),
                      width: isLastRead ? 1.4 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 5,
                    ),
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: isLastRead
                            ? const Color(0xFFFFF3D5)
                            : const Color(0xFFE8F2E9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        toArabicNumerals(id),
                        style: TextStyle(
                          color: isLastRead ? Colors.brown : green,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      surah['name'] as String,
                      style: const TextStyle(
                        fontFamily: kSurahNameFont,
                        fontSize: 29,
                        color: Color(0xFF263D32),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMeccan
                                  ? const Color(0xFFFFF0E2)
                                  : const Color(0xFFE4F3FA),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              surah['type'] as String,
                              style: TextStyle(
                                color: isMeccan
                                    ? const Color(0xFFB85B18)
                                    : const Color(0xFF176D91),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${toArabicNumerals(surah['verses'] as int)} آية',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          if (isLastRead)
                            const Text(
                              'آخر قراءة',
                              style: TextStyle(
                                color: Color(0xFF947025),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_left_rounded,
                      color: green,
                      size: 25,
                    ),
                    onTap: () => _openSurah(surah),
                  ),
                );
              },
              childCount: surahList.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioTab() {
    const green = Color(0xFF174D35);
    final currentSurah = _currentPlayingSurahId == null ? null : surahList.cast<Map<String, dynamic>?>().firstWhere((s) => s?['id'] == _currentPlayingSurahId, orElse: () => null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text('الصوتيات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 5),
        const Text('اختر القارئ أولاً، ثم اضغط على السورة لتشغيلها.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        _isLoadingReciters ? const LinearProgressIndicator() : _reciterPicker(),
        const SizedBox(height: 12),
        if (currentSurah != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE8F1E9), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.graphic_eq_rounded, color: green, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedReciterName(), style: const TextStyle(color: green, fontWeight: FontWeight.bold)),
                Text('سورة ${currentSurah['name']}', style: const TextStyle(color: green, fontSize: 15)),
                Text(_isPlaying ? 'جاري التشغيل' : 'متوقف مؤقتًا', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
              IconButton(onPressed: () => _playSurahAudio(_currentPlayingSurahId!), icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: green, size: 34)),
            ]),
          ),
        const SizedBox(height: 12),
        ...surahList.map((surah) {
          final id = surah['id'] as int;
          final isCurrent = _currentPlayingSurahId == id;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: _surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isCurrent ? green.withOpacity(.5) : Colors.black12)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFE8F1E9), child: Text(toArabicNumerals(id), style: const TextStyle(color: green, fontWeight: FontWeight.bold))),
              title: Text(surah['name'] as String, style: TextStyle(fontFamily: kSurahNameFont, fontSize: 27, color: _isDarkMode ? const Color(0xFFE4D19A) : green)),
              subtitle: Text('${_selectedReciterName()} • سورة ${surah['name']}', style: TextStyle(fontSize: 12, color: _mutedTextColor)),
              trailing: Icon(isCurrent && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: green, size: 32),
              onTap: () => _playSurahAudio(id),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: _surfaceColor,
          child: SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded, color: Color(0xFFD6B45C), size: 28),
            title: Text('المظهر الداكن', style: TextStyle(fontWeight: FontWeight.bold, color: _textColor)),
            subtitle: Text(_isDarkMode ? 'الوضع الداكن مفعّل' : 'التبديل بين المظهر الفاتح والداكن', style: TextStyle(color: _mutedTextColor)),
            value: _isDarkMode,
            activeColor: const Color(0xFFD6B45C),
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              _saveSetting('app_dark_mode', value);
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: _surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.language, color: Color(0xFF287653), size: 26),
                    SizedBox(width: 10),
                    Text("لغة واجهة التطبيق", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF287653))),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _currentLanguage,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, color: Color(0xFF287653), size: 26),
                    SizedBox(width: 10),
                    Text("القارئ الافتراضي للصوتيات", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF287653))),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoadingReciters ? const Center(child: CircularProgressIndicator()) : _reciterPicker(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Center(
          child: Column(
            children: [
              Text("تطبيق المصحف الشريف الإلكتروني v1.0.0", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text("جميع التلاوات الصوتية تعمل عبر شبكة MP3Quran المباشرة", style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
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
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, -2))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    "${_selectedReciterName()} • سورة ${currentSurah['name']}",
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
                    value: _duration.inMilliseconds > 0
                        ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                        : 0.0,
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
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
}
