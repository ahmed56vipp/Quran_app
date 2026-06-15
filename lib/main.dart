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
      title: 'القرآن الكريم',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        primaryColor: const Color(0xFF1B5E20),
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
      ),
      home: const SurahListScreen(),
    );
  }
}

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  Future<List<dynamic>> loadQuranData() async {
    try {
      final String response = await rootBundle.loadString('assets/quran_data.json');
      final data = json.decode(response);
      return data is List ? data : data['surahs'] ?? [];
    } catch (e) {
      try {
        final String response = await rootBundle.loadString('assets/quran_full.json');
        final data = json.decode(response);
        return data is List ? data : data['surahs'] ?? [];
      } catch (e) {
        return [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مصحف القرآن الكريم',
          style: TextStyle(fontFamily: 'ahmed', fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: loadQuranData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('تأكد من ملف الـ JSON الرئيسي في الـ assets', style: TextStyle(fontFamily: 'ahmed', fontSize: 18)),
            );
          } else {
            final surahs = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: surahs.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final surah = surahs[index];
                
                final String name = surah['name'] ?? surah['surah_name'] ?? 'سورة';
                final String type = surah['type'] ?? surah['revelation_type'] ?? 'مكية';
                
                // تحويل الـ ID إلى رقم بشكل آمن وتجنب المشاكل البرمجية
                int id = index + 1;
                if (surah['id'] != null) id = int.tryParse(surah['id'].toString()) ?? id;
                else if (surah['number'] != null) id = int.tryParse(surah['number'].toString()) ?? id;

                // محاولة جلب عدد الآيات من المفاتيح الشائعة في ملفات الفهرس
                int versesCount = 0;
                if (surah['numberOfAyahs'] != null) {
                  versesCount = int.tryParse(surah['numberOfAyahs'].toString()) ?? 0;
                } else if (surah['verses_count'] != null) {
                  versesCount = int.tryParse(surah['verses_count'].toString()) ?? 0;
                } else if (surah['total_verses'] != null) {
                  versesCount = int.tryParse(surah['total_verses'].toString()) ?? 0;
                } else if (surah['count'] != null) {
                  versesCount = int.tryParse(surah['count'].toString()) ?? 0;
                } else if (surah['verses'] is List) {
                  versesCount = (surah['verses'] as List).length;
                }

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$id',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 16),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontFamily: 'ahmed', fontSize: 22, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    subtitle: Text(
                      '$type  |  آياتها: ${versesCount > 0 ? versesCount : "..."}',
                      style: const TextStyle(fontFamily: 'ahmed', fontSize: 14, color: Colors.black54),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
                    onTap: () {
                      // نمرر الـ id لنفتح ملف السورة المنفصل داخل الشاشة القادمة
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SurahDetailScreen(surahId: id, surahName: name),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// 📖 شاشة قراءة الآيات الذكية (تقرأ من ملف السورة المستقل)
class SurahDetailScreen extends StatelessWidget {
  final int surahId;
  final String surahName;

  const SurahDetailScreen({super.key, required this.surahId, required this.surahName});

  // دالة مخصصة لقراءة ملف السورة المنفصل بناءً على رقمها
  Future<List<dynamic>> loadSurahVerses() async {
    try {
      final String response = await rootBundle.loadString('assets/surah_$surahId.json');
      final data = json.decode(response);
      
      if (data is List) return data;
      if (data is Map) {
        if (data['verses'] is List) return data['verses'];
        if (data['ayahs'] is List) return data['ayahs'];
        if (data['text'] is List) return data['text'];
        if (data['data'] is List) return data['data'];
        if (data['surah'] != null && data['surah']['verses'] is List) return data['surah']['verses'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          surahName,
          style: const TextStyle(fontFamily: 'ahmed', fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: loadSurahVerses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'لم نتمكن من العثور على ملف الآيات لـ surah_$surahId.json',
                style: const TextStyle(fontFamily: 'ahmed', fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          } else {
            final verses = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                final verse = verses[index];
                String verseText = '';
                
                if (verse is String) {
                  verseText = verse;
                } else if (verse is Map) {
                  verseText = verse['text'] ?? verse['ar'] ?? verse['verse'] ?? verse['text_ar'] ?? '';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        verseText,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontFamily: 'ahmed',
                          fontSize: 24,
                          height: 1.8,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '﴿${index + 1}﴾',
                            style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const Divider(color: Colors.black12, height: 20),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
