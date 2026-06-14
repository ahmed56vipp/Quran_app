import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// هذا الكلاس لجلب البيانات من الملف الذي رفعته
Future<List> loadQuranData() async {
  final String response = await rootBundle.loadString('assets/quran_full.json');
  final data = await json.decode(response);
  return data['surahs']; // تأكد أن المفتاح هو "surahs" حسب محتوى ملفك
}

// كود صفحة القراءة المحدث
class SurahDetailsScreen extends StatelessWidget {
  final Map surah;
  const SurahDetailsScreen({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surah['name'])),
      body: ListView.builder(
        itemCount: surah['verses'].length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              surah['verses'][index],
              style: const TextStyle(fontSize: 22, fontFamily: 'Uthmanic'),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}
