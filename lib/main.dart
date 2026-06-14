import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(home: SurahListScreen()));
}

// 1. صفحة القائمة الرئيسية
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurahDetailsScreen(
                          surahNumber: surahs[index]['number'], 
                          surahName: surahs[index]['name']
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// 2. صفحة عرض الآيات
class SurahDetailsScreen extends StatelessWidget {
  final int surahNumber;
  final String surahName;
  const SurahDetailsScreen({super.key, required this.surahNumber, required this.surahName});

  Future<Map> loadSurahData() async {
    String response = await rootBundle.loadString('assets/surah_$surahNumber.json');
    return json.decode(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surahName)),
      body: FutureBuilder(
        future: loadSurahData(),
        builder: (context, snapshot) {
          // هنا التصحيح: استبدلنا isDone بـ connectionState == ConnectionState.done
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          
          List ayahs = snapshot.data!['ayahs'];
          return ListView.builder(
            itemCount: ayahs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  ayahs[index]['text'],
                  style: const TextStyle(fontSize: 22, fontFamily: 'Uthmanic'),
                  textAlign: TextAlign.right,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
