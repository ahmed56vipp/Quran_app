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
        backgroundColor: Colors.green[800], // تم إصلاح الخطأ هنا وحذف const
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

  @override
  void initState() {
    super.initState();
    _saveLastReadPosition();
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

    // سورة الفاتحة (1): البسملة آية مرقمة داخل النص
    if (widget.surahId == 1) {
      dynamicVerses = allVerses;
    } 
    // سورة التوبة (9): لا تحتوي على بسملة مطلقاً
    else if (widget.surahId == 9) {
      dynamicVerses = allVerses;
    } 
    // باقي السور: نأخذ أول سطر كبسملة مستقلة بدون ترميز، والباقي آيات مرقمة
    else {
      if (allVerses.isNotEmpty && (allVerses[0].contains("بِسْمِ") || allVerses[0].startsWith("بِسمِ"))) {
        basmalah = allVerses[0];
        dynamicVerses = allVerses.sublist(1);
      } else {
        dynamicVerses = allVerses;
      }
    }

    return {
      'basmalah': basmalah,
      'verses': dynamicVerses,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName, style: const TextStyle(fontWeight: FontWeight.bold)), // تم إصلاح الخطأ الإملائي هنا
        backgroundColor: Colors.green[800], // تم إصلاح الخطأ هنا وحذف const
        foregroundColor: Colors.white,
        actions: [
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
        future: loadSurahData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final basmalahText = snapshot.data!['basmalah'] as String?;
          final versesList = snapshot.data!['verses'] as List<String>;

          return SingleChildScrollView(
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
                      // ترتيب أرقام الآيات يبدأ من 1 دائماً بعد عزل البسملة
                      int actualVerseNum = index + 1; 
                      
                      return TextSpan(
                        children: [
                          TextSpan(
                            text: "${versesList[index]} ",
                            style: TextStyle(
                              fontSize: _fontSize, 
                              fontFamily: 'ahmed', 
                              height: 2.2, 
                              color: Colors.black87, // تم تصحيح الخطأ الإملائي للون هنا
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
