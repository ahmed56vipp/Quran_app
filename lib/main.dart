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
  Map surahDetails = {}; // لتخزين بيانات quran_full.json

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    // تحميل الفهرس
    final String indexResponse = await rootBundle.loadString('assets/quran_data.json');
    final indexData = await json.decode(indexResponse);
    
    // تحميل بيانات السور الكاملة (النوع)
    final String fullResponse = await rootBundle.loadString('assets/quran_full.json');
    final fullData = await json.decode(fullResponse);

    // تحويل البيانات لقاموس ليسهل الوصول لها برقم السورة
    Map tempDetails = {};
    for (var item in fullData) {
      tempDetails[item['index']] = item;
    }

    setState(() {
      surahs = indexData['surahs'];
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

// كلاس SurahDetailsScreen يبقى كما هو (الذي يعمل لديك حالياً)
// ...
