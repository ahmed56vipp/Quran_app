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
      // 🌍 إجبار التطبيق على الاتجاه العربي الصحيح من اليمين إلى اليمين
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

  // دالة متطورة لقراءة ملف الـ JSON وحساب الآيات بدقة
  Future<List<dynamic>> loadQuranData() async {
    try {
      final String response = await rootBundle.loadString('assets/quran_data.json');
      final data = json.decode(response);
      return data is List ? data : data['surahs'] ?? [];
    } catch (e) {
      final String response = await rootBundle.loadString('assets/quran_full.json');
      final data = json.decode(response);
      return data is List ? data : data['surahs'] ?? [];
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
              child: Text('تأكد من ملفات الـ JSON في الـ assets', style: TextStyle(fontFamily: 'ahmed', fontSize: 18)),
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
                final int id = surah['id'] ?? surah['number'] ?? (index + 1);
                final String type = surah['type'] ?? surah['revelation_type'] ?? 'مكية';
                
                // 🛠️ حساب عدد الآيات بشكل ديناميكي مرن لتجنب ظهور الرقم 0
                int versesCount = 0;
                if (surah['verses'] is List) {
                  versesCount = (surah['verses'] as List).length;
                } else if (surah['verses_count'] != null) {
                  versesCount = surah['verses_count'];
                } else if (surah['total_verses'] != null) {
                  versesCount = surah['total_verses'];
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
                      '$type  |  آياتها: $versesCount',
                      style: const TextStyle(fontFamily: 'ahmed', fontSize: 14, color: Colors.black54),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
                    onTap: () {
                      // 🚀 فتح السورة والانتقال لشاشة القراءة عند الضغط عليها
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SurahDetailScreen(surahData: surah, surahName: name),
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

// 📖 شاشة عرض وقراءة آيات السورة الجديدة
class SurahDetailScreen extends StatelessWidget {
  final dynamic surahData;
  final String surahName;

  const SurahDetailScreen({super.key, required this.surahData, required this.surahName});

  @override
  Widget build(BuildContext context) {
    // جلب قائمة الآيات من السورة المفتوحة
    final List<dynamic> verses = surahData['verses'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          surahName,
          style: const TextStyle(fontFamily: 'ahmed', fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: verses.isEmpty
          ? const Center(child: Text('لا توجد آيات متوفرة لهذه السورة', style: TextStyle(fontFamily: 'ahmed')))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                final verse = verses[index];
                // استخراج نص الآية سواء كانت عبارة عن نص مباشر أو خريطة داخلياً
                String verseText = '';
                if (verse is String) {
                  verseText = verse;
                } else if (verse is Map) {
                  verseText = verse['text'] ?? verse['ar'] ?? verse['verse'] ?? '';
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
                          color: Colors.blackDE,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // رقم الآية في نهاية السطر
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
            ),
    );
  }
}
