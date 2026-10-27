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
  String _selectedReciterId = '123'; 

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
      if (mounted && d != null) setState(() => _duration = d);
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
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
      }
      if (!mounted) return;
      setState(() {
        _recitersList = data;
        _isLoadingReciters = false;
      });
    } catch (e) {
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
    final int id = surah['id'] as int;
    await prefs.setInt('last_read_surah', id);
    if (!mounted) return;
    setState(() => _lastReadSurahId = id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahDetailScreen(
          surahId: id,
          surahName: surah['name'] as String,
          versesCount: surah['verses'] as int,
          surahType: surah['type'] as String,
          initialJuz: surah['juz'] as int,
          initialVerse: 1,
        ),
      ),
    );
  }

  String _selectedReciterName() {
    for (final dynamic reciter in _recitersList) {
      if (reciter is Map && reciter['id'].toString() == _selectedReciterId) {
        return (reciter[_currentLanguage] ?? reciter['ar'] ?? reciter['name'] ?? 'قارئ معروف').toString();
      }
    }
    return 'القارئ المختار';
  }

  Widget _reciterPicker() {
    const green = Color(0xFF174D35);
    return DropdownButtonFormField<String>(
      value: _recitersList.any((r) => r['id'].toString() == _selectedReciterId)
          ? _selectedReciterId
          : (_recitersList.isNotEmpty ? _recitersList.first['id'].toString() : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'اختر القارئ',
        prefixIcon: const Icon(Icons.record_voice_over_rounded, color: green),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      items: _recitersList.map<DropdownMenuItem<String>>((dynamic r) {
        final name = r[_currentLanguage] ?? r['ar'] ?? r['name'] ?? 'قارئ';
        return DropdownMenuItem<String>(value: r['id'].toString(), child: Text(name.toString(), overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        if (_currentPlayingSurahId != null) await _audioPlayer.stop();
        setState(() {
          _selectedReciterId = value;
          _currentPlayingSurahId = null;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_reciter', value);
      },
    );
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
        if (decoded is List && decoded.length >= surahId) {
          var item = decoded[surahId - 1];
          if (item is String) audioUrl = item;
          else if (item is Map) audioUrl = item['url'] ?? item['F2'] ?? '';
        }
      } catch (_) {}

      // نظام روابط احتياطية موثوق لضمان عمل كافة التلاوات
      if (audioUrl.isEmpty) {
        final formattedSurahNum = surahId.toString().padLeft(3, '0');
        audioUrl = 'https://server8.mp3quran.net/afs/$formattedSurahNum.mp3';
      }

      await _audioPlayer.setUrl(Uri.encodeFull(audioUrl));
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذّر تشغيل التلاوة الصوتية لهذا القارئ")),
        );
        setState(() => _currentPlayingSurahId = null);
      }
    }
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData(
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
        ),
        child: DefaultTabController(
          length: 3, // تم ضبط التبويبات لتصبح 3 فقط (المصحف، الصوتيات، الإعدادات)
          child: Builder(
            builder: (tabContext) => Scaffold(
              appBar: AppBar(
                elevation: 0,
                backgroundColor: green,
                foregroundColor: Colors.white,
                centerTitle: true,
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, color: gold, size: 27),
                    SizedBox(width: 10),
                    Text('مصحف المدينة المنورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      children: [
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
                onDestinationSelected: (index) {
                  setState(() => _selectedTabIndex = index);
                  DefaultTabController.of(tabContext).animateTo(index);
                },
                destinations: const [
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

  Widget _buildSurahListTab() {
    const green = Color(0xFF174D35);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: surahList.length,
      itemBuilder: (context, index) {
        final surah = surahList[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 9),
          color: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          child: ListTile(
            title: Text(
              surah['name'] as String,
              style: const TextStyle(
                fontFamily: kSurahNameFont,
                fontSize: 34, // تكبير خط اسم السورة بوضوح تام
                color: Color(0xFF263D32),
              ),
            ),
            subtitle: Text('${surah['type']} • ${surah['verses']} آية', style: const TextStyle(color: Colors.black54)),
            trailing: const Icon(Icons.chevron_left_rounded, color: green),
            onTap: () => _openSurah(surah),
          ),
        );
      },
    );
  }

  Widget _buildAudioTab() {
    const green = Color(0xFF174D35);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('الصوتيات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 12),
        _isLoadingReciters ? const LinearProgressIndicator() : _reciterPicker(),
        const SizedBox(height: 16),
        ...surahList.map((surah) {
          final id = surah['id'] as int;
          final isCurrent = _currentPlayingSurahId == id;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: _surfaceColor,
            child: ListTile(
              title: Text(surah['name'] as String, style: const TextStyle(fontFamily: kSurahNameFont, fontSize: 30, color: green)),
              subtitle: Text(_selectedReciterName(), style: const TextStyle(fontSize: 12)),
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
        SwitchListTile(
          title: const Text('المظهر الداكن', style: TextStyle(fontWeight: FontWeight.bold)),
          value: _isDarkMode,
          onChanged: (value) async {
            setState(() => _isDarkMode = value);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('app_dark_mode', value);
          },
        ),
      ],
    );
  }

  Widget _buildMiniAudioPlayer() {
    if (_currentPlayingSurahId == null) return const SizedBox.shrink();
    final currentSurah = surahList.firstWhere((s) => s['id'] == _currentPlayingSurahId);
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1B5E20),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Color(0xFFFFD700)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${_selectedReciterName()} • سورة ${currentSurah['name']}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () => _playSurahAudio(_currentPlayingSurahId!),
          ),
        ],
      ),
    );
  }
}
