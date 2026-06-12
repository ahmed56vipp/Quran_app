import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() => runApp(MaterialApp(home: QuranApp()));

class QuranApp extends StatefulWidget {
  @override
  _QuranAppState createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  String _data = "جاري تهيئة قاعدة البيانات...";

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  Future<void> initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'demo.db');

    Database db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute("CREATE TABLE quran (id INTEGER PRIMARY KEY, verse TEXT)");
      await db.execute("INSERT INTO quran (verse) VALUES ('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ')");
    });

    List<Map> list = await db.rawQuery('SELECT * FROM quran');
    setState(() {
      _data = list[0]['verse'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تطبيق القرآن الكريم")),
      body: Center(child: Text(_data, style: TextStyle(fontSize: 24))),
    );
  }
}

