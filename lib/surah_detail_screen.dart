import 'dart:convert';
import 'dart:async';
import 'dart:ui'; // تم استيراده لدعم الشفافية والتضبيب الذكي للواجهة
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- دالة مساعدة لتحويل الأرقام إلى صيغتها العربية للمصحف ---
String _toArabicNumbers(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], arabic[i]);
  }
  return input;
}

// ==========================================
// 1. الشاشة الرئيسية وإدارة الحالة (Controller)
// ==========================================
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
  int _currentVisibleVerse = 1;

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

  Future<void> _loadSurahVerses() async {
    try {
      final String responseMeta = await rootBundle.loadString('assets/data/quran_full.json');
      final List<dynamic> dataMeta = json.decode(responseMeta);
      
      final surahData = dataMeta.firstWhere(
        (element) => int.tryParse(element['index'].toString()) == widget.surahId,
        orElse: () => null,
      );

      if (surahData != null) {
        setState(() {
          _surahJuzRanges = surahData['juz'] as List<dynamic>? ?? [];
        });
      }

      String surahTextResponse = '';
      try {
        surahTextResponse = await rootBundle.loadString('assets/surah/${widget.surahId}.json');
      } catch (_) {
        surahTextResponse = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      }

      final dynamic parsedText = json.decode(surahTextResponse);
      Map<String, dynamic> localVersesMap = {};

      if (parsedText is Map) {
        Map<String, dynamic> targetMap = parsedText.containsKey('verse') && parsedText['verse'] is Map
            ? parsedText['verse'] as Map<String, dynamic>
            : parsedText as Map<String, dynamic>;

        targetMap.forEach((key, value) {
          String cleanKey = key.toString();
          if (!cleanKey.startsWith('verse_') && cleanKey != '0') {
            localVersesMap['verse_$cleanKey'] = _cleanRawText(value.toString());
          } else {
            localVersesMap[cleanKey] = _cleanRawText(value.toString());
          }
          localVersesMap[cleanKey.replaceAll('verse_', '')] = _cleanRawText(value.toString());
        });
      } else if (parsedText is List) {
        for (int i = 0; i < parsedText.length; i++) {
          int indexKey = parsedText.length == widget.versesCount ? i + 1 : i;
          localVersesMap['verse_$indexKey'] = _cleanRawText(parsedText[i].toString());
          localVersesMap['$indexKey'] = _cleanRawText(parsedText[i].toString());
        }
      }

      setState(() {
        _versesMap = localVersesMap;
      });
    } catch (e) {
      debugPrint("خطأ في جلب البيانات: $e");
      setState(() {
        _versesMap = {'verse_0': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'};
      });
    }
  }

  String _cleanRawText(String text) {
    return text
        .replaceAll('●', '') 
        .replaceAll('•', '') 
        .replaceAll('۝', '') 
        .replaceAll('\u06DD', '')
        .trim();
  }

  void _onScroll() {
    if (_verseKeys.isEmpty || !mounted) return;
    double appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
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
    setState(() => _isAutoScrolling = start);

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

  void _jumpToVerseAction(int targetVerse) {
    final targetContext = _verseKeys[targetVerse].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(targetContext, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
    } else {
      double maxScroll = _scrollController.position.maxScrollExtent;
      double estimatedOffset = (targetVerse / widget.versesCount) * maxScroll;
      _scrollController.animateTo(estimatedOffset, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
    }
  }

  String _getDynamicJuzNumber() {
    if (_surahJuzRanges.isEmpty) return _getFallbackJuz();
    for (var juz in _surahJuzRanges) {
      if (juz['verse'] != null && juz['verse']['start'] != null && juz['verse']['end'] != null) {
        int start = int.tryParse(juz['verse']['start'].toString().replaceAll('verse_', '')) ?? 1;
        int end = int.tryParse(juz['verse']['end'].toString().replaceAll('verse_', '')) ?? widget.versesCount;
        if (_currentVisibleVerse >= start && _currentVisibleVerse <= end) {
          return juz['index'].toString();
        }
      }
    }
    return _surahJuzRanges.first['index']?.toString() ?? _getFallbackJuz();
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 2,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.surahName, style: const TextStyle(fontFamily: 'ahmed', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
              const SizedBox(height: 2),
              Text("جزء: ${_getDynamicJuzNumber()} | آياتها: ${widget.versesCount} (${widget.surahType})", style: TextStyle(fontFamily: 'ahmed', fontSize: 13, color: Colors.white.withOpacity(0.70))),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent, // جعل خلفية المودال الأساسية شفافة ليعمل التضبيب الخلفي بشكل صحيح
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (context) => UnifiedSettingsBottomSheet(
                  versesCount: widget.versesCount,
                  currentFontSize: _currentFontSize,
                  isNightMode: _isNightMode,
                  isEyeProtection: _isEyeProtection,
                  isAutoScrolling: _isAutoScrolling,
                  scrollSpeed: _scrollSpeed,
                  onFontSizeChanged: (size) => setState(() => _currentFontSize = size),
                  onNightModeChanged: (val) => setState(() { _isNightMode = val; if (val) _isEyeProtection = false; }),
                  onEyeProtectionChanged: (val) => setState(() { _isEyeProtection = val; if (val) _isNightMode = false; }),
                  onAutoScrollToggle: _toggleAutoScroll,
                  onSpeedChanged: (speed) => setState(() => _scrollSpeed = speed),
                  onJumpToVerse: _jumpToVerseAction,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: _versesMap == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      _BuildBasmalahHeader(versesMap: _versesMap, cardColor: cardColor, textColor: textColor, verseKey: _verseKeys[0]),
                      const SizedBox(height: 10),
                      MushafTextView(
                        versesCount: widget.versesCount,
                        versesMap: _versesMap!,
                        verseKeys: _verseKeys,
                        fontSize: _currentFontSize,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. ويدجت صندوق البسملة المنفصل المعزول
// ==========================================
class _BuildBasmalahHeader extends StatelessWidget {
  final Map<String, dynamic>? versesMap;
  final Color cardColor;
  final Color textColor;
  final GlobalKey verseKey;

  const _BuildBasmalahHeader({
    required this.versesMap,
    required this.cardColor,
    required this.textColor,
    required this.verseKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: verseKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5C158), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: cardColor,
      ),
      child: Text(
        versesMap?['verse_0'] ?? versesMap?['0'] ?? "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'ahmed', fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}

// ==========================================
// 3. ويدجت عرض السورة المتدفقة (المصحف النظيف تماماً)
// ==========================================
class MushafTextView extends StatelessWidget {
  final int versesCount;
  final Map<String, dynamic> versesMap;
  final List<GlobalKey> verseKeys;
  final double fontSize;
  final Color textColor;

  const MushafTextView({
    super.key,
    required this.versesCount,
    required this.versesMap,
    required this.verseKeys,
    required this.fontSize,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    List<InlineSpan> spans = [];

    for (int i = 1; i <= versesCount; i++) {
      final String verseText = versesMap['verse_$i'] ?? versesMap['$i'] ?? '';
      if (verseText.isEmpty) continue;

      spans.add(
        WidgetSpan(
          child: SizedBox(key: verseKeys[i], width: 0, height: 0),
        ),
      );

      spans.add(
        TextSpan(
          text: "$verseText ",
          style: TextStyle(
            fontFamily: 'ahmed',
            fontSize: fontSize,
            color: textColor,
            height: 2.1,
          ),
        ),
      );

      String arabicNum = _toArabicNumbers(i.toString());
      spans.add(
        TextSpan(
          text: "$arabicNum ",
          style: TextStyle(
            fontFamily: 'ahmed',
            fontSize: fontSize * 0.9,
            color: const Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }
}

// ==========================================
// 4. لوحة الإضافات الشفافة والمصلحة (Unified Settings)
// ==========================================
class UnifiedSettingsBottomSheet extends StatefulWidget {
  final int versesCount;
  final double currentFontSize;
  final bool isNightMode;
  final bool isEyeProtection;
  final bool isAutoScrolling;
  final double scrollSpeed;
  
  final Function(double) onFontSizeChanged;
  final Function(bool) onNightModeChanged;
  final Function(bool) onEyeProtectionChanged;
  final Function(bool) onAutoScrollToggle;
  final Function(double) onSpeedChanged;
  final Function(int) onJumpToVerse;

  const UnifiedSettingsBottomSheet({
    super.key,
    required this.versesCount,
    required this.currentFontSize,
    required this.isNightMode,
    required this.isEyeProtection,
    required this.isAutoScrolling,
    required this.scrollSpeed,
    required this.onFontSizeChanged,
    required this.onNightModeChanged,
    required this.onEyeProtectionChanged,
    required this.onAutoScrollToggle,
    required this.onSpeedChanged,
    required this.onJumpToVerse,
  });

  @override
  State<UnifiedSettingsBottomSheet> createState() => _UnifiedSettingsBottomSheetState();
}

class _UnifiedSettingsBottomSheetState extends State<UnifiedSettingsBottomSheet> {
  late double _localFontSize;
  late bool _localNightMode;
  late bool _localEyeProtection;
  late bool _localAutoScrolling;
  late double _localScrollSpeed;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localFontSize = widget.currentFontSize;
    _localNightMode = widget.isNightMode;
    _localEyeProtection = widget.isEyeProtection;
    _localAutoScrolling = widget.isAutoScrolling;
    _localScrollSpeed = widget.scrollSpeed;
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ تم إدخال التعديل هنا: استخدام درجة ألفا الشفافة (withOpacity) لبناء مظهر زجاجي عصري ومريح للعين
    Color sheetBg = _localNightMode 
        ? const Color(0xFF1E1E1E).withOpacity(0.82) 
        : (_localEyeProtection ? const Color(0xFFEFE5CD).withOpacity(0.85) : Colors.white.withOpacity(0.82));
        
    Color textCol = _localNightMode ? Colors.white : (_localEyeProtection ? const Color(0xFF3E2723) : const Color(0xFF1A1A1A));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          // تضبيب فائق الجودة لخلفية المصحف الورقي عند فتح التبويب
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: sheetBg,
            padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: textCol.withOpacity(0.2), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                // 🛠️ تم تحديث المسمى هنا إلى "اضافات القرآن" بناءً على طلبك
                Center(child: Text("اضافات القرآن", style: TextStyle(fontFamily: 'ahmed', fontSize: 18, fontWeight: FontWeight.bold, color: textCol))),
                const Divider(height: 25),
                
                Text("انتقال سريع لآية:", style: TextStyle(fontFamily: 'ahmed', fontWeight: FontWeight.bold, color: textCol, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textCol, fontFamily: 'ahmed'),
                        decoration: InputDecoration(
                          hintText: "من 1 إلى ${widget.versesCount}",
                          hintStyle: TextStyle(color: textCol.withOpacity(0.5), fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                      onPressed: () {
                        final int? target = int.tryParse(_inputController.text);
                        if (target != null && target > 0 && target <= widget.versesCount) {
                          Navigator.pop(context);
                          widget.onJumpToVerse(target);
                        }
                      },
                      child: const Text("ذهاب", style: TextStyle(fontFamily: 'ahmed', color: Colors.white)),
                    )
                  ],
                ),
                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("الوضع الليلي", style: TextStyle(fontFamily: 'ahmed', color: textCol)),
                    Switch(
                      value: _localNightMode,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        setState(() { _localNightMode = val; if (val) _localEyeProtection = false; });
                        widget.onNightModeChanged(val);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("وضع حماية العين (الدافئ)", style: TextStyle(fontFamily: 'ahmed', color: textCol)),
                    Switch(
                      value: _localEyeProtection,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        setState(() { _localEyeProtection = val; if (val) _localNightMode = false; });
                        widget.onEyeProtectionChanged(val);
                      },
                    ),
                  ],
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("حجم خط الآيات الكريمة:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(icon: Icon(Icons.remove_circle_outline, color: textCol), onPressed: () { if (_localFontSize > 18) { setState(() => _localFontSize -= 2); widget.onFontSizeChanged(_localFontSize); } }),
                        Text("${_localFontSize.toInt()}", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: Icon(Icons.add_circle_outline, color: textCol), onPressed: () { if (_localFontSize < 42) { setState(() => _localFontSize += 2); widget.onFontSizeChanged(_localFontSize); } }),
                      ],
                    )
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("تشغيل التمرير التلقائي للأعلى:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _localAutoScrolling,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (value) {
                        setState(() => _localAutoScrolling = value);
                        widget.onAutoScrollToggle(value);
                      },
                    ),
                  ],
                ),
                if (_localAutoScrolling) ...[
                  Row(
                    children: [
                      Text("سرعة التدفق:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _localScrollSpeed,
                          min: 0.5,
                          max: 5.0,
                          divisions: 9,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: (value) {
                            setState(() => _localScrollSpeed = value);
                            widget.onSpeedChanged(value);
                            widget.onAutoScrollToggle(true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
