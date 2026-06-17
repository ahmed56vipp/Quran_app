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

  @override
  void initState() {
    super.initState();
    _loadLastReadPosition();
  }

  // تحميل آخر موضع قراءة تم حفظه
  Future<void> _loadLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSurahId = prefs.getInt('last_surah_id');
      _lastSurahName = prefs.getString('last_surah_name');
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
          // عرض زر العودة لآخر موضع قراءة إذا كان متوفراً
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
                      ),
                    ),
                  );
                  _loadLastReadPosition(); // تحديث الموضع عند الرجوع
                },
              ),
            ),
          
          // قائمة السور
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
                    
                    return ListTile(
                      leading: SizedBox(
                        width: 35,
                        height: 35,
                        child: Image.asset(
                          isMeccan ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      title: Text(surah['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      subtitle: Text(isMeccan ? "مكية | آياتها: ${surah['verses_count'] ?? ''}" : "مدنية | آياتها: ${surah['verses_count'] ?? ''}"),
                      trailing: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SurahDetailScreen(
                              surahId: surah['id'],
                              surahName: surah['name'],
                            ),
                          ),
                        );
                        _loadLastReadPosition(); // تحديث الموضع بعد العودة للفهرس
                      },
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

  const SurahDetailScreen({super.key, required this.surahId, required this.surahName});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  double _fontSize = 24.0;
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _surahDataFuture;
  List<String> _currentVerses = []; // لحفظ الآيات الحالية واستخدامها في دالة التنقل

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

  // حفظ موضع القراءة الحالي تلقائياً فور الدخول للسورة
  Future<void> _saveLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
  }

  // دالة معالجة السورة وفصل البسملة عن الآيات المرقّرة
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

    _currentVerses = dynamicVerses; // تخزين محلي للآيات لعمل دالة السكرول
    return {
      'basmalah': basmalah,
      'verses': dynamicVerses,
    };
  }

  // دالة حساب موضع الانتقال السلس للآية المطلوبة بدقة
  void _goToVerse(int verseNumber) {
    if (verseNumber < 1 || verseNumber > _currentVerses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم الآية غير صحيح! السورة تحتوي على ${_currentVerses.length} آية.')),
      );
      return;
    }

    // حساب إجمالي عدد الحروف في السورة كاملة
    int totalCharacters = _currentVerses.fold(0, (sum, verse) => sum + verse.length);
    
    // حساب عدد الحروف حتى الوصول للآية المستهدفة
    int targetCharacters = 0;
    for (int i = 0; i < verseNumber - 1; i++) {
      targetCharacters += _currentVerses[i].length;
    }

    // حساب النسبة والتنقل الذكي
    double ratio = targetCharacters / totalCharacters;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
  }

  // نافذة إدخال رقم الآية
  void _showGoToVerseDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الذهاب إلى آية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 16)),
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
            child: const Text('ذهاب', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          // زر ميزة الانتقال للآية الجديد
          IconButton(
            icon: const Icon(Icons.find_in_page, size: 26),
            tooltip: 'الذهاب إلى آية',
            onPressed: _currentVerses.isEmpty ? null : _showGoToVerseDialog,
          ),
          // أزرار التحكم في حجم الخط بترميز A+ و A-
          TextButton(
            onPressed: () => setState(() => _fontSize += 2),
            child: const Text('A+', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => setState(() => _fontSize -= 2),
            child: const Text('A-', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _surahDataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final basmalahText = snapshot.data!['basmalah'] as String?;
          final versesList = snapshot.data!['verses'] as List<String>;

          return SingleChildScrollView(
            controller: _scrollController, // ربط السكرول هنا ليعمل الانتقال بدقة
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. عرض البسملة في المنتصف مستقلة تماماً وبدون أي رموز أو أرقام
                if (basmalahText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      basmalahText,
                      style: TextStyle(
                        fontSize: _fontSize + 4, 
                        fontFamily: 'ahmed', 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 2. عرض نص السورة بشكل مستمر ومترابط تماماً مثل المصحف الورقي
                Text.rich(
                  TextSpan(
                    children: List.generate(versesList.length, (index) {
                      int actualVerseNum = index + 1; 
                      
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
                          // إدراج رمز خاتمة الآية مع الرقم العربي داخله بشكل موحد
                          TextSpan(
                            text: "\u06DD${toArabicNumerals(actualVerseNum)} ",
                            style: TextStyle(
                              fontSize: _fontSize - 2, 
                              fontFamily: 'ahmed', 
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  textAlign: TextAlign.justify, // محاذاة النص من الطرفين ليماثل السطر الورقي
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
