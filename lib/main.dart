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
      home: const SurahListScreen(),
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
    loadQuranIndex();
  }

  Future<void> loadQuranIndex() async {
    final String response = await rootBundle.loadString('assets/surah.json');
    final data = await json.decode(response);
    setState(() {
      surahs = data;
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
            title: Text(surahs[index]['titleAr']),
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
    String index = widget.surah['index'];
    int id = int.parse(index);
    final String response = await rootBundle.loadString('assets/surah/$id.json');
    final data = await json.decode(response);
    setState(() {
      verses = data['ayahs'];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.surah['titleAr'])),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: verses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    verses[index]['text'],
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
    );
  }
}
