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
  Map surahDetails = {};
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      final String indexResponse = await rootBundle.loadString('assets/quran_data.json');
      List indexData = json.decode(indexResponse);
      indexData.sort((a, b) => a['number'].compareTo(b['number']));

      final String fullResponse = await rootBundle.loadString('assets/quran_full.json');
      final List fullData = json.decode(fullResponse);

      Map tempDetails = {};
      for (var item in fullData) {
        tempDetails[item['index']] = item;
      }

      setState(() {
        surahs = indexData;
        surahDetails = tempDetails;
      });
    } catch (e) {
      setState(() {
        errorMessage = "خطأ في تحميل البيانات: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage.isNotEmpty) {
      return Scaffold(body: Center(child: Text(errorMessage)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("القرآن الكريم")),
      body: surahs.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                String surahIndex = surahs[index]['number'].toString().padLeft(3, '0');
                var details = surahDetails[surahIndex];
                String type = details != null ? details['type'] : "";

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
      body: FutureBuilder<Map>(
        future: loadSurahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("خطأ: ${snapshot.error}"));
          }
          
          Map verseMap = snapshot.data!['verse'];
          List verses = verseMap.values.toList();

          return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              String verseText = verses[index];
              bool isBasmala = verseText.contains("بسم الله الرحمن الرحيم");
              
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  verseText + (isBasmala ? "" : " (${index + 1})"),
                  style: const TextStyle(fontSize: 22, fontFamily: 'ahmed'),
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
