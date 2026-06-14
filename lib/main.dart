import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SurahListScreen(),
    );
  }
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
    loadQuranData();
  }

  Future<void> loadQuranData() async {
    final String response = await rootBundle.loadString('assets/quran_full.json');
    final data = await json.decode(response);
    setState(() {
      surahs = data['surahs'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("القرآن الكريم")),
      body: ListView.builder(
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(surahs[index]['name']),
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
