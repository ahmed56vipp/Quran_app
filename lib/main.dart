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
        fontFamily: 'ahmed', // استخدام الخط المخصص
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
    // المسار المحدث للفهرس داخل مجلد data
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
              return ListTile(
                leading: CircleAvatar(child: Text("${surah['id']}")),
                title: Text(surah['name']),
                subtitle: Text("${surah['type']} | آياتها: ${surah['verses_count']}"),
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

  Future<List<dynamic>> loadSurah() async {
    // المسار المحدث للسور داخل مجلد surah
    final String response = await rootBundle.loadString('assets/surah/surah_$surahId.json');
    final data = json.decode(response);
    return data['verses'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surahName)),
      body: FutureBuilder<List<dynamic>>(
        future: loadSurah(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final verses = snapshot.data!;
          return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(verses[index]['text'], textAlign: TextAlign.justify),
            ),
          );
        },
      ),
    );
  }
}
