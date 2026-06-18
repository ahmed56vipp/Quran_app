import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

String toArabicNumerals(int number) {
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number.toString().split('').map((char) {
    return arabicDigits[int.parse(char)];
  }).join();
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        fontFamily: 'ahmed', 
      ),
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
  int? _lastSurahId;
  String? _lastSurahName;
  int? _lastVersesCount;
  String? _lastSurahType;
  List<dynamic> surahs = [];

  @override
  void initState() {
    super.initState();
    _loadIndexData();
    _loadLastReadPosition();
  }

  Future<void> _loadIndexData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/quran_data.json');
      setState(() {
        surahs = json.decode(response);
      });
    } catch (e) {
      debugPrint("خطأ في تحميل الفهرس الرئيسي: $e");
    }
  }

  Future<void> _loadLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSurahId = prefs.getInt('last_surah_id');
      _lastSurahName = prefs.getString('last_surah_name');
      _lastVersesCount = prefs.getInt('last_verses_count');
      _lastSurahType = prefs.getString('last_surah_type');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'ahmed')),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_lastSurahId != null && _lastSurahName != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bookmark),
                label: Text('العودة إلى آخر موضع قراءة: $_lastSurahName', style: const TextStyle(fontFamily: 'ahmed')),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surahId: _lastSurahId!,
                        surahName: _lastSurahName!,
                        versesCount: _lastVersesCount ?? 0,
                        surahType: _lastSurahType ?? 'مكية',
                      ),
                    ),
                  );
                  _loadLastReadPosition();
                },
              ),
            ),
          
          Expanded(
            child: surahs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      
                      String rawId = surah['id'].toString().trim();
                      rawId = rawId.replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
                                   .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
                                   .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8').replaceAll('٩', '9');
                      
                      final int sId = int.tryParse(rawId) ?? (index + 1);
                      final String sName = surah['name'] ?? 'بدون اسم';
                      final String sType = surah['type'] ?? 'مكية';
                      final int vCount = int.tryParse(surah['verses_count'].toString()) ?? 0;
                      
                      final bool isMeccan = sType.contains('مكية');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              sName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'ahmed'),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              "$sType | آياتها: $vCount",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'ahmed'),
                              textAlign: TextAlign.right,
                            ),
                            leading: SizedBox(
                              width: 36,
                              height: 36,
                              child: Image.asset(
                                isMeccan ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    backgroundColor: Colors.green[50],
                                    child: Text(
                                      toArabicNumerals(sId),
                                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SurahDetailScreen(
                                    surahId: sId,
                                    surahName: sName,
                                    versesCount: vCount,
                                    surahType: sType,
                                  ),
                                ),
                              );
                              _loadLastReadPosition();
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
  final int versesCount;
  final String surahType;

  const SurahDetailScreen({
    super.key, 
    required this.surahId, 
    required this.surahName,
    required this.versesCount,
    required this.surahType,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  double _fontSize = 24.0;
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _surahDataFuture;
  List<String> _currentVerses = [];
  String _errorMessage = '';

  Map<String, dynamic>? _tafsirArData;
  Map<String, dynamic>? _translationEnData;
  Map<String, dynamic>? _translationIdData;
  Map<String, dynamic>? _tajweedRulesData; 

  @override
  void initState() {
    super.initState();
    _saveLastReadPosition();
    _surahDataFuture = loadSurahData();
    _preloadTafsirAndTranslations();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', widget.surahId);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_verses_count', widget.versesCount);
    await prefs.setString('last_surah_type', widget.surahType);
  }

  Future<Map<String, dynamic>> loadSurahData() async {
    try {
      final textResponse = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final textData = json.decode(textResponse);
      Map<String, dynamic> versesMap = Map<String, dynamic>.from(textData['verse']);
      List<String> allVerses = versesMap.values.map((value) => value.toString()).toList();

      try {
        final tajweedResponse = await rootBundle.loadString('assets/tajweed/surah_${widget.surahId}.json');
        _tajweedRulesData = json.decode(tajweedResponse);
      } catch (e) {
        debugPrint("لم يتوفر ملف تجويد بالإحداثيات لهذه السورة: $e");
        _tajweedRulesData = null;
      }
      
      String? basmalah;
      List<String> dynamicVerses = [];

      if (widget.surahId == 1 || widget.surahId == 9) {
        dynamicVerses = allVerses;
      } else {
        if (allVerses.isNotEmpty && (allVerses[0].contains("بِسْمِ") || allVerses[0].startsWith("بِسمِ"))) {
          basmalah = allVerses[0];
          dynamicVerses = allVerses.sublist(1);
        } else {
          dynamicVerses = allVerses;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentVerses = dynamicVerses;
          });
        }
      });

      return {
        'basmalah': basmalah,
        'verses': dynamicVerses,
      };
    } catch (e) {
      setState(() {
        _errorMessage = "لم يتم العثور على ملف السورة رقم ${widget.surahId} أو أن الصيغة غير صحيحة.";
      });
      return {'basmalah': null, 'verses': <String>[]};
    }
  }

  Future<void> _preloadTafsirAndTranslations() async {
    try {
      final arString = await rootBundle.loadString('assets/translation/ar/ar_translation_${widget.surahId}.json');
      _tafsirArData = json.decode(arString);
    } catch (_) {}

    try {
      final enString = await rootBundle.loadString('assets/translation/en/en_translation_${widget.surahId}.json');
      _translationEnData = json.decode(enString);
    } catch (_) {}

    try {
      final idString = await rootBundle.loadString('assets/translation/id/id_translation_${widget.surahId}.json');
      _translationIdData = json.decode(idString);
    } catch (_) {}
  }

  String _getTafsirOrTranslationText(Map<String, dynamic>? data, int verseNum) {
    if (data == null || data['verse'] == null) return "النص غير متوفر حالياً لهذا الخيار.";
    var verseMap = data['verse'];
    
    if (verseMap is Map) {
      if (verseMap.containsKey('verse_$verseNum')) {
        return verseMap['verse_$verseNum'].toString();
      } else if (verseMap.containsKey('verse_${verseNum - 1}')) {
        return verseMap['verse_${verseNum - 1}'].toString();
      } else if (verseMap.containsKey(verseNum.toString())) {
        return verseMap[verseNum.toString()].toString();
      }
    }
    return "النص غير متوفر لهذه الآية.";
  }

  Color _getTajweedColorByRule(String rule) {
    if (rule.contains('madd')) return Colors.red[700]!;            
    if (rule.contains('ghunnah')) return Colors.orange[700]!;       
    if (rule.contains('idghaam')) return Colors.blue[700]!;         
    if (rule.contains('ikhfa')) return Colors.teal[700]!;           
    if (rule.contains('qalqalah')) return Colors.green[700]!;       
    if (rule.contains('iqlab')) return Colors.purple[700]!;         
    return Colors.black87; 
  }

  List<InlineSpan> _buildDynamicTajweedSpans(String verseText, int verseIndex) {
    List<InlineSpan> spans = [];
    
    if (_tajweedRulesData == null || _tajweedRulesData!['verse'] == null) {
      spans.add(TextSpan(text: verseText, style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87)));
      return spans;
    }

    final String key = 'verse_$verseIndex';
    final List<dynamic>? rules = _tajweedRulesData!['verse'][key];

    if (rules == null || rules.isEmpty) {
      spans.add(TextSpan(text: verseText, style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87)));
      return spans;
    }

    List<dynamic> sortedRules = List.from(rules);
    sortedRules.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    int currentIdx = 0;
    for (var ruleMap in sortedRules) {
      int start = ruleMap['start'] as int;
      int end = ruleMap['end'] as int;
      String ruleName = ruleMap['rule'] as String;

      if (start < currentIdx || start > verseText.length || end > verseText.length || start > end) continue;

      if (start > currentIdx) {
        spans.add(TextSpan(
          text: verseText.substring(currentIdx, start),
          style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87),
        ));
      }

      spans.add(TextSpan(
        text: verseText.substring(start, end),
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

    if (currentIdx < verseText.length) {
      spans.add(TextSpan(
        text: verseText.substring(currentIdx),
        style: TextStyle(fontSize: _fontSize, fontFamily: 'ahmed', height: 2.2, color: Colors.black87),
      ));
    }

    return spans;
  }

  void _showTafsirBottomSheet(int verseNumber, String verseText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(
              color: Color(0xFFFDFBF7),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "الآية (${toArabicNumerals(verseNumber)})",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800], fontFamily: 'ahmed'),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical:
