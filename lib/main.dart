import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        fontFamily: 'ahmed', 
      ),
      home: const SurahListScreen(),
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
  List<dynamic> surahs = [];

  @override
  void initState() {
    super.initState();
    _loadIndexData();
    _loadLastReadPosition();
  }

  Future<void> _loadIndexData() async {
    final String response = await rootBundle.loadString('assets/data/quran_data.json');
    setState(() {
      surahs = json.decode(response);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
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
                label: Text('العودة إلى آخر موضع قراءة: $_lastSurahName', style: const TextStyle(fontFamily: 'ahmed')),
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
            child: surahs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      
                      final int sId = int.tryParse(surah['id'].toString()) ?? (index + 1);
                      final String sName = surah['name'] ?? 'بدون اسم';
                      final String sType = surah['type'] ?? 'مكية';
                      final int vCount = int.tryParse(surah['verses_count'].toString()) ?? 0;
                      
                      final bool isMeccan = sType.contains('مكية');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              sName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'ahmed'),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              "$sType | آياتها: $vCount",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'ahmed'),
                              textAlign: TextAlign.right,
                            ),
                            leading: SizedBox(
                              width: 36,
                              height: 36,
                              child: Image.asset(
                                isMeccan ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    backgroundColor: Colors.green[50],
                                    child: Text(
                                      toArabicNumerals(sId),
                                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SurahDetailScreen(
                                    surahId: sId,
                                    surahName: sName,
                                    versesCount: vCount,
                                    surahType: sType,
                                  ),
                                ),
                              );
                              _loadLastReadPosition();
                            },
                          ),
                        ),
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

  Future<Map<String, dynamic>> loadSurahData() async {
    final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
    final data = json.decode(response);
    
    Map<String, dynamic> versesMap = Map<String, dynamic>.from(data['verse']);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentVerses = dynamicVerses;
        });
      }
    });

    return {
      'basmalah': basmalah,
      'verses': dynamicVerses,
    };
  }

  void _goToVerse(int verseNumber) {
    if (_currentVerses.isEmpty) return;

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

    double ratio = totalCharacters > 0 ? (targetCharacters / totalCharacters) : 0.0;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
  }

  void _showGoToVerseDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الذهاب إلى آية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
        content: TextField(
          controller: inputController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'أدخل رقم الآية (1 - ${_currentVerses.length})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'ahmed')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () {
              final int? verseNum = int.tryParse(inputController.text);
              Navigator.pop(context);
              if (verseNum != null) {
                _goToVerse(verseNum);
              }
            },
            child: const Text('ذهاب', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'ahmed')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ الـ AppBar المحدث والمكبر لضمان وضوح الكلمات والأرقام ومنع صغر الخط
      appBar: AppBar(
        centerTitle: false, 
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        toolbarHeight: 85, // زيادة الارتفاع ليعطي مساحة كافية للخطوط الكبيرة دون انضغاط
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // السطر الأول: اسم السورة كبير وعريض + نوع السورة واضح
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "سورة ${widget.surahName}", 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  "(${widget.surahType})", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, fontFamily: 'ahmed', color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // السطر الثاني: عدد الآيات والجزء بخط مكبر وواضح بلون أبيض ناصع لقراءته بسهولة
            Text(
              "آياتها: ${toArabicNumerals(widget.versesCount)}  |  الجزء الأول",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal, fontFamily: 'ahmed', color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.find_in_page, size: 26),
            tooltip: 'الذهاب إلى آية',
            onPressed: _currentVerses.isEmpty ? null : _showGoToVerseDialog,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.text_fields, size: 26),
              tooltip: 'إعدادات الخط',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields, color: Colors.green[800], size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'إعدادات الخط',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed'),
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1.2),
                Text(
                  'حجم خط القراءة الحالي: ${_fontSize.toInt()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'ahmed'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize += 2),
                      child: const Text('A+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize = (_fontSize > 16) ? _fontSize - 2 : _fontSize),
                      child: const Text('A-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _surahDataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final basmalahText = snapshot.data!['basmalah'] as String?;
          final versesList = snapshot.data!['verses'] as List<String>;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (basmalahText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EDE2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    ),
                    child: Text(
                      basmalahText,
                      style: TextStyle(
                        fontSize: _fontSize + 2, 
                        fontFamily: 'ahmed', 
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B4226),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Text.rich(
                  TextSpan(
                    children: List.generate(versesList.length, (index) {
                      int actualVerseNum = (basmalahText != null) ? (index + 2) : (index + 1);
                      if (widget.surahId == 1) {
                        actualVerseNum = index + 1;
                      }
                      
                      return TextSpan(
                        children: [
                          TextSpan(
                            text: "${versesList[index]} ",
                            style: TextStyle(
                              fontSize: _fontSize, 
                              fontFamily: 'ahmed', 
                              height: 2.2, 
                              color: Colors.black87,
                            ),
                          ),
                          TextSpan(
                            text: " ﴿${toArabicNumerals(actualVerseNum)}﴾ ",
                            style: TextStyle(
                              fontSize: _fontSize - 2, 
                              fontFamily: 'ahmed', 
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
