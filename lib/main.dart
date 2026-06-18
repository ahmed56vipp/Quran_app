import 'package:flutter/material.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مصحف التجويد الإلكتروني',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'ahmed', // الخط المخصص لتطبيقك
      ),
      home: const SurahListPage(),
    );
  }
}

/// شاشة قائمة السور
class SurahListPage extends StatelessWidget {
  const SurahListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // نموذج بيانات لمحاكاة قائمة السور
    final List<Map<String, dynamic>> surahs = [
      {"id": 1, "name": "الفاتحة", "verses": 7, "type": "مكية"},
      {"id": 2, "name": "البقرة", "verses": 286, "type": "مدنية"},
      {"id": 3, "name": "آل عمران", "verses": 200, "type": "مدنية"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصحف الشريف', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade800,
      ),
      body: ListView.builder(
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          final surah = surahs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade100,
                child: Text('${surah['id']}', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
              ),
              title: Text(
                surah['name'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: Text('آياتها: ${surah['verses']} - ${surah['type']}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahDetailsPage(
                      surahName: surah['name'],
                      surahId: surah['id'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// شاشة عرض السورة مع ميزة تلوين أحكام التجويد بدقة دون تقطيع الحروف
class SurahDetailsPage extends StatefulWidget {
  final String surahName;
  final int surahId;

  const SurahDetailsPage({Key? key, required this.surahName, required this.surahId}) : super(key: key);

  @override
  State<SurahDetailsPage> createState() => _SurahDetailsPageState();
}

class _SurahDetailsPageState extends State<SurahDetailsPage> {
  double _fontSize = 24.0;
  Map<String, dynamic>? _tajweedRulesData;
  bool _isLoading = true;

  // محاكاة لآيات السورة (مثال: سورة البقرة أو الفاتحة)
  final List<String> _verses = [
    "الم",
    "ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ",
    "الَّذِينَ يُؤْمِنُونَ بِالْغَيْبِ وَيُقِيمُونَ الصَّلَاةَ وَمِمَّا رَزَقْنَاهُمْ يُنفِقُونَ",
    "وَالَّذِينَ يُؤْمِنُونَ بِمَا أُنزِلَ إِلَيْكَ وَمَا أُنزِلَ مِن قَبْلِكَ وَبِالْآخِرَةِ هُمْ يُوقِنُونَ"
  ];

  @override
  void initState() {
    super.initState();
    _loadTajweedData();
  }

  /// محاكاة تحميل بيانات أحكام التجويد (تُستبدل بملف الـ JSON الخاص بك)
  void _loadTajweedData() async {
    await Future.delayed(const Duration(milliseconds: 500)); // محاكاة وقت التحميل
    
    // بيانات تجويدية تجريبية دقيقة لاختبار الكلمات المتصلة مثل (مِن قَبْلِكَ - يُنفِقُونَ)
    setState(() {
      _tajweedRulesData = {
        "verse": {
          "verse_2": [
            {"start": 57, "end": 62, "rule": "ikhfa"} // إخفاء في كلمة "يُنفِقُونَ"
          ],
          "verse_3": [
            {"start": 19, "end": 24, "rule": "ikhfa"}, // إخفاء "أُنزِلَ"
            {"start": 47, "end": 52, "rule": "ikhfa"}, // إخفاء "أُنزِلَ"
            {"start": 57, "end": 61, "rule": "iqlab"}   // إقلاب/إخفاء في "مِن قَبْلِكَ"
          ]
        }
      };
      _isLoading = false;
    });
  }

  /// دالة جلب اللون المناسب حسب حكم التجويد
  Color _getTajweedColorByRule(String rule) {
    switch (rule) {
      case 'ghunnah':
        return Colors.red.shade700;
      case 'idgham':
        return Colors.blue.shade700;
      case 'ikhfa':
        return Colors.orange.shade800; // لون الإخفاء
      case 'iqlab':
        return Colors.green.shade700;  // لون الإقلاب
      case 'qalqalah':
        return Colors.purple.shade700;
      case 'hamzat_wasl':
        return Colors.grey.shade600;
      default:
        return Colors.black87;
    }
  }

  /// الدالة الاحترافية والمحدثة لبناء النصوص الملونة دون تقطيع الحروف العربية
  List<InlineSpan> _buildDynamicTajweedSpans(String verseText, int verseIndex) {
    List<InlineSpan> spans = [];
    const String zwj = '\u200D'; // الرمز السحري (Zero-Width Joiner) لربط الحروف منعاً للتقطع
    
    // إذا لم تتوفر بيانات التجويد، يتم عرض النص عاديًا بالكامل
    if (_tajweedRulesData == null || _tajweedRulesData!['verse'] == null) {
      spans.add(TextSpan(text: verseText, style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87)));
      return spans;
    }

    final String key = 'verse_$verseIndex';
    final List<dynamic>? rules = _tajweedRulesData!['verse'][key];

    // إذا كانت الآية لا تحتوي على أحكام، يتم عرضها بنص موحد
    if (rules == null || rules.isEmpty) {
      spans.add(TextSpan(text: verseText, style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87)));
      return spans;
    }

    // ترتيب الأحكام تصاعدياً حسب مؤشر البداية لضمان التلوين الصحيح بالترتيب
    List<dynamic> sortedRules = List.from(rules);
    sortedRules.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    int currentIdx = 0;
    for (int i = 0; i < sortedRules.length; i++) {
      final ruleMap = sortedRules[i];
      int start = ruleMap['start'] as int;
      int end = ruleMap['end'] as int;
      String ruleName = ruleMap['rule'] as String;

      // حماية لمنع تخطي حدود النص أو التداخل الخاطئ
      if (start < currentIdx || start > verseText.length || end > verseText.length || start > end) continue;

      // 1. النص العادي (قبل الحكم): نضيف zwj في نهايته ليلتحم مع الحرف الملون القادم
      if (start > currentIdx) {
        String normalText = verseText.substring(currentIdx, start);
        spans.add(TextSpan(
          text: normalText + zwj,
          style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87),
        ));
      }

      // 2. النص الملون (موضع الحكم): نحقن zwj قبله وبعده ليبقى مشبوكاً تماماً في الكلمة
      String coloredChunk = verseText.substring(start, end);
      spans.add(TextSpan(
        text: (start > 0 ? zwj : "") + coloredChunk + (end < verseText.length ? zwj : ""),
        style: TextStyle(
          fontSize: _fontSize,
          fontFamily: 'ahmed',
          height: 2.2,
          color: _getTajweedColorByRule(ruleName),
          fontWeight: ruleName.contains('hamzat_wasl') ? FontWeight.normal : FontWeight.bold,
        ),
      ));

      currentIdx = end;
    }

    // 3. النص المتبقي (بعد آخر حكم): نضيف zwj في بدايته ليتصل بآخر حرف ملون
    if (currentIdx < verseText.length) {
      String remainingText = verseText.substring(currentIdx);
      spans.add(TextSpan(
        text: (currentIdx > 0 ? zwj : "") + remainingText,
        style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade800,
        actions: [
          // شريط علوي للتحكم الآمن في حجم الخط داخل الشاشة
          Row(
            children: [
              const Icon(Icons.text_fields, size: 16),
              Slider(
                value: _fontSize,
                min: 18.0,
                max: 38.0,
                activeColor: Colors.amber,
                inactiveColor: Colors.teal.shade200,
                onChanged: (newSize) {
                  setState(() {
                    _fontSize = newSize;
                  });
                },
              ),
            ],
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                color: const Color(0xFFFBF7F0), // لون خلفية مريح للعين (ورقي)
                padding: const EdgeInsets.all(16.0),
                child: ListView.separated(
                  itemCount: _verses.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.black12, height: 20),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: RichText(
                        textAlign: TextAlign.justify,
                        text: TextSpan(
                          children: [
                            // بناء الآية بأحكامها الملونة المتصلة
                            ..._buildDynamicTajweedSpans(_verses[index], index),
                            // رمز نهاية الآية مع رقمها
                            TextSpan(
                              text: ' ﴿${index + 1}﴾ ',
                              style: TextStyle(
                                fontSize: _fontSize - 4,
                                color: Colors.teal.shade700,
                                fontFamily: 'Arial', // خط أرقام قياسي
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
