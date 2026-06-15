import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SurahListScreen(),
  ));
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
    try {
      final String indexResponse = await rootBundle.loadString('assets/quran_data.json');
      List indexData = json.decode(indexResponse);
      indexData.sort((a, b) => a['number'].compareTo(b['number']));

      final String fullResponse = await rootBundle.loadString('assets/quran_full.json');
      final List fullData = json.decode(fullResponse);

      Map tempDetails = {};
      for (var item in fullData) {
        tempDetails[item['index'].toString().padLeft(3, '0')] = item;
      }

      setState(() {
        surahs = indexData;
        surahDetails = tempDetails;
      });
    } catch (e) {
      print("Error loading data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: const Text("القرآن الكريم"), backgroundColor: const Color(0xFF333300)),
      body: surahs.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                String surahIndex = surahs[index]['number'].toString().padLeft(3, '0');
                var details = surahDetails[surahIndex];
                String type = details != null ? details['type'] : "";

                return ListTile(
                  leading: Image.asset(type == 'Makkiyah' ? 'assets/mk.png' : 'assets/md.png', width: 40, height: 40, errorBuilder: (c, o, s) => const Icon(Icons.book, color: Colors.white)),
                  title: Text(surahs[index]['name'], style: const TextStyle(color: Colors.white, fontSize: 20)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SurahDetailsScreen(surahNumber: surahs[index]['number'], surahName: surahs[index]['name'])));
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
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: Text(surahName), backgroundColor: const Color(0xFF333300)),
      body: FutureBuilder<Map>(
        future: loadSurahData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text("خطأ في تحميل البيانات", style: TextStyle(color: Colors.white)));
          
          Map verseMap = snapshot.data!['verse'];
          List keys = verseMap.keys.toList()..sort(); 
          
          String fullText = "";
          int counter = 0;
          for (int i = 0; i < keys.length; i++) {
            String text = verseMap[keys[i]];
            if (i == 0) {
              fullText += "$text ";
            } else {
              counter++;
              fullText += "$text ($counter) ";
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(fullText, textAlign: TextAlign.justify, style: const TextStyle(fontFamily: 'ahmed', fontSize: 26, color: Colors.white, height: 2.2)),
          );
        },
      ),
    );
  }
}
