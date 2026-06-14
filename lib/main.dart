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
    loadQuranData();
  }

  Future<void> loadQuranData() async {
    try {
      final String response = await rootBundle.loadString('assets/quran_full.json');
      final data = await json.decode(response);
      setState(() {
        // الملف عبارة عن قائمة مباشرة، لذا نضع البيانات كما هي
        surahs = data; 
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
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
                  title: Text(surahs[index]['titleAr']), // اسم السورة بالعربي
                  subtitle: Text(surahs[index]['title']), // اسم السورة بالإنجليزي
                  leading: CircleAvatar(child: Text(surahs[index]['index'])),
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
      appBar: AppBar(title: Text(surah['titleAr'])),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "معلومات السورة: ${surah['type']} - عدد الآيات: ${surah['count']}",
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
