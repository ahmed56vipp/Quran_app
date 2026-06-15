import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مصحف القرآن الكريم',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        fontFamily: 'ahmed', // تأكد أن الخط موجود في المسار الصحيح
        primaryColor: const Color(0xFF1B5E20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const SurahListScreen(),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) return const Center(child: Text("لا توجد بيانات"));
          
          final surahs = snapshot.data!;
          return ListView.builder(
            itemCount: surahs.length,
            itemBuilder: (context, index) {
              final surah = surahs[index];
              final String type = surah['type'] ?? 'مكية';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'مكية' ? Colors.amber[100] : Colors.green[100],
                  child: Text("${surah['id']}"),
                ),
                title: Text(surah['name']),
                subtitle: Row(
                  children: [
                    Icon(
                      type == 'مكية' ? Icons.star_border : Icons.mosque,
                      size: 16,
                      color: type == 'مكية' ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text("$type | آياتها: ${surah['verses_count']}"),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surahId: surah['id'], 
                        surahName: surah['name']
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SurahDetailScreen extends StatelessWidget {
  final int surahId;
  final String surahName;

  const SurahDetailScreen({super.key, required this.surahId, required this.surahName});

  Future<List<String>> loadSurah() async {
    try {
      final String response = await rootBundle.loadString('assets/surah/surah_$surahId.json');
      final data = json.decode(response);
      
      // استخراج الكائن "verse" كما يظهر في ملفاتك
      Map<String, dynamic> versesMap = data['verse'];
      
      // تحويل القيم إلى قائمة نصوص
      return versesMap.values.map((value) => value.toString()).toList();
    } catch (e) {
      return ["حدث خطأ أثناء تحميل السورة"];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surahName)),
      body: FutureBuilder<List<String>>(
        future: loadSurah(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("لا توجد آيات"));
          }

          final verses = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: verses.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                "${verses[index]} (${index + 1})", 
                style: const TextStyle(fontSize: 20, fontFamily: 'ahmed'),
                textAlign: TextAlign.justify,
              ),
            ),
          );
        },
      ),
    );
  }
}
