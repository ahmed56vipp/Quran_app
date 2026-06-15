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
      theme: ThemeData(
        primaryColor: const Color(0HeaderFF0D47A1), // لون إسلامي هادئ
        scaffoldBackgroundColor: const Color(0xFFF9F9F9), // خلفية مريحة للعين
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20), // لون أخضر داكن فخم للمصاحف
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const SurahListScreen(),
    );
  }
}

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  // دالة ذكية لقراءة ملف الـ JSON المحلي من الـ assets
  Future<List<dynamic>> loadQuranData() async {
    try {
      final String response = await rootBundle.loadString('assets/quran_data.json');
      final data = json.decode(response);
      
      // هنا نقوم بفحص ما إذا كان الـ JSON عبارة عن قائمة مباشرة أو يحتوي على مفتاح داخلي
      if (data is List) {
        return data;
      } else if (data is Map && data.containsKey('surahs')) {
        return data['surahs'];
      } else {
        return data.values.toList(); // حل احتياطي مرن
      }
    } catch (e) {
      // إذا لم يجد quran_data.json سيتوجه تلقائياً للملف الآخر quran_full.json كخطة بديلة
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
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: loadQuranData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            );
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'تأكد من وجود ملفات الـ JSON داخل الـ assets',
                style: TextStyle(fontFamily: 'ahmed', fontSize: 18),
              ),
            );
          } {
            final surahs = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: surahs.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final surah = surahs[index];
                
                // جلب البيانات مع وضع قيم افتراضية في حال اختلف مسمى المفاتيح بالـ JSON
                final String name = surah['name'] ?? surah['surah_name'] ?? 'سورة';
                final int id = surah['id'] ?? surah['number'] ?? (index + 1);
                final int versesCount = surah['verses_count'] ?? surah['total_verses'] ?? 0;
                final String type = surah['type'] ?? surah['revelation_type'] ?? '';

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
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'ahmed',
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'آياتها: $versesCount  |  $type',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black32),
                    onTap: () {
                      // سنضع هنا دالة الانتقال لصفحة قراءة الآيات في الخطوة القادمة
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
