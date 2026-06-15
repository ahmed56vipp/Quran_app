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
    String response = await rootBundle.loadString('assets/surah_$surahNumber.json');
    return json.decode(response);
  }

  // تحويل الأرقام إلى المظهر الشرقي (١، ٢، ٣) لأن الخط المرفق يتكفل بوضع الدائرة حولها تلقائياً
  String _toArabicNumbers(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String input = number.toString();
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
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
          
          if (snapshot.hasError) return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("خطأ: ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
          ));
          
          if (!snapshot.hasData) return const Center(child: Text("لا توجد بيانات", style: TextStyle(color: Colors.white)));
          
          Map verseData = snapshot.data!['verse'] ?? {};
          int count = snapshot.data!['count'] ?? verseData.length;
          List<String> verses = [];
          
          for(int i = 1; i <= count; i++) {
             if(verseData.containsKey('verse_$i')) {
                String verseText = verseData['verse_$i'] ?? "";
                String arabicNumbered = _toArabicNumbers(i);
                
                // هنا تم الاعتماد كلياً على الرقم العربي المدمج بالدائرة من الخط نفسه
                verses.add("$verseText $arabicNumbered"); 
             }
          }

          String fullText = verses.join(" ");

          // إضافة البسملة في سطر مستقل عدا الفاتحة والتوبة
          if (surahNumber != 1 && surahNumber != 9) {
            fullText = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n" + fullText;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              fullText, 
              textAlign: TextAlign.justify, 
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 26, color: Colors.white, height: 2.2, fontFamily: 'ahmed'),
            ),
          );
        },
      ),
    );
  }
}
