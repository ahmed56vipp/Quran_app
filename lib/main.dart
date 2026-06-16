import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    // فرض اتجاه اليمين لليسار على كامل التطبيق
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        home: const SurahListScreen(),
      ),
    );
  }
}

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  Future<List<dynamic>> loadQuranIndex() async {
    final String response = await rootBundle.loadString('assets/data/quran_data.json');
    return json.decode(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فهرس القرآن الكريم')),
      body: FutureBuilder<List<dynamic>>(
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
                title: Text(surah['name']),
                subtitle: Text(isMeccan ? "مكية" : "مدنية"),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => 
                    SurahDetailScreen(surahId: surah['id'], surahName: surah['name'])));
                },
              );
            },
          );
        },
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
  double _fontSize = 22.0;

  Future<List<String>> loadSurah() async {
    final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
    final data = json.decode(response);
    Map<String, dynamic> versesMap = data['verse'];
    List<String> allVerses = versesMap.values.map((value) => value.toString()).toList();
    
    // منطق البسملة: تُحذف فقط في سورة التوبة (ID 9)
    if (widget.surahId == 9 && allVerses.isNotEmpty) {
      return allVerses.sublist(1);
    }
    return allVerses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _fontSize += 2)),
          IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => _fontSize -= 2)),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: loadSurah(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final verses = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: verses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "${verses[index]} \u06DD ${index + 1}",
                  style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed'),
                  textAlign: TextAlign.justify,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
