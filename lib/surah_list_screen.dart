import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils.dart';
import 'surah_detail_screen.dart';

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
  List<dynamic> juzData = [];

  @override
  void initState() {
    super.initState();
    _loadIndexData();
    _loadJuzData();
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

  Future<void> _loadJuzData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/juz.json');
      setState(() {
        juzData = json.decode(response);
      });
    } catch (e) {
      debugPrint("خطأ في تحميل ملف الأجزاء: $e");
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

  String _getJuzForSurah(int surahId) {
    if (juzData.isEmpty) return '';
    List<int> parts = [];
    
    for (var juz in juzData) {
      int startSurah = int.tryParse(juz['start']['index'].toString()) ?? 0;
      int endSurah = int.tryParse(juz['end']['index'].toString()) ?? 0;
      int juzIndex = int.tryParse(juz['index'].toString()) ?? 0;

      if (surahId >= startSurah && surahId <= endSurah) {
        if (!parts.contains(juzIndex)) {
          parts.add(juzIndex);
        }
      }
    }
    
    if (parts.isEmpty) return '';
    if (parts.length == 1) return "الجزء ${toArabicNumerals(parts.first)}";
    return "الأجزاء: ${parts.map((p) => toArabicNumerals(p)).join(' | ')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرس القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'ahmed', color: Colors.white)),
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
                icon: const Icon(Icons.bookmark, color: Colors.white),
                label: Text('العودة إلى آخر موضع قراءة: $_lastSurahName', style: const TextStyle(fontFamily: 'ahmed', fontSize: 16)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surahId: _lastSurahId!,
                        surahName: _lastSurahName!,
                        versesCount: _lastVersesCount ?? 0,
                        surahType: _lastSurahType ?? 'مكية',
                        juzData: juzData,
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
                      
                      final String sJuz = _getJuzForSurah(sId);
                      final bool isMeccan = sType.contains('مكية');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sName,
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'ahmed'),
                                  textAlign: TextAlign.right,
                                ),
                                if (sJuz.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      sJuz,
                                      style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold, fontFamily: 'ahmed'),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              "$sType | آياتها: ${toArabicNumerals(vCount)}",
                              style: TextStyle(color: Colors.grey[600], fontSize: 14, fontFamily: 'ahmed'),
                              textAlign: TextAlign.right,
                            ),
                            leading: SizedBox(
                              width: 38,
                              height: 38,
                              child: Image.asset(
                                isMeccan ? 'assets/icon/mk.png' : 'assets/icon/md.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    backgroundColor: Colors.green[50],
                                    child: Text(
                                      toArabicNumerals(sId),
                                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontFamily: 'ahmed'),
                                    ),
                                  );
                                },
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SurahDetailScreen(
                                    surahId: sId,
                                    surahName: sName,
                                    versesCount: vCount,
                                    surahType: sType,
                                    juzData: juzData,
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
