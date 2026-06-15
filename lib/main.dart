import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

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

  String? bookmarkName;
  int? bookmarkNumber;

  @override
  void initState() {
    super.initState();
    loadAllData();
    loadBookmark();
  }

  Future<void> loadAllData() async {
    final String response = await rootBundle.loadString('assets/quran_data.json');
    setState(() {
      allSurahs = json.decode(response);
      filteredSurahs = allSurahs;
    });
  }

  Future<void> loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookmarkName = prefs.getString('bookmark_name');
      bookmarkNumber = prefs.getInt('bookmark_number');
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
            : Column(
                children: [
                  if (bookmarkNumber != null && !isSearching)
                    Card(
                      color: const Color(0xFF333300),
                      margin: const EdgeInsets.all(12),
                      elevation: 4,
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, color: Colors.yellow, size: 28),
                        title: const Text("مواصلة القراءة السابقة", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        subtitle: Text(bookmarkName ?? "", style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'ahmed')),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => 
                            SurahDetailsScreen(surahNumber: bookmarkNumber!, surahName: bookmarkName!)));
                          loadBookmark();
                        },
                      ),
                    ),
                  
                  Expanded(
                    child: ListView.builder(
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
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => 
                              SurahDetailsScreen(surahNumber: surah['number'], surahName: surah['name'])));
                            loadBookmark();
                          },
                        );
                      },
                    ),
                  ),
                ],
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

  double _fontSize = 26.0;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    hasBasmalah = (widget.surahNumber != 1 && widget.surahNumber != 9);
    _surahDataFuture = loadSurahData();
    _loadSettings();
  }

  Future<Map> loadSurahData() async {
    String response = await rootBundle.loadString('assets/surah_${widget.surahNumber}.json');
    Map data = json.decode(response);
    Map verseData = data['verse'] ?? {};
    totalVersesCount = data['count'] ?? verseData.length;
    
    _verseKeys = List.generate(totalVersesCount + 1, (index) => GlobalKey());
    return data;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedNum = prefs.getInt('bookmark_number');
    setState(() {
      _fontSize = prefs.getDouble('font_size') ?? 26.0;
      _isBookmarked = (savedNum == widget.surahNumber);
    });
  }

  Future<void> _changeFontSize(bool increase) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (increase && _fontSize < 42) _fontSize += 2;
      if (!increase && _fontSize > 18) _fontSize -= 2;
      prefs.setDouble('font_size', _fontSize);
    });
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isBookmarked) {
      await prefs.remove('bookmark_number');
      await prefs.remove('bookmark_name');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إزالة علامة القراءة', textDirection: TextDirection.rtl)));
    } else {
      await prefs.setInt('bookmark_number', widget.surahNumber);
      await prefs.setString('bookmark_name', widget.surahName);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ السورة كعلامة قراءة حالية', textDirection: TextDirection.rtl)));
    }
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
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
                  
                  final targetContext = _verseKeys[verseNum].currentContext;
                  if (targetContext != null) {
                    Scrollable.ensureVisible(
                      MosesGetContext(targetContext),
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

  BuildContext MosesGetContext(BuildContext context) => context;

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
          
          if (hasBasmalah) {
            textSpans.add(TextSpan(
              text: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n",
              style: TextStyle(fontSize: _fontSize + 4, color: Colors.white, height: 2.3, fontFamily: 'ahmed'),
            ));
          }

          for (int i = 1; i <= totalVersesCount; i++) {
             if (verseData.containsKey('verse_$i')) {
                String verseText = verseData['verse_$i'] ?? "";
                String arabicNumbered = toArabicNumbers(i);
                
                // نقطة التتبع الخفية للتنقل
                textSpans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(key: _verseKeys[i], width: 0, height: 0),
                ));

                // 1. نص الآية باللون الأبيض (ويحتوي تلقائياً على الرمز الأول من الـ JSON)
                textSpans.add(TextSpan(
                  text: "$verseText ",
                  style: TextStyle(fontSize: _fontSize, color: Colors.white, height: 2.3, fontFamily: 'ahmed'),
                ));

                // 2. عرض رقم الآية فقط باللون الذهبي الدافئ (بدون كتابة الرمز يدوياً لمنع التكرار)
                textSpans.add(TextSpan(
                  text: " $arabicNumbered  ",
                  style: TextStyle(fontSize: _fontSize, color: Colors.amber, fontWeight: FontWeight.bold, height: 2.3, fontFamily: 'ahmed'),
                ));
             }
          }

          return Scaffold(
            backgroundColor: const Color(0xFF1A1A1A),
            appBar: AppBar(
              title: Text(widget.surahName, style: const TextStyle(fontFamily: 'ahmed')), 
              backgroundColor: const Color(0xFF333300),
              actions: [
                IconButton(
                  icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.yellow),
                  onPressed: _toggleBookmark,
                  tooltip: "حفظ علامة القراءة",
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase, color: Colors.white),
                  onPressed: () => _changeFontSize(true),
                  tooltip: "تكبير الخط",
                ),
                IconButton(
                  icon: const Icon(Icons.text_decrease, color: Colors.white),
                  onPressed: () => _changeFontSize(false),
                  tooltip: "تصغير الخط",
                ),
              ],
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
                textAlign: TextAlign.justify,
              ),
            ),
          );
        },
      ),
    );
  }
}
