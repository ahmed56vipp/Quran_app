import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final List<dynamic> juzData;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.juzData,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  bool _isNightMode = false;
  bool _isEyeProtection = false;
  
  Map<String, dynamic>? _versesMap;
  List<dynamic> _surahJuzRanges = [];
  
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _verseKeys = [];
  int _currentVisibleVerse = 1; // تتبع الآية الحالية الظاهرة في أعلى الشاشة

  @override
  void initState() {
    super.initState();
    // إنشاء مفاتيح فريدة لكل آية لتتبع موضعها أثناء التمرير
    _verseKeys.addAll(List.generate(widget.versesCount + 1, (index) => GlobalKey()));
    _loadSurahVerses();
    
    // الاستماع لحركة التمرير لتحديث رقم الجزء ديناميكياً
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // تحميل آيات السورة الحقيقية وبيانات الأجزاء الخاصة بها من ملف JSON
  Future<void> _loadSurahVerses() async {
    try {
      final String response = await rootBundle.loadString('assets/data/quran_data.json');
      final List<dynamic> data = json.decode(response);
      
      // البحث عن السورة المطلوبة بواسطة معرف السورة (id)
      final surahData = data.firstWhere(
        (element) => int.tryParse(element['id'].toString()) == widget.surahId,
        orElse: () => null,
      );

      if (surahData != null) {
        setState(() {
          _versesMap = surahData['verse'] as Map<String, dynamic>?;
          _surahJuzRanges = surahData['juz'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل آيات السورة: $e");
    }
  }

  // دالة تتبع السطر الحالي وتحديد الآية العلوية لتغيير الجزء تلقائياً
  void _onScroll() {
    if (_verseKeys.isEmpty) return;
    
    double appBarHeight = Scaffold.of(context).appBarMaxHeight ?? 100.0;
    int detectedVerse = 1;

    for (int i = 1; i <= widget.versesCount; i++) {
      final contextKey = _verseKeys[i].currentContext;
      if (contextKey != null) {
        final box = contextKey.findRenderObject() as RenderBox?;
        if (box != null) {
          final positionY = box.localToGlobal(Offset.zero).dy;
          // إذا كانت الآية قد وصلت إلى منطقة القراءة أسفل الشريط العلوي مباشرة
          if (positionY + box.size.height > appBarHeight) {
            detectedVerse = i;
            break;
          }
        }
      }
    }

    if (_currentVisibleVerse != detectedVerse) {
      setState(() {
        _currentVisibleVerse = detectedVerse;
      });
    }
  }

  // حساب رقم الجزء الحالي بناءً على الآية المرئية حالياً
  String _getDynamicJuzNumber() {
    if (_surahJuzRanges.isEmpty) {
      return _getFallbackJuz();
    }

    for (var juz in _surahJuzRanges) {
      final startStr = juz['verse']['start'].toString().replaceAll('verse_', '');
      final endStr = juz['verse']['end'].toString().replaceAll('verse_', '');
      
      int start = int.tryParse(startStr) ?? 1;
      int end = int.tryParse(endStr) ?? widget.versesCount;
      
      if (_currentVisibleVerse >= start && _currentVisibleVerse <= end) {
        return juz['index'].toString();
      }
    }
    return _surahJuzRanges.first['index'].toString();
  }

  // دالة احتياطية لحساب الجزء في حال عدم توفر المخطط التفصيلي في السورة
  String _getFallbackJuz() {
    if (widget.juzData.isEmpty) return '1';
    List<int> parts = [];
    for (var juz in widget.juzData) {
      int startSurah = int.tryParse(juz['start']['index'].toString()) ?? 0;
      int endSurah = int.tryParse(juz['end']['index'].toString()) ?? 0;
      int juzIndex = int.tryParse(juz['index'].toString()) ?? 0;

      if (widget.surahId >= startSurah && widget.surahId <= endSurah) {
        if (!parts.contains(juzIndex)) parts.add(juzIndex);
      }
    }
    return parts.isEmpty ? '1' : parts.first.toString();
  }

  @override
  Widget build(BuildContext context) {
    // إعدادات الألوان الذكية للأوضاع الثلاثة
    Color backgroundColor = Colors.white;
    Color textColor = const Color(0xFF1A1A1A);
    Color cardColor = const Color(0xFFFAFAFA);

    if (_isNightMode) {
      backgroundColor = const Color(0xFF121212);
      textColor = const Color(0xFFE0E0E0);
      cardColor = const Color(0xFF1E1E1E);
    } else if (_isEyeProtection) {
      backgroundColor = const Color(0xFFF4ECD8); // لون السيبيا المريح للعين
      textColor = const Color(0xFF3E2723);
      cardColor = const Color(0xFFEFE5CD);
    }

    final String currentJuz = _getDynamicJuzNumber();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              // إطار ذهبي فخم لاسم السورة مع تكبير الخط
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF1B5E20),
                ),
                child: Text(
                  widget.surahName,
                  style: const TextStyle(
                    fontFamily: 'ahmed',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // بيانات الجزء والآيات بالأرقام العادية 123 وبخط واضح ومكبر جداً
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "(${widget.surahType}) | جزء: $currentJuz", // يتغير الجزء هنا ديناميكياً 1 أو 2 أو 3 حسب موقع القراءة الحالي
                      style: const TextStyle(
                        fontFamily: 'ahmed',
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "آياتها: ${widget.versesCount}",
                      style: const TextStyle(
                        fontFamily: 'ahmed',
                        fontSize: 15,
                        color: Colors.whiteA70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isEyeProtection ? Icons.visibility : Icons.visibility_outlined,
                color: _isEyeProtection ? const Color(0xFFFFD700) : Colors.white,
              ),
              tooltip: 'حماية العين',
              onPressed: () {
                setState(() {
                  _isEyeProtection = !_isEyeProtection;
                  if (_isEyeProtection) _isNightMode = false;
                });
              },
            ),
            IconButton(
              icon: Icon(
                _isNightMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                color: _isNightMode ? const Color(0xFFFFD700) : Colors.white,
              ),
              tooltip: 'الوضع الليلي',
              onPressed: () {
                setState(() {
                  _isNightMode = !_isNightMode;
                  if (_isNightMode) _isEyeProtection = false;
                });
              },
            ),
          ],
        ),
        body: SafeArea(
          child: _versesMap == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: widget.versesCount + 1, // +1 من أجل بطاقة البسملة في البداية
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // عرض بطاقة البسملة المخصصة والمحاطة بإطار ذهبي أنيق
                      return Container(
                        key: _verseKeys[0],
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 22),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5C158), width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                          color: cardColor,
                        ),
                        child: Text(
                          _versesMap?['verse_0'] ?? "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ahmed',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      );
                    }

                    // جلب نص الآية الفعلي من ملف البيانات الخاص بك
                    final String verseText = _versesMap?['verse_$index'] ?? '';

                    return Container(
                      key: _verseKeys[index], // المفتاح السحري لتحديد السطر ومتابعة الأجزاء بدقة
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: textColor.withOpacity(0.05), width: 0.5)
                        ),
                      ),
                      child: Text(
                        verseText,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontFamily: 'ahmed',
                          fontSize: 23, // خط كبير وواضح جداً لقراءة مريحة للمصحف
                          color: textColor,
                          height: 1.8,
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
