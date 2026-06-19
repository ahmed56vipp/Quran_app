import 'dart:convert';
import 'dart:async';
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
  // أوضاع الرؤية وحماية العين
  bool _isNightMode = false;
  bool _isEyeProtection = false;
  
  // بيانات الآيات والأجزاء
  Map<String, dynamic>? _versesMap;
  List<dynamic> _surahJuzRanges = [];
  
  // التحكم في التمرير وتتبع الآيات
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _verseKeys = [];
  int _currentVisibleVerse = 1;

  // خيارات التحكم بحجم الخط والسرعة
  double _currentFontSize = 24.0; 
  bool _isAutoScrolling = false;  
  double _scrollSpeed = 2.0;      
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _verseKeys.addAll(List.generate(widget.versesCount + 1, (index) => GlobalKey()));
    _loadSurahVerses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  // تم تصحيح المسار هنا إلى quran_full.json ليعمل جلب السور بنجاح
  Future<void> _loadSurahVerses() async {
    try {
      final String response = await rootBundle.loadString('assets/data/quran_full.json');
      final List<dynamic> data = json.decode(response);
      
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

  void _onScroll() {
    if (_verseKeys.isEmpty || !mounted) return;
    double appBarHeight = Scaffold.of(context).appBarMaxHeight ?? 100.0;
    int detectedVerse = _currentVisibleVerse;

    for (int i = 1; i <= widget.versesCount; i++) {
      if (i >= _verseKeys.length) break;
      final contextKey = _verseKeys[i].currentContext;
      if (contextKey != null && contextKey.mounted) {
        final box = contextKey.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final positionY = box.localToGlobal(Offset.zero).dy;
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

  void _toggleAutoScroll(bool start) {
    _autoScrollTimer?.cancel();
    setState(() {
      _isAutoScrolling = start;
    });

    if (start) {
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.position.pixels;
          
          if (currentScroll < maxScroll) {
            _scrollController.jumpTo(currentScroll + (_scrollSpeed * 0.3));
          } else {
            _toggleAutoScroll(false);
          }
        }
      });
    }
  }

  void _showGoToVerseDialog() {
    final TextEditingController textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "الذهاب إلى آية",
            style: TextStyle(fontFamily: 'ahmed', fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "أدخل رقم الآية من (1 إلى ${widget.versesCount}):",
                style: const TextStyle(fontFamily: 'ahmed', fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  hintText: "مثال: 7",
                  prefixIcon: const Icon(Icons.pin_drop, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'ahmed', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final int? targetVerse = int.tryParse(textController.text);
                if (targetVerse != null && targetVerse > 0 && targetVerse <= widget.versesCount) {
                  Navigator.pop(context);
                  final targetContext = _verseKeys[targetVerse].currentContext;
                  if (targetContext != null) {
                    Scrollable.ensureVisible(
                      targetContext,
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text(
                        "خطأ: نطاق الآيات بين 1 و ${widget.versesCount}",
                        style: const TextStyle(fontFamily: 'ahmed'),
                      ),
                    ),
                  );
                }
              },
              child: const Text("انتقال", style: TextStyle(fontFamily: 'ahmed', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Color sheetBg = _isNightMode ? const Color(0xFF1E1E1E) : (_isEyeProtection ? const Color(0xFFEFE5CD) : Colors.white);
            Color textCol = _isNightMode ? Colors.white : (_isEyeProtection ? const Color(0xFF3E2723) : const Color(0xFF1A1A1A));
            
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                color: sheetBg,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "خيارات القراءة والتحكم",
                      style: TextStyle(fontFamily: 'ahmed', fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("حجم خط الآيات الكريمة:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 16)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: textCol, size: 28),
                              onPressed: () {
                                if (_currentFontSize > 18) {
                                  setState(() => _currentFontSize -= 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                            Text("${_currentFontSize.toInt()}", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: textCol, size: 28),
                              onPressed: () {
                                if (_currentFontSize < 42) {
                                  setState(() => _currentFontSize += 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("تشغيل التمرير التلقائي:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 16)),
                        Switch(
                          value: _isAutoScrolling,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: (value) {
                            setModalState(() {
                              _toggleAutoScroll(value);
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isAutoScrolling) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text("سرعة التمرير:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: _scrollSpeed,
                              min: 0.5,
                              max: 5.0,
                              divisions: 9,
                              activeColor: const Color(0xFF2E7D32),
                              label: "سرعة: $_scrollSpeed",
                              onChanged: (value) {
                                setState(() {
                                  _scrollSpeed = value;
                                });
                                setModalState(() {
                                  _toggleAutoScroll(true); 
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getDynamicJuzNumber() {
    if (_surahJuzRanges.isEmpty) return _getFallbackJuz();

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
    Color backgroundColor = Colors.white;
    Color textColor = const Color(0xFF1A1A1A);
    Color cardColor = const Color(0xFFFAFAFA);

    if (_isNightMode) {
      backgroundColor = const Color(0xFF121212);
      textColor = const Color(0xFFE0E0E0);
      cardColor = const Color(0xFF1E1E1E);
    } else if (_isEyeProtection) {
      backgroundColor = const Color(0xFFF4ECD8);
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
          // زر العودة يقع جهة اليمين في وضع الـ RTL تلقائياً
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          // منصة العنوان مخصصة فقط لبيانات السورة والجزء بشكل نظيف وواسع
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.surahName,
                style: const TextStyle(
                  fontFamily: 'ahmed',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "جزء: $currentJuz | آياتها: ${widget.versesCount} (${widget.surahType})",
                style: const TextStyle(
                  fontFamily: 'ahmed',
                  fontSize: 13,
                  color: Colors.whiteBD,
                ),
              ),
            ],
          ),
          // كافة الإضافات والتحكم مجمعة هنا لتظهر بتبويب جهة اليسار كاملة
          actions: [
            IconButton(
              icon: const Icon(Icons.pin_drop_outlined),
              tooltip: 'الذهاب إلى آية',
              onPressed: _showGoToVerseDialog,
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'خيارات الخط والتمرير',
              onPressed: _showSettingsBottomSheet,
            ),
            IconButton(
              icon: Icon(_isEyeProtection ? Icons.visibility : Icons.visibility_outlined),
              color: _isEyeProtection ? const Color(0xFFFFD700) : Colors.white,
              tooltip: 'حماية العين',
              onPressed: () {
                setState(() {
                  _isEyeProtection = !_isEyeProtection;
                  if (_isEyeProtection) _isNightMode = false;
                });
              },
            ),
            IconButton(
              icon: Icon(_isNightMode ? Icons.dark_mode : Icons.dark_mode_outlined),
              color: _isNightMode ? const Color(0xFFFFD700) : Colors.white,
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
                  itemCount: widget.versesCount + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
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

                    final String verseText = _versesMap?['verse_$index'] ?? '';

                    return Container(
                      key: _verseKeys[index],
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
                          fontSize: _currentFontSize,
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
