import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Uthmanic', // تعميم الخط العثماني على التطبيق بالكامل
      ),
      home: SurahListScreen(),
    );
  }
}

class SurahListScreen extends StatefulWidget {
  @override
  _SurahListScreenState createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List surahs = [];

  @override
  void initState() {
    super.initState();
    loadSurahs();
  }

  Future<void> loadSurahs() async {
    try {
      final String response = await rootBundle.loadString('assets/quran_data.json');
      final data = await json.decode(response);
      setState(() {
        surahs = data['surahs'];
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("القرآن الكريم", style: TextStyle(color: Colors.white, fontFamily: 'Uthmanic')),
        backgroundColor: Colors.teal,
      ),
      body: surahs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text("${surahs[index]['number']}"),
                    ),
                    title: Text(
                      surahs[index]['name'],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(surahs[index]['englishName']),
                    trailing: const Icon(Icons.menu_book, color: Colors.teal),
                  ),
                );
              },
            ),
    );
  }
}
