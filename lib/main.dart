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
  late Future<Map> _surahDataFuture;
  List<GlobalKey> _verseKeys = [];
  int totalVersesCount = 0;
  bool hasBasmalah = false;

  @override
  void initState() {
    super.initState();
    hasBasmalah = (widget.surahNumber != 1 && widget.surahNumber != 9);
    _surahDataFuture = loadSurahData();
  }

  Future<Map> loadSurahData() async {
    String response = await rootBundle.loadString('assets/surah_${widget.surahNumber}.json');
    Map data = json.decode(response);
    Map verseData = data['verse'] ?? {};
    totalVersesCount = data['count'] ?? verseData.length;
    
    // توليد مفاتيح تتبع ذكية لكل آية لربطها بقرص التنقل
    _verseKeys = List.generate(totalVersesCount + 1, (index) => GlobalKey());
    
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
                  
                  // جلب مكان المفتاح الخاص بالآية وسط النص المتصل بدقة
                  final targetContext = _verseKeys[verseNum].currentContext;
                  if (targetContext != null) {
                    Scrollable.ensureVisible(
                      targetContext,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
                    );
                  }
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
      child: FutureBuilder<Map>(
        future: _surahDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(0xFF1A1A1A),
              appBar: AppBar(title: Text(widget.surahName, style: const TextStyle(fontFamily: 'ahmed')), backgroundColor: const Color(0xFF333300)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              backgroundColor: const Color(0xFF1A1A1A),
              appBar: AppBar(title: Text(widget.surahName, style: const TextStyle(fontFamily: 'ahmed')), backgroundColor: const Color(0xFF333300)),
              body: Center(child: Text("خطأ في تحميل سورة ${widget.surahNumber}", style: const TextStyle(color: Colors.white))),
            );
          }
          
          Map verseData = snapshot.data!['verse'] ?? {};
          List<InlineSpan> textSpans = [];
          
          // إضافة البسملة في البداية بشكل مستقل ومتناسق
          if (hasBasmalah) {
            textSpans.add(const TextSpan(
              text: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n",
              style: TextStyle(fontSize: 28, color: Colors.white, fontFamily: 'ahmed'),
            ));
          }

          // بناء النص الكامل المسترسل مع دمج نقاط التتبع الخفية لزر الانتقال
          for (int i = 1; i <= totalVersesCount; i++) {
             if (verseData.containsKey('verse_$i')) {
                String verseText = verseData['verse_$i'] ?? "";
                String arabicNumbered = toArabicNumbers(i);
                
                // زرع نقطة مرجعية خفية تماماً بحجم 0 قبل بداية كل آية للتنقل التلقائي
                textSpans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(key: _verseKeys[i], width: 0, height: 0),
                ));

                // إضافة نص الآية ملتصقاً بما قبله وما بعده دون أسطر جديدة
                textSpans.add(TextSpan(
                  text: "$verseText $arabicNumbered  ",
                ));
             }
          }

          return Scaffold(
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
            body: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Text.rich(
                TextSpan(children: textSpans),
                textAlign: TextAlign.justify, // توزيع النص بشكل متساوٍ وعادل على أطراف الشاشة
                style: const TextStyle(fontSize: 26, color: Colors.white, height: 2.3, fontFamily: 'ahmed'),
              ),
            ),
          );
        },
      ),
    );
  }
}
