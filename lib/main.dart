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

  @override
  void initState() {
    super.initState();
    loadQuranIndex();
  }

  Future<void> loadQuranIndex() async {
    final String response = await rootBundle.loadString('assets/quran_data.json');
    final data = await json.decode(response);
    setState(() {
      // بناءً على صورة ملف quran_data.json، البيانات داخل مفتاح "surahs"
      surahs = data['surahs'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("القرآن الكريم")),
      body: surahs.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(surahs[index]['name']),
                  subtitle: Text(surahs[index]['englishName']),
                );
              },
            ),
    );
  }
}
