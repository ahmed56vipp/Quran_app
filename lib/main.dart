import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SurahListScreen(),
  ));
}

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});
  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List surahs = [];

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    final String response = await rootBundle.loadString('assets/quran_data.json');
    setState(() {
      surahs = json.decode(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: const Text("القرآن الكريم"), backgroundColor: const Color(0xFF333300)),
      body: surahs.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                var surah = surahs[index];
                // مطابقة كلمة "مكية" أو "مدنية" كما في ملفك
                String type = surah['type']; 

                return ListTile(
                  leading: Image.asset(
                    type == 'مكية' ? 'assets/mk.png' : 'assets/md.png', 
                    width: 40, height: 40,
                    errorBuilder: (c, o, s) => const Icon(Icons.book, color: Colors.white),
                  ),
                  title: Text(surah['name'], style: const TextStyle(color: Colors.white, fontSize: 20)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => 
                      SurahDetailsScreen(surahNumber: surah['number'], surahName: surah['name'])));
                  },
                );
              },
            ),
    );
  }
}

class SurahDetailsScreen extends StatelessWidget {
  final int surahNumber;
  final String surahName;
  const SurahDetailsScreen({super.key, required this.surahNumber, required this.surahName});

  Future<Map> loadSurahData() async {
    // تحميل الملف حسب رقم السورة (مثال: surah_1.json)
    String response = await rootBundle.loadString('assets/surah_$surahNumber.json');
    return json.decode(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: Text(surahName), backgroundColor: const Color(0xFF333300)),
      body: FutureBuilder<Map>(
        future: loadSurahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData) return Center(child: Text("خطأ في تحميل سورة $surahNumber", style: const TextStyle(color: Colors.white)));
          
          // استخراج النصوص من الـ Map الموجودة في 'verse'
          Map verseData = snapshot.data!['verse'];
          List<String> verses = [];
          
          // الترتيب بناءً على المفاتيح الموجودة في ملفك (verse_1, verse_2...)
          for(int i=1; i <= verseData.length; i++) {
             verses.add(verseData['verse_$i'] ?? "");
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              verses.join(" "), 
              textAlign: TextAlign.justify, 
              style: const TextStyle(fontSize: 26, color: Colors.white, height: 2.2, fontFamily: 'ahmed'),
            ),
          );
        },
      ),
    );
  }
}
