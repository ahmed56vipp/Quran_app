import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SurahListScreen(),
  ));
}

// دالة عامة لتحويل الأرقام إلى المظهر الشرقي (١، ٢، ٣...)
String toArabicNumbers(int number) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String input = number.toString();
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], arabic[i]);
  }
  return input;
}

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});
  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List allSurahs = [];
  List filteredSurahs = [];
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    final String response = await rootBundle.loadString('assets/quran_data.json');
    setState(() {
      allSurahs = json.decode(response);
      filteredSurahs = allSurahs;
    });
  }

  void _filterSurahs(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredSurahs = allSurahs;
      } else {
        filteredSurahs = allSurahs.where((surah) {
          final name = surah['name'].toString();
          final num = surah['number'].toString();
          return name.contains(query) || num.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Directionality تقوم بنقل كل شيء لليمين تلقائياً لتناسب اللغة العربية
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF333300),
          title: isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: "ابحث عن سورة أو رقمها...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: _filterSurahs,
                )
              : const Text("القرآن الكريم", style: TextStyle(fontFamily: 'ahmed')),
          actions: [
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  if (isSearching) {
                    isSearching = false;
                    _searchController.clear();
                    filteredSurahs = allSurahs;
                  } else {
                    isSearching = true;
                  }
                });
              },
            ),
          ],
        ),
        body: filteredSurahs.isEmpty 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: filteredSurahs.length,
                itemBuilder: (context, index) {
                  var surah = filteredSurahs[index];
                  String type = surah['type']; 

                  return ListTile(
                    // الأيقونة ستصبح على اليمين تلقائياً
                    leading: Image.asset(
                      type == 'مكية' ? 'assets/mk.png' : 'assets/md.png', 
                      width: 40, height: 40,
                      errorBuilder: (c, o, s) => const Icon(Icons.book, color: Colors.white),
                    ),
                    title: Text(
                      surah['name'], 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'ahmed')
                    ),
                    // رقم السورة سيظهر على اليسار بشكل أنيق جداً
                    trailing: Text(
                      "سورة رقم ${toArabicNumbers(surah['number'])}",
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => 
                        SurahDetailsScreen(surahNumber: surah['number'], surahName: surah['name'])));
                    },
                  );
                },
              ),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: Text(surahName, style: const TextStyle(fontFamily: 'ahmed')), 
          backgroundColor: const Color(0xFF333300),
          actions: [
            // أيقونة مبدئية لحفظ العلامة المرجعية سنقوم ببرمجتها لاحقاً
            IconButton(
              icon: const Icon(Icons.bookmark_border, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم حفظ علامة مرجعية مؤقتة عند هذه السورة"))
                );
              },
            )
          ],
        ),
        body: FutureBuilder<Map>(
          future: loadSurahData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return Center(child: Text("خطأ في تحميل سورة $surahNumber", style: const TextStyle(color: Colors.white)));
            
            Map verseData = snapshot.data!['verse'] ?? {};
            int count = snapshot.data!['count'] ?? verseData.length;
            List<String> verses = [];
            
            for(int i = 1; i <= count; i++) {
               if(verseData.containsKey('verse_$i')) {
                  String verseText = verseData['verse_$i'] ?? "";
                  String arabicNumbered = toArabicNumbers(i);
                  verses.add("$verseText $arabicNumbered"); 
               }
            }

            String fullText = verses.join(" ");

            if (surahNumber != 1 && surahNumber != 9) {
              fullText = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n" + fullText;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                fullText, 
                textAlign: TextAlign.justify, 
                style: const TextStyle(fontSize: 26, color: Colors.white, height: 2.2, fontFamily: 'ahmed'),
              ),
            );
          },
        ),
      ),
    );
  }
}
