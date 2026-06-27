import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final int initialJuz;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.initialJuz,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  List<String> verses = [];
  List<dynamic> juzData = [];
  bool isLoading = true;
  int currentJuz = 1;
  
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 0.1; 

  double _fontSize = 24.0;
  int _themeMode = 0; 

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.position.pixels;
          
          if (currentScroll >= maxScroll) {
            timer.cancel();
            setState(() => _isAutoScrolling = false);
          } else {
            _scrollController.jumpTo(currentScroll + (_scrollSpeed * 5));
          }
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  Future<void> _loadData() async {
    try {
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final data = json.decode(response);
      final Map<String, dynamic> verseMap = data['verse'];
      
      List<String> loadedVerses = [];
      for (int i = 0; i < verseMap.length; i++) {
        if (verseMap.containsKey('verse_$i')) {
          String text = verseMap['verse_$i'].toString().trim();
          
          // تصفية وحذف البسملة النصية الافتراضية من الآية الأولى لجميع السور عدا الفاتحة
          if (widget.surahId != 1 && i == 0) {
            // تعبير نمطي مرن يتجاهل التشكيل والحركات تماماً لضمان حذف نص البسملة بشكل صحيح
            final RegExp basmalahRegExp = RegExp(
              r'^بِ_?سْ_?مِ_?\s+اللَّ_?هِ_?\s+الرَّ_?حْ_?مَٰ_?نِ_?\s+الرَّ_?حِ_?يمِ_?\s*',
              caseSensitive: false,
            );
            
            // محاولة أولى بالحركات البديلة ومحاولة ثانية للنص الخام المقارن
            if (text.contains("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ")) {
              text = text.replaceFirst("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ", "").trim();
            } else if (text.contains("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")) {
              text = text.replaceFirst("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", "").trim();
            } else {
              text = text.replaceFirst(basmalahRegExp, "").trim();
            }
          }
          loadedVerses.add(text);
        }
      }

      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        verses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
        isLoading = false;
      });
    }
  }

  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFFBF7EE);
    if (_themeMode == 2) return const Color(0xFF121212);
    return Colors.white;
  }

  Color _getTextColor() {
    if (_themeMode == 2) return Colors.white;
    return const Color(0xFF2C3E50);
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _themeMode == 2;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 10),
                    Text("حجم خط القراءة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    Slider(
                      value: _fontSize, min: 20, max: 40, divisions: 10,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        setModalState(() => _fontSize = v);
                      },
                    ),
                    const Divider(),
                    Text("وضع العرض والوضوح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(label: const Text("فاتح"), selected: _themeMode == 0, onSelected: (s) { setState(() => _themeMode = 0); setModalState(() {}); }),
                        ChoiceChip(label: const Text("دافئ"), selected: _themeMode == 1, onSelected: (s) { setState(() => _themeMode = 1); setModalState(() {}); }),
                        ChoiceChip(label: const Text("ليلي"), selected: _themeMode == 2, onSelected: (s) { setState(() => _themeMode = 2); setModalState(() {}); }),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("التمرير الآلي ذكي (أثناء القراءة):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _isAutoScrolling ? Colors.red : const Color(0xFF2E7D32)),
                          onPressed: () {
                            _toggleAutoScroll();
                            setModalState(() {});
                          },
                          icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          label: Text(_isAutoScrolling ? "إيقاف" : "تشغيل", style: const TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                    Slider(
                      value: _scrollSpeed, min: 0.1, max: 1.0, divisions: 9,
                      activeColor: Colors.orange,
                      label: "السرعة: $_scrollSpeed",
                      onChanged: (v) {
                        setModalState(() => _scrollSpeed = v);
                        setState(() => _scrollSpeed = v);
                        if (_isAutoScrolling) {
                          _scrollTimer?.cancel();
                          _isAutoScrolling = false;
                          _toggleAutoScroll();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFFFD700).withOpacity(0.4), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.surahId == 2 ? 'البَقَرَةِ' : widget.surahName,
                      style: const TextStyle(fontFamily: 'nam', fontSize: 24, color: Color(0xFFFFFFD700), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "آياتها: ${widget.versesCount}", 
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$currentJuz", 
                    style: const TextStyle(fontFamily: 'jzu12', fontSize: 24, color: Color(0xFFFFFFD700), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    onPressed: _showSettingsBottomSheet,
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
            ),
          ),
          elevation: 2,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    // عرض مخطوطة البسملة المصممة الكبيرة لجميع السور عدا الفاتحة
                    if (widget.surahId != 1) ...[
                      const Center(
                        child: Text(
                          "19", 
                          style: TextStyle(fontFamily: 'bsm60', fontSize: 85, color: Color(0xFF2E7D32)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: RichText(
                        textAlign: TextAlign.justify,
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          children: List.generate(verses.length, (index) {
                            return TextSpan(
                              children: [
                                TextSpan(
                                  text: "${verses[index]} ",
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    fontFamily: 'nss', 
                                    height: 1.9,
                                    color: _getTextColor(),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: " ${index + 1} ", 
                                  style: const TextStyle(fontFamily: 'quran_num', fontSize: 22, color: Color(0xFFC19A6B)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
