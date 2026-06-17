import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

// دالة تحويل الأرقام إلى عربية (١، ٢، ٣...)
String toArabicNumerals(int number) {
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number.toString().split('').map((char) {
    return arabicDigits[int.parse(char)];
  }).join();
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFFFDFBF7), // لون خلفية مريح للعين يشبه الورق
        ),
        home: const SurahListScreen(),
      ),
    );
  }
}

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  int? _lastSurahId;
  String? _lastSurahName;
  int? _lastVersesCount;
  String? _lastSurahType;

  @override
  void initState() {
    super.initState();
    _loadLastReadPosition();
  }

  Future<void> _loadLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSurahId = prefs.getInt('last_surah_id');
      _lastSurahName = prefs.getString('last_surah_name');
      _lastVersesCount = prefs.getInt('last_verses_count');
      _lastSurahType = prefs.getString('last_surah_type');
    });
  }

  Future<List<dynamic>> loadQuranIndex() async {
    final String response = await rootBundle.loadString('assets/data/quran_data.json');
    return json.decode(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_lastSurahId != null && _lastSurahName != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bookmark),
                label: Text('العودة إلى آخر موضع قراءة: $_lastSurahName'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surahId: _lastSurahId!,
                        surahName: _lastSurahName!,
                        versesCount: _lastVersesCount ?? 0,
                        surahType: _lastSurahType ?? 'مكية',
                      ),
                    ),
                  );
                  _loadLastReadPosition();
                },
              ),
            ),
          
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: loadQuranIndex(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final surahs = snapshot.data!;
                return ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    bool isMeccan = surah['type'] == 'مكية';
                    int vCount = surah['verses_count'] ?? 0;
                    
                    // تصميم مخصص من الجهة اليمنى للفهرس وبمحاذاة تامة
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurahDetailScreen(
                                surahId: surah['id'],
                                surahName: surah['name'],
                                versesCount: vCount,
                                surahType: surah['type'] ?? 'مكية',
                              ),
                            ),
                          );
                          _loadLastReadPosition();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            children: [
                              // الأيقونة جهة اليمين
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Image.asset(
                                  isMeccan ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // النصوص بمحاذاة يمين كاملة
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      surah['name'], 
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isMeccan ? "مكية | آياتها: $vCount" : "مدنية | آياتها: $vCount",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              // سهم التنقل جهة اليسار
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;

  const SurahDetailScreen({
    super.key, 
    required this.surahId, 
    required this.surahName,
    required this.versesCount,
    required this.surahType,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  double _fontSize = 24.0;
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _surahDataFuture;
  List<String> _currentVerses = [];

  @override
  void initState() {
    super.initState();
    _saveLastReadPosition();
    _surahDataFuture = loadSurahData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_verses_count', widget.versesCount);
    await prefs.setString('last_surah_type', widget.surahType);
  }

  // دالة تحديد الجزء بناءً على رقم السورة (تقريبية ذكية وهيكلية)
  String _getJuzText(int surahId) {
    if (surahId == 1) return "الجزء الأول";
    if (surahId == 2) return "من الجزء 1 إلى 3";
    if (surahId == 3) return "من الجزء 3 إلى 4";
    if (surahId == 4) return "من الجزء 4 إلى 6";
    if (surahId >= 5 && surahId <= 6) return "من الجزء 6 إلى 8";
    if (surahId >= 7 && surahId <= 9) return "من الجزء 8 إلى 11";
    if (surahId >= 10 && surahId <= 14) return "من الجزء 11 إلى 13";
    if (surahId >= 15 && surahId <= 17) return "من الجزء 14 إلى 15";
    if (surahId >= 18 && surahId <= 20) return "من الجزء 15 إلى 16";
    if (surahId >= 21 && surahId <= 25) return "من الجزء 17 إلى 19";
    if (surahId >= 26 && surahId <= 30) return "من الجزء 19 إلى 21";
    if (surahId >= 31 && surahId <= 36) return "من الجزء 21 إلى 23";
    if (surahId >= 37 && surahId <= 45) return "من الجزء 23 إلى 25";
    if (surahId >= 46 && surahId <= 57) return "من الجزء 26 إلى 27";
    if (surahId >= 58 && surahId <= 66) return "الجزء الثامن والعشرون";
    if (surahId >= 67 && surahId <= 77) return "الجزء التاسع والعشرون";
    return "الجزء الثلاثون";
  }

  Future<Map<String, dynamic>> loadSurahData() async {
    final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
    final data = json.decode(response);
    Map<String, dynamic> versesMap = data['verse'];
    List<String> allVerses = versesMap.values.map((value) => value.toString()).toList();
    
    String? basmalah;
    List<String> dynamicVerses = [];

    if (widget.surahId == 1 || widget.surahId == 9) {
      dynamicVerses = allVerses;
    } else {
      if (allVerses.isNotEmpty && (allVerses[0].contains("بِسْمِ") || allVerses[0].startsWith("بِسمِ"))) {
        basmalah = allVerses[0];
        dynamicVerses = allVerses.sublist(1);
      } else {
        dynamicVerses = allVerses;
      }
    }

    _currentVerses = dynamicVerses;
    return {
      'basmalah': basmalah,
      'verses': dynamicVerses,
    };
  }

  void _goToVerse(int verseNumber) {
    if (verseNumber < 1 || verseNumber > _currentVerses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم الآية غير صحيح! السورة تحتوي على ${_currentVerses.length} آية.')),
      );
      return;
    }

    int totalCharacters = _currentVerses.fold(0, (sum, verse) => sum + verse.length);
    int targetCharacters = 0;
    for (int i = 0; i < verseNumber - 1; i++) {
      targetCharacters += _currentVerses[i].length;
    }

    double ratio = targetCharacters / totalCharacters;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;
