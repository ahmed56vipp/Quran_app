import 'dart:convert';
import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =========================================================
// 📥 إعدادات الخطوط والمخطوطات الإسلامية المعتمدة في الـ YAML
// =========================================================
const String kSurahNameFont = 'nam';       
const String kBasmalahFont = 'bsm60';      
const String kSurahTextFont = 'nss';       
const String kNumbersFont = 'quran_num';   
const String kJuzFont = 'jzu12'; // 🌟 إضافة خط الغريب المخصص للأجزاء بناءً على لقطة الشاشة

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
          localVersesMap[cleanKey.replaceAll('verse_', '')] = _cleanRawText(value.toString());
        });
      } else if (parsedText is List) {
        for (int i = 0; i < parsedText.length; i++) {
          int indexKey = parsedText.length == widget.versesCount ? i + 1 : i;
          localVersesMap['$indexKey'] = _cleanRawText(parsedText[i].toString());
        }
      }

      setState(() {
        _versesMap = localVersesMap;
      });
    } catch (e) {
      debugPrint("خطأ في جلب البيانات: $e");
    }
  }

  String _cleanRawText(String text) {
    return text
        .replaceAll('●', '') 
        .replaceAll('•', '') 
        .replaceAll('\u06DF', '') 
        .replaceAll('\u06E0', '') 
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
    for (var juz in widget.juzData) {
      int startSurah = int.tryParse(juz['start']['index'].toString()) ?? 0;
      int endSurah = int.tryParse(juz['end']['index'].toString()) ?? 0;
      if (widget.surahId >= startSurah && widget.surahId <= endSurah) {
        return juz['index'].toString();
      }
    }
    return '1';
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

    String cleanJuzNum = _getDynamicJuzNumber();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 2,
          title: Row(
            children: [
              Text(
                "سورة ${widget.surahName}", 
                style: const TextStyle(
                  fontFamily: kSurahNameFont, 
                  fontSize: 24, 
                  color: Color(0xFFFFD700)
                )
              ),
              const Spacer(),
              
              // 🌟 تعديل كامل هنا لعرض مخطوطة الجزء بخط jzu12 والزخارف التزيينية طبقاً للصورة
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زخرفة تزيينية جانبية (شكل رقم 33)
                  const Text(
                    "33 ", 
                    style: TextStyle(
                      fontFamily: kJuzFont,
                      fontSize: 24,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  // هنا نمرر الرقم الإنجليزي الصافي والخط يحوله تلقائياً إلى "الجزء العاشر" إلخ
                  Text(
                    cleanJuzNum, 
                    style: const TextStyle(
                      fontFamily: kJuzFont, 
                      fontSize: 32, // حجم مناسب لعرض المخطوطة بدقة عالية
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              Text(
                "آياتها: ${widget.versesCount}", 
                style: const TextStyle(fontSize: 12, color: Colors.white70)
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent, 
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
                      if (widget.surahId != 9)
                        _BuildBasmalahHeader(cardColor: cardColor, textColor: textColor, verseKey: _verseKeys[0]),
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

class _BuildBasmalahHeader extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final GlobalKey verseKey;

  const _BuildBasmalahHeader({
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5C158), width: 1.2),
        borderRadius: BorderRadius.circular(12),
        color: cardColor,
      ),
      child: Text(
        "60", 
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kBasmalahFont, 
          fontSize: 55, 
          color: textColor
        ),
      ),
    );
  }
}

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
      String verseText = versesMap['$i'] ?? '';
      if (verseText.isEmpty) continue;

      final RegExp trailingTarget = RegExp(r'[\u06DD۝٠-٩0-9\s]+$');
      verseText = verseText.replaceAll(trailingTarget, '').trim();

      spans.add(
        WidgetSpan(child: SizedBox(key: verseKeys[i], width: 0, height: 0)),
      );

      spans.add(
        TextSpan(
          text: "$verseText ",
          style: TextStyle(
            fontFamily: kSurahTextFont,
            fontSize: fontSize,
            color: textColor,
            height: 2.2,
          ),
        ),
      );

      spans.add(
        TextSpan(
          text: " $i ", 
          style: TextStyle(
            fontFamily: kNumbersFont,
            fontSize: fontSize * 1.05,
            color: const Color(0xFF2E7D32),
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
    Color sheetBg = _localNightMode 
        ? const Color(0xFF1E1E1E).withOpacity(0.85) 
        : (_localEyeProtection ? const Color(0xFFEFE5CD).withOpacity(0.88) : Colors.white.withOpacity(0.85));
        
    Color textCol = _localNightMode ? Colors.white : (_localEyeProtection ? const Color(0xFF3E2723) : const Color(0xFF1A1A1A));

    // 🛠️ تم إعادة بناء الكود بالكامل وبشكل سليم هنا لحل المشكلة البرمجية السابقة لمنع أي أخطاء
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: sheetBg,
            padding: EdgeInsets.only(
              top: 20, 
              left: 20, 
              right: 20, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 20
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "خيارات العرض والقراءة", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: textCol),
                      Expanded(
                        child: Slider(
                          value: _localFontSize,
                          min: 16,
                          max: 40,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: (val) {
                            setState(() => _localFontSize = val);
                            widget.onFontSizeChanged(val);
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: Text("الوضع الليلي", style: TextStyle(color: textCol)),
                    value: _localNightMode,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (val) {
                      setState(() {
                        _localNightMode = val;
                        if (val) _localEyeProtection = false;
                      });
                      widget.onNightModeChanged(val);
                    },
                  ),
                  SwitchListTile(
                    title: Text("وضع حماية العين", style: TextStyle(color: textCol)),
                    value: _localEyeProtection,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (val) {
                      setState(() {
                        _localEyeProtection = val;
                        if (val) _localNightMode = false;
                      });
                      widget.onEyeProtectionChanged(val);
                    },
                  ),
                  SwitchListTile(
                    title: Text("التمرير التلقائي للآيات", style: TextStyle(color: textCol)),
                    value: _localAutoScrolling,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (val) {
                      setState(() => _localAutoScrolling = val);
                      widget.onAutoScrollToggle(val);
                    },
                  ),
                  if (_localAutoScrolling)
                    Row(
                      children: [
                        Text("سرعة التمرير: ", style: TextStyle(color: textCol)),
                        Expanded(
                          child: Slider(
                            value: _localScrollSpeed,
                            min: 1,
                            max: 10,
                            activeColor: const Color(0xFF2E7D32),
                            onChanged: (val) {
                              setState(() => _localScrollSpeed = val);
                              widget.onSpeedChanged(val);
                              widget.onAutoScrollToggle(false);
                              widget.onAutoScrollToggle(true);
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textCol),
                          decoration: InputDecoration(
                            labelText: "انتقال سريع لآية (1 - ${widget.versesCount})",
                            labelStyle: TextStyle(color: textCol.withOpacity(0.7)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: textCol.withOpacity(0.3))
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF2E7D32))
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                        onPressed: () {
                          int? verseNum = int.tryParse(_inputController.text);
                          if (verseNum != null && verseNum >= 1 && verseNum <= widget.versesCount) {
                            Navigator.pop(context);
                            widget.onJumpToVerse(verseNum);
                          }
                        },
                        child: const Text("اذهب", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
