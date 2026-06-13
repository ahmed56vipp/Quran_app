import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SurahListScreen());
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
    fetchSurahs();
  }

  fetchSurahs() async {
    final response = await http.get(Uri.parse('https://api.alquran.cloud/v1/surah'));
    if (response.statusCode == 200) {
      setState(() {
        surahs = json.decode(response.body)['data'];
      });
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
                  title: Text(surahs[index]['name']),
                  subtitle: Text(surahs[index]['englishName']),
                );
              },
            ),
    );
  }
}
