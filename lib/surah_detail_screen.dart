import 'dart:convert';
import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart'; // ✅ إضافة حزمة الصوت

// =========================================================
// 📥 إعدادات الخطوط والمخطوطات الإسلامية المعتمدة في الـ YAML
// =========================================================
const String kSurahNameFont = 'nam';       
const String kBasmalahFont = 'bsm60';      
const String kSurahTextFont = 'nss';       
const String kNumbersFont = 'quran_num';   
const String kJuzFont = 'jzu12'; 

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
  
  DateTime _lastScrollCheck = DateTime.now();

  // ✅ متغيرات مشغل الصوت الجديد
  late AudioPlayer _audioPlayer;
  bool _isAudioLoading = false;

  @override
  void initState() {
    super.initState();
    _verseKeys.addAll(List.generate(widget.versesCount + 1, (index) => GlobalKey()));
    _loadSurahVerses();
    _scrollController.addListener(_onScroll);
    
    // ✅ تهيئة مشغل الصوت
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  // ✅ دالة تجهيز رابط الصوت الخاص بالسورة تلقائياً
  Future<void> _initAudio() async {
    setState(() => _isAudioLoading = true);
    try {
      // تحويل رقم السورة إلى صيغة 3 خانات (مثال: سورة 1 تصبح 001)
      String formattedSurahId = widget.surahId.toString().padLeft(3, '0');
      // رابط التلاوة (بصوت الشيخ مشاري العفاسي كمثال)
      String audioUrl = "https://server8.mp3quran.net/afs/$formattedSurahId.mp3";
      
      await _audioPlayer.setUrl(audioUrl);
    } catch (e) {
      debugPrint("خطأ في تحميل الصوت: $e");
    } finally {
      if (mounted) setState(() => _isAudioLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    _audioPlayer.dispose(); // ✅ إغلاق مشغل الصوت لحفظ الذاكرة
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

    final now = DateTime.now();
    if (now.difference(_lastScrollCheck).inMilliseconds < 90) return;
    _lastScrollCheck = now;

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
          toolbarHeight: 75, 
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "سورة ${widget.surahName}", 
                    style: const TextStyle(
                      fontFamily: kSurahNameFont, 
                      fontSize: 32, 
                      color: Color(0xFFFFD700),
                      height: 1.1
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "آياتها: ${widget.versesCount}", 
                    style: const TextStyle(
                      fontSize: 12, 
                      color: Colors.white70, 
                      fontWeight: FontWeight.w500
                    )
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  cleanJuzNum.trim(), 
                  style: const TextStyle(
                    fontFamily: kJuzFont, 
                    fontSize: 32, 
                    color: Color(0xFFFFD700),
                  ),
                ),
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
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height, 
                  child: UnifiedSettingsBottomSheet(
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
            ),
          ],
        ),
        
        // ✅ إضافة شريط التحكم الصوتي في الأسفل بشكل ثابت واحترافي
        bottomNavigationBar: _buildAudioBottomBar(cardColor, textColor),

        body: SafeArea(
          child: _versesMap == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 90.0), // زيادة الحشو السفلي لتفادي تغطية النص بشريط الصوت
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

  // ✅ تصميم شريط الصوت السفلي
  Widget _buildAudioBottomBar(Color cardColor, Color textColor) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -3))
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                "تلاوة سورة ${widget.surahName}",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          _isAudioLoading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2E7D32)),
                )
              : StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final playing = playerState?.playing;
                    final processingState = playerState?.processingState;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2E7D32)),
                      );
                    } else if (playing != true) {
                      return CircleAvatar(
                        backgroundColor: const Color(0xFF2E7D32),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          onPressed: _audioPlayer.play,
                        ),
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return CircleAvatar(
                        backgroundColor: Colors.amber[700],
                        child: IconButton(
                          icon: const Icon(Icons.pause, color: Colors.white),
                          onPressed: _audioPlayer.pause,
                        ),
                      );
                    } else {
                      return CircleAvatar(
                        backgroundColor: const Color(0xFF2E7D32),
                        child: IconButton(
                          icon: const Icon(Icons.replay, color: Colors.white),
                          onPressed: () => _audioPlayer.seek(Duration.zero),
                        ),
                      );
                    }
                  },
                ),
        ],
      ),
    );
  }
}

// =========================================================
// 🎨 تصميم غلاف البسملة الجديد
// =========================================================
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
      margin: const EdgeInsets.only(bottom: 22, top: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: const Color(0xFFE5C158), width: 1.5), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4), 
          ),
        ],
        gradient: LinearGradient( 
          colors: [
            cardColor,
            const Color(0xFFFFFDF0).withOpacity(0.4),
            cardColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Text(
        "19", 
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kBasmalahFont, 
          fontSize: 38, 
          color: textColor,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.12),
              offset: const Offset(1, 1),
              blurRadius: 1,
            )
          ]
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

// =========================================================
// 🎛️ شاشة الإعدادات المحدثة
// =========================================================
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
        ? const Color(0xFF1E1E1E)
        : (_localEyeProtection ? const Color(0xFFEFE5CD) : Colors.white);
        
    Color textCol = _localNightMode ? Colors.white : (_localEyeProtection ? const Color(0xFF3E2723) : const Color(0xFF1A1A1A));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: sheetBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 0,
          title: const Text("خيارات العرض والقراءة", style: TextStyle(color: Colors.white, fontSize: 20)),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white), 
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  "حجم خط القراءة:", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)
                ),
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
                const Divider(),
                SwitchListTile(
                  title: Text("الوضع الليلي", style: TextStyle(color: textCol, fontWeight: FontWeight.w500)),
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
                  title: Text("وضع حماية العين (الدافئ)", style: TextStyle(color: textCol, fontWeight: FontWeight.w500)),
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
                const Divider(),
                SwitchListTile(
                  title: Text("التمرير التلقائي لصفحة المصحف", style: TextStyle(color: textCol, fontWeight: FontWeight.w500)),
                  value: _localAutoScrolling,
                  activeColor: const Color(0xFF2E7D32),
                  onChanged: (val) {
                    setState(() => _localAutoScrolling = val);
                    widget.onAutoScrollToggle(val);
                  },
                ),
                if (_localAutoScrolling)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
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
                  ),
                const Divider(),
                const SizedBox(height: 15),
                Text(
                  "الانتقال السريع لآية معينة:", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textCol),
                        decoration: InputDecoration(
                          labelText: "أدخل رقم الآية (1 - ${widget.versesCount})",
                          labelStyle: TextStyle(color: textCol.withOpacity(0.7)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textCol.withOpacity(0.4))
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2)
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: () {
                        int? verseNum = int.tryParse(_inputController.text);
                        if (verseNum != null && verseNum >= 1 && verseNum <= widget.versesCount) {
                          Navigator.pop(context);
                          widget.onJumpToVerse(verseNum);
                        }
                      },
                      child: const Text("اذهب الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
