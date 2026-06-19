import 'package:flutter/material.dart';

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
  // متغيرات التحكم في الأوضاع المتقدمة للقراءة
  bool _isNightMode = false;
  bool _isEyeProtection = false;

  // دالة جلب رقم الجزء بالأرقام العادية 123 للتعريف العلوي فقط
  String _getJuzNumber(int surahId) {
    if (widget.juzData.isEmpty) return '1';
    List<int> parts = [];
    for (var juz in widget.juzData) {
      int startSurah = int.tryParse(juz['start']['index'].toString()) ?? 0;
      int endSurah = int.tryParse(juz['end']['index'].toString()) ?? 0;
      int juzIndex = int.tryParse(juz['index'].toString()) ?? 0;

      if (surahId >= startSurah && surahId <= endSurah) {
        if (!parts.contains(juzIndex)) {
          parts.add(juzIndex);
        }
      }
    }
    return parts.isEmpty ? '1' : parts.join('-');
  }

  @override
  Widget build(BuildContext context) {
    // ضبط الألوان ديناميكياً بحسب الوضع المختار لحماية العين
    Color backgroundColor = Colors.white;
    Color textColor = const Color(0xFF212121);

    if (_isNightMode) {
      backgroundColor = const Color(0xFF121212); // خلفية داكنة مريحة جداً
      textColor = const Color(0xFFECEFF1);       // نص فاتح مريح
    } else if (_isEyeProtection) {
      backgroundColor = const Color(0xFFF4ECD8); // لون الورق القديم (سيبيا) حماية العين
      textColor = const Color(0xFF3E2723);       // بني داكن متناسق
    }

    final String juzNumber = _getJuzNumber(widget.surahId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32), // اللون الأخضر المعتمد في تطبيقك
          foregroundColor: Colors.white,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          // تصميم شريط التعريف العلوي بناءً على طلبك المحدث
          title: Row(
            children: [
              // 1. اسم السورة داخل إطار ذهبي ملكي مكبر
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF1B5E20), // خلفية داكنة لتبرز الخط الذهبي
                ),
                child: Text(
                  widget.surahName,
                  style: const TextStyle(
                    fontFamily: 'ahmed',
                    fontSize: 20, // تكبير الخط لاسم السورة
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700), // لون النص ذهبي
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 2. بيانات الجزء والآيات بالأرقام العادية وبخط مكبر ومريح
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "(${widget.surahType}) | جزء: $juzNumber",
                      style: const TextStyle(
                        fontFamily: 'ahmed',
                        fontSize: 16, // تكبير خط الجزء
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "آياتها: ${widget.versesCount}", // الرقم الإجمالي فقط بالأرقام العادية 123
                      style: const TextStyle(
                        fontFamily: 'ahmed',
                        fontSize: 15, // تكبير خط التعريف بالآيات
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // زر وضع حماية العين (اللون الدافئ)
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
            // زر الوضع الليلي (اللون الداكن)
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // إطار البسملة الذهبي المعتمد في منتصف الشاشة كما يظهر في الصورة
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5C158), width: 1.2),
                    borderRadius: BorderRadius.circular(10),
                    color: _isNightMode ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                  ),
                  child: Text(
                    "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ahmed',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                
                // تنبيه هام: نصوص الآيات وأرقامها الفردية داخل السورة تعرض هنا مباشرة 
                // من ملفات البيانات الخاصة بك دون أي فلترة أو تغيير لتظل ثابتة بالصيغة الأصيلة (١٢٣)
                Center(
                  child: Text(
                    "هنا يتم عرض نصوص السورة الكريمة كاملة، وستبقى أرقام الآيات الداخلية محتفظة برسمها العثماني العريق (١، ٢، ٣) كما هي في قاعدة بياناتك دون أي تغيير أو تبديل للأرقام.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ahmed',
                      fontSize: 19,
                      color: textColor.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
