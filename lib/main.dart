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
  Map surahDetails = {};

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    final String indexResponse = await rootBundle.loadString('assets/quran_data.json');
    final List indexData = json.decode(indexResponse);
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
                  subtitle: Text(type == 'Makkiyah' ? "مكية" : "مدنية"),
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
      body: FutureBuilder<Map>(
        future: loadSurahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("لا توجد بيانات"));
          }
          
          Map verseMap = snapshot.data!['verse'];
          List verses = verseMap.values.toList();

          return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              String verseNumber = (index + 1).toString();
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: verses[index] + " "),
                      TextSpan(
                        text: "($verseNumber)", 
                        style: const TextStyle(fontSize: 18, color: Colors.grey, fontFamily: 'Roboto'), // رقم الآية بخط عادي
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 22, fontFamily: 'ahmed'), // هنا طبقنا الخط باسم ahmed
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
