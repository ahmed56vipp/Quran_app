import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

String toArabicNumerals(int number) {
  const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  return number.toString().split('').map((e) => arabicDigits[int.parse(e)]).join();
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ جعل الـ RTL شاملاً لكل شاشات التطبيق بشكل تلقائي بناءً على نصيحة الصور
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        fontFamily: 'Amiri', // ✅ تأكيد الحرف الكبير لاسم الخط كما في لقطات الشاشة
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Amiri',
      ),

      themeMode: ThemeMode.system,
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
  int? lastSurahId;
  String? lastSurahName;
  int? lastVerseIndex;
  List<dynamic> surahs = [];

  @override
  void initState() {
    super.initState();
    loadData();
    loadLastRead();
  }

  Future<void> loadData() async {
    final data = await rootBundle.loadString('assets/data/quran_data.json');
    setState(() {
      surahs = json.decode(data);
    });
  }

  Future<void> loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastSurahId = prefs.getInt('last_surah_id');
      lastSurahName = prefs.getString('last_surah_name');
      lastVerseIndex = prefs.getInt('last_verse_index');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: Column(
        children: [
          // 🔖 زر العودة لآخر قراءة
          if (lastSurahId != null && lastSurahName != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bookmark),
                label: Text('آخر قراءة: $lastSurahName'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahDetailScreen(
                        surahId: lastSurahId!,
                        surahName: lastSurahName!,
                        initialVerse: lastVerseIndex ?? 0,
                      ),
                    ),
                  );
                  loadLastRead(); // لتحديث الزر عند العودة
                },
              ),
            ),

          // 📖 قائمة الفهرس المعدلة والمحاذية لليمين تماماً
          Expanded(
            child: surahs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            // إجبار عناصر الـ ListTile على الالتزام باليمين المطلق
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              surah['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              'عدد الآيات: ${surah['verses'].length}',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.right,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[50],
                              child: Text(
                                toArabicNumerals(index + 1),
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SurahDetailScreen(
                                    surahId: index,
                                    surahName: surah['name'],
                                    initialVerse: 0,
                                  ),
                                ),
                              );
                              loadLastRead();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int initialVerse;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.initialVerse,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  List verses = [];
  double _fontSize = 22.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadSurah();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadSurah() async {
    final data = await rootBundle.loadString('assets/data/quran_data.json');
    final jsonData = json.decode(data);

    setState(() {
      verses = jsonData[widget.surahId]['verses'];
    });

    // القفز إلى الآية المحددة في حال تم استدعاؤها من "آخر قراءة" بعد رسم الواجهة
    if (widget.initialVerse > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToVerse(widget.initialVerse + 1);
      });
    }
  }

  Future<void> saveLastRead(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_verse_index', index);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الموضع عند الآية: ${toArabicNumerals(index + 1)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // دالة الحساب الدقيقة للانتقال والذهاب للآية المطلوبة بسلاسة
  void _goToVerse(int verseNumber) {
    if (verses.isEmpty) return;

    if (verseNumber < 1 || verseNumber > verses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رقم الآية غير صحيح! السورة تحتوي على ${verses.length} آية.')),
      );
      return;
    }

    int totalCharacters = verses.fold(0, (sum, v) => sum + v['text'].toString().length);
    int targetCharacters = 0;
    for (int i = 0; i < verseNumber - 1; i++) {
      targetCharacters += verses[i]['text'].toString().length;
    }

    double ratio = totalCharacters > 0 ? (targetCharacters / totalCharacters) : 0.0;
    double targetOffset = _scrollController.position.maxScrollExtent * ratio;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
  }

  // نافذة إدخال رقم الآية المراد الذهاب إليها
  void _showGoToVerseDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الذهاب إلى آية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: inputController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'أدخل رقم الآية (1 - ${verses.length})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () {
              final int? verseNum = int.tryParse(inputController.text);
              Navigator.pop(context);
              if (verseNum != null) {
                _goToVerse(verseNum);
              }
            },
            child: const Text('ذهاب', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.find_in_page, size: 26),
            tooltip: 'الذهاب إلى آية',
            onPressed: verses.isEmpty ? null : _showGoToVerseDialog,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.text_fields, size: 26),
              tooltip: 'إعدادات الخط',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      
      // درج جانبي للتحكم بحجم خط القراءة بكل أريحية
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields, color: Colors.green[800], size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'إعدادات الخط',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800]),
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1.2),
                Text(
                  'حجم خط القراءة الحالي: ${_fontSize.toInt()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize += 2),
                      child: const Text('A+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                      onPressed: () => setState(() => _fontSize = (_fontSize > 16) ? _fontSize - 2 : _fontSize),
                      child: const Text('A-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      body: verses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                final verse = verses[index];

                return GestureDetector(
                  onTap: () => saveLastRead(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch, // التمدد لضمان اتجاه المحاذاة تماماً
                      children: [
                        Text(
                          verse['text'],
                          textAlign: TextAlign.right, // ✅ تأكيد المحاذاة لليمين للنص القرآني
                          style: TextStyle(
                            fontSize: _fontSize,
                            height: 2.0,
                            fontFamily: 'Amiri', // الحرف الكبير المتناسق مع pubspec.yaml
                          ),
                        ),
                        const SizedBox(height: 8),
                        // جعل علامة رقم الآية تلتصق بأقصى اليمين بالتناسق
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '﴿ ${toArabicNumerals(index + 1)} ﴾',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: _fontSize - 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
