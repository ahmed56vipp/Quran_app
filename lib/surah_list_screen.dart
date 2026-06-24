import 'package:flutter/material.dart';
import 'surah_detail_screen.dart'; 
import 'utils.dart'; // ✅ استيراد ملف الأدوات لاستعمال تحويل الأرقام

const String kSurahNameFont = 'nam';

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  final List<Map<String, dynamic>> surahList = const [
    {"id": 1, "name": "الفاتحة", "type": "مكية", "verses": 7, "isMeccan": true},
    {"id": 2, "name": "البقرة", "type": "مدنية", "verses": 286, "isMeccan": false},
    {"id": 3, "name": "آل عمران", "type": "مدنية", "verses": 200, "isMeccan": false},
    {"id": 4, "name": "النساء", "type": "مدنية", "verses": 176, "isMeccan": false},
    {"id": 5, "name": "المائدة", "type": "مدنية", "verses": 120, "isMeccan": false},
    {"id": 6, "name": "الأنعام", "type": "مكية", "verses": 165, "isMeccan": true},
    {"id": 7, "name": "الأعراف", "type": "مكية", "verses": 206, "isMeccan": true},
    {"id": 8, "name": "الأنفال", "type": "مدنية", "verses": 75, "isMeccan": false},
    {"id": 9, "name": "التوبة", "type": "مدنية", "verses": 129, "isMeccan": false},
    {"id": 10, "name": "يونس", "type": "مكية", "verses": 109, "isMeccan": true},
    {"id": 11, "name": "هود", "type": "مكية", "verses": 123, "isMeccan": true},
    {"id": 12, "name": "يوسف", "type": "مكية", "verses": 111, "isMeccan": true},
    {"id": 13, "name": "الرعد", "type": "مدنية", "verses": 43, "isMeccan": false},
    {"id": 14, "name": "إبراهيم", "type": "مكية", "verses": 52, "isMeccan": true},
    {"id": 15, "name": "الحجر", "type": "مكية", "verses": 99, "isMeccan": true},
    {"id": 16, "name": "النحل", "type": "مكية", "verses": 128, "isMeccan": true},
    {"id": 17, "name": "الإسراء", "type": "مكية", "verses": 111, "isMeccan": true},
    {"id": 18, "name": "الكهف", "type": "مكية", "verses": 110, "isMeccan": true},
    {"id": 19, "name": "مريم", "type": "مكية", "verses": 98, "isMeccan": true},
    {"id": 20, "name": "طه", "type": "مكية", "verses": 135, "isMeccan": true},
    {"id": 21, "name": "الأنبياء", "type": "مكية", "verses": 112, "isMeccan": true},
    {"id": 22, "name": "الحج", "type": "مدنية", "verses": 78, "isMeccan": false},
    {"id": 23, "name": "المؤمنون", "type": "مكية", "verses": 118, "isMeccan": true},
    {"id": 24, "name": "النور", "type": "مدنية", "verses": 64, "isMeccan": false},
    {"id": 25, "name": "الفرقان", "type": "مكية", "verses": 77, "isMeccan": true},
    {"id": 26, "name": "الشعراء", "type": "مكية", "verses": 227, "isMeccan": true},
    {"id": 27, "name": "النمل", "type": "مكية", "verses": 93, "isMeccan": true},
    {"id": 28, "name": "القصص", "type": "مكية", "verses": 88, "isMeccan": true},
    {"id": 29, "name": "العنكبوت", "type": "مكية", "verses": 69, "isMeccan": true},
    {"id": 30, "name": "الروم", "type": "مكية", "verses": 60, "isMeccan": true},
    {"id": 31, "name": "لقمان", "type": "مكية", "verses": 34, "isMeccan": true},
    {"id": 32, "name": "السجدة", "type": "مكية", "verses": 30, "isMeccan": true},
    {"id": 33, "name": "الأحزاب", "type": "مدنية", "verses": 73, "isMeccan": false},
    {"id": 34, "name": "سبأ", "type": "مكية", "verses": 54, "isMeccan": true},
    {"id": 35, "name": "فاطر", "type": "مكية", "verses": 45, "isMeccan": true},
    {"id": 36, "name": "يس", "type": "مكية", "verses": 83, "isMeccan": true},
    {"id": 37, "name": "الصافات", "type": "مكية", "verses": 182, "isMeccan": true},
    {"id": 38, "name": "ص", "type": "مكية", "verses": 88, "isMeccan": true},
    {"id": 39, "name": "الزمر", "type": "مكية", "verses": 75, "isMeccan": true},
    {"id": 40, "name": "غافر", "type": "مكية", "verses": 85, "isMeccan": true},
    {"id": 41, "name": "فصلت", "type": "مكية", "verses": 54, "isMeccan": true},
    {"id": 42, "name": "الشورى", "type": "مكية", "verses": 53, "isMeccan": true},
    {"id": 43, "name": "الزخرف", "type": "مكية", "verses": 89, "isMeccan": true},
    {"id": 44, "name": "الدخان", "type": "مكية", "verses": 59, "isMeccan": true},
    {"id": 45, "name": "الجاثية", "type": "مكية", "verses": 37, "isMeccan": true},
    {"id": 46, "name": "الأحقاف", "type": "مكية", "verses": 35, "isMeccan": true},
    {"id": 47, "name": "محمد", "type": "مدنية", "verses": 38, "isMeccan": false},
    {"id": 48, "name": "الفتح", "type": "مدنية", "verses": 29, "isMeccan": false},
    {"id": 49, "name": "الحجرات", "type": "مدنية", "verses": 18, "isMeccan": false},
    {"id": 50, "name": "ق", "type": "مكية", "verses": 45, "isMeccan": true},
    {"id": 51, "name": "الذاريات", "type": "مكية", "verses": 60, "isMeccan": true},
    {"id": 52, "name": "الطور", "type": "مكية", "verses": 49, "isMeccan": true},
    {"id": 53, "name": "النجم", "type": "مكية", "verses": 62, "isMeccan": true},
    {"id": 54, "name": "القمر", "type": "مكية", "verses": 55, "isMeccan": true},
    {"id": 55, "name": "الرحمن", "type": "مدنية", "verses": 78, "isMeccan": false},
    {"id": 56, "name": "الواقعة", "type": "مكية", "verses": 96, "isMeccan": true},
    {"id": 57, "name": "الحديد", "type": "مدنية", "verses": 29, "isMeccan": false},
    {"id": 58, "name": "المجادلة", "type": "مدنية", "verses": 22, "isMeccan": false},
    {"id": 59, "name": "الحشر", "type": "مدنية", "verses": 24, "isMeccan": false},
    {"id": 60, "name": "الممتحنة", "type": "مدنية", "verses": 13, "isMeccan": false},
    {"id": 61, "name": "الصف", "type": "مدنية", "verses": 14, "isMeccan": false},
    {"id": 62, "name": "الجمعة", "type": "مدنية", "verses": 11, "isMeccan": false},
    {"id": 63, "name": "المنافقون", "type": "مدنية", "verses": 11, "isMeccan": false},
    {"id": 64, "name": "التغابن", "type": "مدنية", "verses": 18, "isMeccan": false},
    {"id": 65, "name": "الطلاق", "type": "مدنية", "verses": 12, "isMeccan": false},
    {"id": 66, "name": "التحريم", "type": "مدنية", "verses": 12, "isMeccan": false},
    {"id": 67, "name": "الملك", "type": "مكية", "verses": 30, "isMeccan": true},
    {"id": 68, "name": "القلم", "type": "مكية", "verses": 52, "isMeccan": true},
    {"id": 69, "name": "الحاقة", "type": "مكية", "verses": 52, "isMeccan": true},
    {"id": 70, "name": "المعارج", "type": "مكية", "verses": 44, "isMeccan": true},
    {"id": 71, "name": "نوح", "type": "مكية", "verses": 28, "isMeccan": true},
    {"id": 72, "name": "الجن", "type": "مكية", "verses": 28, "isMeccan": true},
    {"id": 73, "name": "المزمل", "type": "مكية", "verses": 20, "isMeccan": true},
    {"id": 74, "name": "المدثر", "type": "مكية", "verses": 56, "isMeccan": true},
    {"id": 75, "name": "القيامة", "type": "مكية", "verses": 40, "isMeccan": true},
    {"id": 76, "name": "الإنسان", "type": "مدنية", "verses": 31, "isMeccan": false},
    {"id": 77, "name": "المرسلات", "type": "مكية", "verses": 50, "isMeccan": true},
    {"id": 78, "name": "النبأ", "type": "مكية", "verses": 40, "isMeccan": true},
    {"id": 79, "name": "النازعات", "type": "مكية", "verses": 46, "isMeccan": true},
    {"id": 80, "name": "عبس", "type": "مكية", "verses": 42, "isMeccan": true},
    {"id": 81, "name": "التكوير", "type": "مكية", "verses": 29, "isMeccan": true},
    {"id": 82, "name": "الانفطار", "type": "مكية", "verses": 19, "isMeccan": true},
    {"id": 83, "name": "المطففين", "type": "مكية", "verses": 36, "isMeccan": true},
    {"id": 84, "name": "الانشقاق", "type": "مكية", "verses": 25, "isMeccan": true},
    {"id": 85, "name": "البروج", "type": "مكية", "verses": 22, "isMeccan": true},
    {"id": 86, "name": "الطارق", "type": "مكية", "verses": 17, "isMeccan": true},
    {"id": 87, "name": "الأعلى", "type": "مكية", "verses": 19, "isMeccan": true},
    {"id": 88, "name": "الغاشية", "type": "مكية", "verses": 26, "isMeccan": true},
    {"id": 89, "name": "الفجر", "type": "مكية", "verses": 30, "isMeccan": true},
    {"id": 90, "name": "البلد", "type": "مكية", "verses": 20, "isMeccan": true},
    {"id": 91, "name": "الشمس", "type": "مكية", "verses": 15, "isMeccan": true},
    {"id": 92, "name": "الليل", "type": "مكية", "verses": 21, "isMeccan": true},
    {"id": 93, "name": "الضحى", "type": "مكية", "verses": 11, "isMeccan": true},
    {"id": 94, "name": "الشرح", "type": "مكية", "verses": 8, "isMeccan": true},
    {"id": 95, "name": "التين", "type": "مكية", "verses": 8, "isMeccan": true},
    {"id": 96, "name": "العلق", "type": "مكية", "verses": 19, "isMeccan": true},
    {"id": 97, "name": "القدر", "type": "مكية", "verses": 5, "isMeccan": true},
    {"id": 98, "name": "البينة", "type": "مدنية", "verses": 8, "isMeccan": false},
    {"id": 99, "name": "الزلزلة", "type": "مدنية", "verses": 8, "isMeccan": false},
    {"id": 100, "name": "العاديات", "type": "مكية", "verses": 11, "isMeccan": true},
    {"id": 101, "name": "القارعة", "type": "مكية", "verses": 11, "isMeccan": true},
    {"id": 102, "name": "التكاثر", "type": "مكية", "verses": 8, "isMeccan": true},
    {"id": 103, "name": "العصر", "type": "مكية", "verses": 3, "isMeccan": true},
    {"id": 104, "name": "الهمزة", "type": "مكية", "verses": 9, "isMeccan": true},
    {"id": 105, "name": "الفيل", "type": "مكية", "verses": 5, "isMeccan": true},
    {"id": 106, "name": "قريش", "type": "مكية", "verses": 4, "isMeccan": true},
    {"id": 107, "name": "الماعون", "type": "مكية", "verses": 7, "isMeccan": true},
    {"id": 108, "name": "الكوثر", "type": "مكية", "verses": 3, "isMeccan": true},
    {"id": 109, "name": "الكافرون", "type": "مكية", "verses": 6, "isMeccan": true},
    {"id": 110, "name": "النصر", "type": "مدنية", "verses": 3, "isMeccan": false},
    {"id": 111, "name": "المسد", "type": "مكية", "verses": 5, "isMeccan": true},
    {"id": 112, "name": "الإخلاص", "type": "مكية", "verses": 4, "isMeccan": true},
    {"id": 113, "name": "الفلق", "type": "مكية", "verses": 5, "isMeccan": true},
    {"id": 114, "name": "الناس", "type": "مكية", "verses": 6, "isMeccan": true}
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.brightness_7_outlined, color: Color(0xFFFFD700), size: 22),
              SizedBox(width: 10),
              Text(
                'القرآن الكريم',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5),
              ),
            ],
          ),
          // تدرج لوني فخم جداً للشريط العلوي ليتوافق مع هوية التطبيق الإسلامية
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.black38,
        ),
        body: ListView.builder(
          itemCount: surahList.length,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemBuilder: (context, index) {
            final surah = surahList[index];
            // تحويل الأرقام الترتيبية وأعداد الآيات ديناميكياً للعربية الفصحى
            final String arabicId = toArabicNumerals(surah['id'] as int);
            final String arabicVerses = toArabicNumerals(surah['verses'] as int);

            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.6), width: 1),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.white, const Color(0xFFF9F9F6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      arabicId,
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  title: Text(
                    "سورة ${surah['name']}", 
                    style: const TextStyle(
                      fontFamily: kSurahNameFont,
                      fontSize: 26,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أيقونة نوع السورة (مكية/مدنية) معالجة بطريقة عصرية
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: surah['isMeccan'] ? const Color(0xFFFFF3E0) : const Color(0xFFE1F5FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                surah['isMeccan'] ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                                height: 16,
                                width: 16,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  surah['type'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: surConditionColor(surah['isMeccan']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                surah['type'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: surConditionColor(surah['isMeccan']),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "• آياتها: $arabicVerses",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left, size: 22, color: Color(0xFF2E7D32)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurahDetailScreen(
                          surahId: surah['id'],
                          surahName: surah['name'],
                          versesCount: surah['verses'],
                          surahType: surah['type'],
                          juzData: const [], 
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color surConditionColor(bool isMeccan) {
    return isMeccan ? const Color(0xFFE65100) : const Color(0xFF01579B);
  }
}
