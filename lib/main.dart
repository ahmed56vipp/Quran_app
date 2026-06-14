import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(home: SurahListScreen()));
}

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});
  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List surahs = [];
  String status = "جاري التحميل...";

  @override
  void initState() {
    super.initState();
    loadQuranIndex();
  }

  Future<void> loadQuranIndex() async {
    try {
      // المسار الصحيح للفهرس داخل مجلد quran_data
      final String response = await rootBundle.loadString('assets/quran_data/quran_data.json');
      final data = await json.decode(response);
      setState(() {
        surahs = data;
        status = "";
      });
    } catch (e) {
      setState(() {
        status = "خطأ في تحميل الفهرس: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("القرآن الكريم")),
      body: surahs.isEmpty
          ? Center(child: Text(status))
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(surahs[index]['name'] ?? "سورة"), // تأكد من اسم المفتاح في ملف الـ JSON
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurahDetailsScreen(surah: surahs[index]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class SurahDetailsScreen extends StatefulWidget {
  final Map surah;
  const SurahDetailsScreen({super.key, required this.surah});
  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  List verses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSurahContent();
  }

  Future<void> loadSurahContent() async {
    try {
      // الحصول على رقم السورة
      String index = widget.surah['index'].toString();
      // المسار الصحيح للسور في assets مباشرة
      final String response = await rootBundle.loadString('assets/surah_$index.json');
      final data = await json.decode(response);
      setState(() {
        verses = data['ayahs'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error loading surah: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.surah['name'] ?? "سورة")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: verses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    verses[index]['text'],
                    style: const TextStyle(fontSize: 22, fontFamily: 'Uthmanic'),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
    );
  }
}
