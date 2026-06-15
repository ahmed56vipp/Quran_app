import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SurahListScreen(),
  ));
}

// دالة تحويل الأرقام إلى المظهر الشرقي (١، ٢، ٣...)
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
                    leading: Image.asset(
                      type == 'مكية' ? 'assets/mk.png' : 'assets/md.png', 
                      width: 40, height: 40,
                      errorBuilder: (c, o, s) => const Icon(Icons.book, color: Colors.white),
                    ),
                    title: Text(
                      surah['name'], 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'ahmed')
                    ),
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

class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  const SurahDetailsScreen({super.key, required this.surahNumber, required this.surahName});

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  int totalVersesCount = 0;
  bool hasBasmalah = false;

  @override
  void initState() {
    super.initState();
    hasBasmalah = (widget.surahNumber != 1 && widget.surahNumber != 9);
  }

  Future<Map> loadSurahData() async {
    String response = await rootBundle.loadString('assets/surah_${widget.surahNumber}.json');
    Map data = json.decode(response);
    Map verseData = data['verse'] ?? {};
    totalVersesCount = data['count'] ?? verseData.length;
    return data;
  }

  void _showGoToVerseDialog(BuildContext context) {
    final TextEditingController _verseInputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF262626),
          title: const Text("الذهاب إلى آية", style: TextStyle(color: Colors.white, fontFamily: 'ahmed')),
          content: TextField(
            controller: _verseInputController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "أدخل الرقم من 1 إلى $totalVersesCount",
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333300))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                int? verseNum = int.tryParse(_verseInputController.text);
                if (verseNum != null && verseNum > 0 && verseNum <= totalVersesCount) {
                  Navigator.pop(context);
                  int targetIndex = hasBasmalah ? verseNum : verseNum - 1;
                  
                  // حساب موقع النزول التقديري بناءً على وضع الأسطر الجديد
                  _scrollController.animateTo(
                    targetIndex * 120.0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: const Text("اذهب", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: Text(widget.surahName, style: const TextStyle(fontFamily: 'ahmed')), 
          backgroundColor: const Color(0xFF333300),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF333300),
          child: const Icon(Icons.pin_drop, color: Colors.white),
          onPressed: () => _showGoToVerseDialog(context),
        ),
        body: FutureBuilder<Map>(
          future: loadSurahData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Text("خطأ في تحميل سورة ${widget.surahNumber}", style: const TextStyle(color: Colors.white)));
            }
            
            Map verseData = snapshot.data!['verse'] ?? {};
            List<String> verses = [];
            
            for (int i = 1; i <= totalVersesCount; i++) {
               if (verseData.containsKey('verse_$i')) {
                  String verseText = verseData['verse_$i'] ?? "";
                  String arabicNumbered = toArabicNumbers(i);
                  verses.add("$verseText $arabicNumbered"); 
               }
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: verses.length + (hasBasmalah ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasBasmalah && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 25.0),
                    child: Text(
                      "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, color: Colors.white, fontFamily: 'ahmed'),
                    ),
                  );
                }

                int verseIndex = hasBasmalah ? index - 1 : index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verses[verseIndex],
                        textAlign: TextAlign.justify,
                        style: const TextStyle(fontSize: 24, color: Colors.white, height: 1.9, fontFamily: 'ahmed'),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12, thickness: 1),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
