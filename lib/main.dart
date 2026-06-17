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
          scaffoldBackgroundColor: const Color(0xFFFDFBF7), // لون خلفية مريح للعين
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
    // استدعاء ملف الـ JSON الخاص بك
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
                        juzData: const [], // فارغة احتياطياً وتُحسب داخلياً
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
                // 1. إذا فشل التطبيق في قراءة ملف الـ JSON سيعرض السبب هنا
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'خطأ في تحميل ملف البيانات:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }

                // 2. أثناء جلب البيانات
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final surahs = snapshot.data!;
                
                // 3. إذا كان الملف فارغاً تماماً
                if (surahs.isEmpty) {
                  return const Center(child: Text('قائمة السور فارغة!'));
                }

                return ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    try {
                      final surah = surahs[index];
                      bool isMeccan = surah['type'] == 'Makkiyah';
                      int vCount = surah['count'] ?? 0;
                      int sId = int.parse(surah['index'].toString());
                      String sName = surah['title'] ?? 'بدون اسم'; 
                      List<dynamic> juzList = surah['juz'] ?? [];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SurahDetailScreen(
                                  surahId: sId,
                                  surahName: sName,
                                  versesCount: vCount,
                                  surahType: isMeccan ? 'مكية' : 'مدنية',
                                  juzData: juzList,
                                ),
                              ),
                            );
                            _loadLastReadPosition();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius
