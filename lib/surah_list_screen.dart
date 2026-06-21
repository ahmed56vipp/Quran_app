import 'package:flutter/material.dart';
import 'surah_detail_screen.dart'; // استيراد شاشة تفاصيل السورة

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  // قائمة السور المطابقة لواجهة التطبيق
  final List<Map<String, dynamic>> surahList = const [
    {
      "id": 1,
      "name": "الفاتحة",
      "type": "مكية",
      "verses": 7,
      "juz": "الجزء 1",
      "isMeccan": true
    },
    {
      "id": 2,
      "name": "البقرة",
      "type": "مدنية",
      "verses": 286,
      "juz": "الجزء 1-2-3",
      "isMeccan": false
    },
    {
      "id": 3,
      "name": "آل عمران",
      "type": "مدنية",
      "verses": 200,
      "juz": "الجزء 3-4",
      "isMeccan": false
    },
    {
      "id": 4,
      "name": "النساء",
      "type": "مدنية",
      "verses": 176,
      "juz": "الجزء 4-5-6",
      "isMeccan": false
    },
    {
      "id": 5,
      "name": "المائدة",
      "type": "مدنية",
      "verses": 120,
      "juz": "الجزء 6-7",
      "isMeccan": false
    },
    {
      "id": 6,
      "name": "الأنعام",
      "type": "مكية",
      "verses": 165,
      "juz": "الجزء 7-8",
      "isMeccan": true
    },
    {
      "id": 7,
      "name": "الأعراف",
      "type": "مكية",
      "verses": 206,
      "juz": "الجزء 8-9",
      "isMeccan": true
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F6), // خلفية بيج فاتحة جداً مريحة للعين
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32), // اللون الأخضر الإسلامي المعتمد
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "فهرس القرآن الكريم",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: surahList.length,
          itemBuilder: (context, index) {
            final surah = surahList[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12.withOpacity(0.05), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () {
                  // الانتقال بسلاسة إلى شاشة تفاصيل السورة عند الضغط
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
                // اليمين: الأيقونة الزخرفية (كعبة للمكي / مسجد للمدني)
                trailing: Image.asset(
                  surah['isMeccan'] 
                      ? 'assets/images/kaaba.png'  
                      : 'assets/images/mosque.png', 
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                ),
                // المنتصف: اسم السورة بخط fhrs كما حددت تماماً
                title: Text(
                  surah['name'],
                  style: const TextStyle(
                    fontFamily: 'fhrs', // الخط مطبق هنا فقط للفهرس
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  child: Text("${surah['type']} | عدد آيات السورة: ${surah['verses']}"),
                ),
                // اليسار: السهم الرمادي وكبسولة الجزء الخضراء
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), 
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        surah['juz'],
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
