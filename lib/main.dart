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

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
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
                String surahIndex = surahs[index]['number'].toString().padLeft(3, '0');
                var details = surahDetails[surahIndex];
                String type = details != null ? details['type'] : "";

                return ListTile(
                  leading: Icon(
                    type == 'Makkiyah' ? Icons.location_on : Icons.mosque,
                    color: type == 'Makkiyah' ? Colors.red : Colors.green,
                  ),
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
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("خطأ في تحميل البيانات"));
          }
          
          Map verseMap = snapshot.data!['verse'];
          List keys = verseMap.keys.toList();
          int verseCounter = 0; // عداد الترقيم الصحيح

          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              String key = keys[index];
              String verseText = verseMap[key];
              
              // كشف البسملة بأي شكل كانت
              bool isBasmala = verseText.contains("بسم الله الرحمن الرحيم");
              
              // زيادة العداد فقط للآيات
              if (!isBasmala) {
                verseCounter++;
              }

              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: verseText + " "),
                      if (!isBasmala) 
                        TextSpan(
                          text: "($verseCounter)", 
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                    ],
                  ),
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
