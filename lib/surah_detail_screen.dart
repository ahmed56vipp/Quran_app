import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final int initialJuz;
  final int? initialVerse;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.initialJuz,
    this.initialVerse,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  static const String _bookmarksKey = 'quran_saved_bookmarks';

  final List<GlobalKey> _verseKeys = [];
  final ScrollController _scrollController = ScrollController();

  List<String> verses = [];
  List<String> tafsirVerses = [];
  List<Map<String, dynamic>> _bookmarks = [];

  bool isLoading = true;
  bool _isAutoScrolling = false;
  bool _updatingVerseFromScroll = false;

  int currentJuz = 1;
  int selectedVerseIndex = 0;
  int _themeMode = 0;

  double _fontSize = 24;
  double _scrollSpeed = 1.0;

  Timer? _autoScrollTimer;
  Timer? _scrollSelectionDebounce;

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz.clamp(1, 30).toInt();
    _scrollController.addListener(_onScroll);
    _loadReadingPreferences();
    _loadData();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _scrollSelectionDebounce?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReadingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _themeMode = (prefs.getInt('quran_theme_mode') ?? 0).clamp(0, 2).toInt();
      _fontSize = (prefs.getDouble('quran_font_size') ?? 24.0).clamp(14.0, 40.0).toDouble();
      _scrollSpeed = (prefs.getDouble('quran_scroll_speed') ?? 1.0).clamp(0.2, 5.0).toDouble();
    });
  }

  Future<void> _saveReadingPreference(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<void> _saveLastReadPosition(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', widget.surahId);
    await prefs.setInt('last_verse', index + 1);
    await prefs.setString('last_surah_name', widget.surahName);
    await prefs.setInt('last_read_surah', widget.surahId);
  }

  int _getJuzForVerse(int surahId, int verseNumber) {
    const juzStarts = <List<int>>[
      [1, 1], [2, 142], [2, 253], [3, 93], [4, 24],
      [4, 148], [5, 82], [6, 111], [7, 88], [8, 41],
      [9, 93], [11, 6], [12, 53], [15, 1], [17, 1],
      [18, 75], [21, 1], [23, 1], [25, 21], [27, 56],
      [29, 46], [33, 31], [36, 28], [39, 32], [41, 47],
      [46, 1], [51, 31], [58, 1], [67, 1], [78, 1],
    ];

    var juz = 1;
    for (var i = 0; i < juzStarts.length; i++) {
      final startSurah = juzStarts[i][0];
      final startVerse = juzStarts[i][1];
      if (surahId > startSurah ||
          (surahId == startSurah && verseNumber >= startVerse)) {
        juz = i + 1;
      } else {
        break;
      }
    }
    return juz.clamp(1, 30).toInt();
  }

  int _numberFromKey(String key) {
    return int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is! Map) return {};
    final result = <String, dynamic>{};
    final source = data['verse'];

    if (source is Map) {
      source.forEach((key, value) {
        result[key.toString()] = value;
      });
      return result;
    }
    if (source is List) {
      for (int i = 0; i < source.length; i++) {
        result['verse_${i + 1}'] = source[i];
      }
      return result;
    }
    data.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  List<String> _extractTexts(Map<String, dynamic> data, {bool removeBasmala = false}) {
    final entries = data.entries.toList()
      ..sort((a, b) => _numberFromKey(a.key).compareTo(_numberFromKey(b.key)));

    final result = <String>[];
    for (final entry in entries) {
      final text = entry.value.toString().trim();
      if (text.isEmpty) continue;
      if (removeBasmala &&
          (text == 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ' ||
              text == 'بسم الله الرحمن الرحيم')) {
        continue;
      }
      result.add(text);
    }
    return result;
  }

  Future<String?> _loadAsset(List<String> paths) async {
    for (final path in paths) {
      try {
        final value = await rootBundle.loadString(path);
        if (value.trim().isNotEmpty) return value;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadData() async {
    try {
      final response = await _loadAsset([
        'assets/surah/surah_${widget.surahId}-json',
        'assets/surah/surah_${widget.surahId}.json',
      ]);

      List<String> loadedVerses = [];
      if (response != null) {
        loadedVerses = _extractTexts(_extractMap(json.decode(response)), removeBasmala: false);
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(widget.versesCount, (i) => 'الآية الكريمة رقم ${i + 1}');
      }

      if (!mounted) return;
      setState(() {
        verses = loadedVerses;
        _verseKeys
          ..clear()
          ..addAll(List.generate(loadedVerses.length, (_) => GlobalKey()));
        isLoading = false;
      });

      await _restoreLastPosition();
    } catch (_) {
      if (!mounted) return;
      final fallback = List.generate(widget.versesCount, (i) => 'الآية الكريمة رقم ${i + 1}');
      setState(() {
        verses = fallback;
        _verseKeys
          ..clear()
          ..addAll(List.generate(fallback.length, (_) => GlobalKey()));
        isLoading = false;
      });
      await _restoreLastPosition();
    }
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bookmarksKey);
      final loaded = <Map<String, dynamic>>[];

      if (raw != null) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final bookmark = Map<String, dynamic>.from(item);
            final surahId = _intValue(bookmark['surahId']);
            final verse = _intValue(bookmark['verse']);
            if (surahId < 1 || verse < 1) continue;
            bookmark['surahId'] = surahId;
            bookmark['verse'] = verse;
            bookmark['surahName'] ??= 'سورة';
            loaded.add(bookmark);
          }
        }
      }
      if (!mounted) return;
      setState(() => _bookmarks = loaded);
    } catch (_) {}
  }

  Future<void> _restoreLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedSurah = prefs.getInt('last_surah');
      final savedVerse = prefs.getInt('last_verse');
      final targetVerse = widget.initialVerse ?? (savedSurah == widget.surahId ? savedVerse : null);
      if (targetVerse != null && targetVerse >= 1 && targetVerse <= verses.length) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (mounted) await _scrollToVerse(targetVerse - 1);
      }
    } catch (_) {}
  }

  void _onScroll() {
    _scrollSelectionDebounce?.cancel();
    _scrollSelectionDebounce = Timer(const Duration(milliseconds: 90), _updateSelectedVerseFromScroll);
  }

  void _updateSelectedVerseFromScroll() {
    if (!mounted || isLoading || verses.isEmpty || _updatingVerseFromScroll || !_scrollController.hasClients) {
      return;
    }
    final screenHeight = MediaQuery.of(context).size.height;
    const targetY = kToolbarHeight + 105.0;

    int? nearestIndex;
    double nearestDistance = double.infinity;

    for (int i = 0; i < _verseKeys.length; i++) {
      final verseContext = _verseKeys[i].currentContext;
      if (verseContext == null) continue;
      final renderObject = verseContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) {
        continue;
      }
      final globalPosition = renderObject.localToGlobal(Offset.zero);
      if (globalPosition.dy < kToolbarHeight || globalPosition.dy > screenHeight) {
        continue;
      }
      final distance = (globalPosition.dy - targetY).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    if (nearestIndex != null && nearestIndex != selectedVerseIndex) {
      _updatingVerseFromScroll = true;
      setState(() {
        selectedVerseIndex = nearestIndex!;
        currentJuz = _getJuzForVerse(widget.surahId, selectedVerseIndex + 1);
      });
      _saveLastReadPosition(nearestIndex);
      _updatingVerseFromScroll = false;
    }
  }

  Future<void> _scrollToVerse(int index) async {
    if (!mounted || index < 0 || index >= verses.length) return;
    _stopAutoScroll();
    setState(() {
      selectedVerseIndex = index;
      currentJuz = _getJuzForVerse(widget.surahId, index + 1);
    });
    _saveLastReadPosition(index);

    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted || index >= _verseKeys.length) return;

    var target = _verseKeys[index].currentContext;
    if (target == null) return;

    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
      );
    } catch (_) {}
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }
    setState(() => _isAutoScrolling = true);
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        return;
      }
      final position = _scrollController.position;
      if (!position.hasContentDimensions || position.pixels >= position.maxScrollExtent) {
        _stopAutoScroll();
        return;
      }
      _scrollController.jumpTo((position.pixels + _scrollSpeed).clamp(0.0, position.maxScrollExtent));
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted && _isAutoScrolling) {
      setState(() => _isAutoScrolling = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFFDF6E3);
    if (_themeMode == 2) return const Color(0xFF121212);
    return const Color(0xFFF8F9FA);
  }

  Color _getTextColor() {
    if (_themeMode == 2) return const Color(0xFFE0E0E0);
    if (_themeMode == 1) return const Color(0xFF5B4636);
    return const Color(0xFF2C3E50);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.surahName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'surah_nam',
                    fontSize: 28,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '(${widget.versesCount})',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'التمرير التلقائي',
              icon: Icon(
                _isAutoScrolling ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: const Color(0xFFFFD700),
              ),
              onPressed: _toggleAutoScroll,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'الجزء ${toArabicNumerals(currentJuz.clamp(1, 30))}',
                  style: const TextStyle(
                    fontFamily: 'jzu12', // ضبط خط الأجزاء بدقة
                    fontSize: 18,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : verses.isEmpty
                ? const Center(child: Text('لا توجد آيات للعرض'))
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: isDark ? 0 : 3,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  for (int i = 0; i < verses.length; i++) ...[
                                    TextSpan(
                                      text: '${verses[i]} ',
                                      style: TextStyle(
                                        fontFamily: 'nss',
                                        fontSize: _fontSize,
                                        height: 2.2,
                                        color: selectedVerseIndex == i ? const Color(0xFF2E7D32) : _getTextColor(),
                                        fontWeight: selectedVerseIndex == i ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle, // توسيط رقم الآية مع السطر تماماً
                                      child: Container(
                                        key: _verseKeys[i],
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: selectedVerseIndex == i ? const Color(0xFF2E7D32) : Colors.transparent,
                                          border: Border.all(color: const Color(0xFF2E7D32)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          toArabicNumerals(i + 1),
                                          style: TextStyle(
                                            fontFamily: '12345',
                                            fontSize: _fontSize * 0.65,
                                            color: selectedVerseIndex == i ? Colors.white : (isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32)),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ' '),
                                  ],
                                ],
                              ),
                              textAlign: TextAlign.justify,
                              textDirection: TextDirection.rtl,
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
