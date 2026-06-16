import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  ThemeMode _themeMode = ThemeMode.light;
  double _fontSize = 20.0;
  List<int> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // تحميل الإعدادات المحفوظة
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = (prefs.getBool('isDark') ?? false) ? ThemeMode.dark : ThemeMode.light;
      _fontSize = prefs.getDouble('fontSize') ?? 20.0;
      _favorites = prefs.getStringList('favorites')?.map(int.parse).toList() ?? [];
    });
  }

  // حفظ الإعدادات
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setStringList('favorites', _favorites.map((e) => e.toString()).toList());
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      _saveSettings();
    });
  }

  void updateFontSize(double newSize) {
    if (newSize < 12 || newSize > 40) return;
    setState(() {
      _fontSize = newSize;
      _saveSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: SurahListScreen(
        toggleTheme: toggleTheme,
        fontSize: _fontSize,
        updateFontSize: updateFontSize,
      ),
    );
  }
}

class SurahListScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final double fontSize;
  final Function(double) updateFontSize;

  const SurahListScreen({super.key, required this.toggleTheme, required this.fontSize, required this.updateFontSize});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  late Future<List<dynamic>> _surahsFuture;

  @override
  void initState() {
    super.initState();
    _surahsFuture = loadQuranIndex();
  }

  Future<List<dynamic>> loadQuranIndex() async {
    final String response = await rootBundle.loadString('assets/data/quran_data.json');
    return json.decode(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم'),
        actions: [
          IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _surahsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text("خطأ في تحميل البيانات"));
          
          final surahs = snapshot.data!;
          return ListView.builder(
            itemCount: surahs.length,
            itemBuilder: (context, index) {
              final surah = surahs[index];
              bool isMeccan = surah['type'] == 'مكية';
              return ListTile(
                leading: CircleAvatar(child: Text("${surah['id']}")),
                title: Text(surah['name']),
                subtitle: Text(isMeccan ? "مكية" : "مدنية"),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => 
                    SurahDetailScreen(surahId: surah['id'], surahName: surah['name'], fontSize: widget.fontSize)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SurahDetailScreen extends StatelessWidget {
  final int surahId;
  final String surahName;
  final double fontSize;

  const SurahDetailScreen({super.key, required this.surahId, required this.surahName, required this.fontSize});

  Future<List<String>> loadSurah() async {
    final String response = await rootBundle.loadString('assets/surah/surah_$surahId.json');
    final data = json.decode(response);
    Map<String, dynamic> versesMap = data['verse'];
    List<String> allVerses = versesMap.values.map((value) => value.toString()).toList();
    
    // منطق فلترة البسملة: إذا لم تكن سورة الفاتحة (1) والتوبة (9)، احذف البسملة (أول سطر)
    if (surahId != 1 && surahId != 9) {
      return allVerses.sublist(1);
    }
    return allVerses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surahName)),
      body: FutureBuilder<List<String>>(
        future: loadSurah(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final verses = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: verses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "${verses[index]} \u06DD ${index + 1}",
                  style: TextStyle(fontSize: fontSize, fontFamily: 'ahmed'),
                  textAlign: TextAlign.justify,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
