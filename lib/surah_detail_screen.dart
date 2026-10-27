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

  List<String> _extractTexts(
    Map<String, dynamic> data, {
    bool removeBasmala = false,
  }) {
    final entries = data.entries.toList()
      ..sort((a, b) =>
          _numberFromKey(a.key).compareTo(_numberFromKey(b.key)));

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
        loadedVerses = _extractTexts(
          _extractMap(json.decode(response)),
          removeBasmala: false,
        );
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(
          widget.versesCount,
          (i) => 'الآية الكريمة رقم ${i + 1}',
        );
      }

      List<String> loadedTafsir = [];
      final responseTafsir = await _loadAsset([
        'assets/translation/ar/ar_translation_${widget.surahId}-json',
        'assets/translation/ar/ar_translation_${widget.surahId}.json',
        'assets/translation/ar/surah_${widget.surahId}-json',
        'assets/translation/ar/surah_${widget.surahId}.json',
      ]);

      if (responseTafsir != null) {
        try {
          loadedTafsir =
              _extractTexts(_extractMap(json.decode(responseTafsir)));
        } catch (_) {
          loadedTafsir = [];
        }
      }

      if (!mounted) return;
      setState(() {
        verses = loadedVerses;
        tafsirVerses = loadedTafsir;
        _verseKeys
          ..clear()
          ..addAll(List.generate(loadedVerses.length, (_) => GlobalKey()));
        isLoading = false;
      });

      await _restoreLastPosition();
    } catch (_) {
      if (!mounted) return;
      final fallback = List.generate(
        widget.versesCount,
        (i) => 'الآية الكريمة رقم ${i + 1}',
      );
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

      final oldSurah = prefs.getInt('last_surah');
      final oldVerse = prefs.getInt('last_verse');
      if (oldSurah != null &&
          oldVerse != null &&
          oldSurah > 0 &&
          oldVerse > 0 &&
          !loaded.any((b) =>
              _intValue(b['surahId']) == oldSurah &&
              _intValue(b['verse']) == oldVerse)) {
        loaded.add({
          'surahId': oldSurah,
          'surahName': prefs.getString('last_surah_name') ?? 'سورة',
          'verse': oldVerse,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      if (!mounted) return;
      setState(() => _bookmarks = loaded);
      await prefs.setString(_bookmarksKey, json.encode(loaded));
    } catch (_) {}
  }

  Future<void> _persistBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarksKey, json.encode(_bookmarks));
  }

  Future<void> _saveBookmark() async {
    if (verses.isEmpty ||
        selectedVerseIndex < 0 ||
        selectedVerseIndex >= verses.length) {
      _showMessage('تعذّر تحديد الآية الحالية');
      return;
    }

    final verseNumber = selectedVerseIndex + 1;
    final exists = _bookmarks.any((b) =>
        _intValue(b['surahId']) == widget.surahId &&
        _intValue(b['verse']) == verseNumber);

    if (exists) {
      _showMessage('هذه العلامة محفوظة مسبقًا');
      return;
    }

    final bookmark = <String, dynamic>{
      'surahId': widget.surahId,
      'surahName': widget.surahName,
      'verse': verseNumber,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() => _bookmarks.add(bookmark));

    try {
      await _persistBookmarks();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_surah', widget.surahId);
      await prefs.setString('last_surah_name', widget.surahName);
      await prefs.setInt('last_verse', verseNumber);

      if (mounted) _showMessage('تم حفظ العلامة في الآية $verseNumber');
    } catch (_) {
      if (!mounted) return;
      setState(() => _bookmarks.removeWhere((b) =>
          _intValue(b['surahId']) == widget.surahId &&
          _intValue(b['verse']) == verseNumber));
      _showMessage('تعذّر حفظ العلامة');
    }
  }

  Future<void> _deleteBookmark(Map<String, dynamic> bookmark) async {
    final surahId = _intValue(bookmark['surahId']);
    final verse = _intValue(bookmark['verse']);
    final oldList = List<Map<String, dynamic>>.from(_bookmarks);

    setState(() {
      _bookmarks.removeWhere((b) =>
          _intValue(b['surahId']) == surahId &&
          _intValue(b['verse']) == verse);
    });

    try {
      await _persistBookmarks();
      if (mounted) _showMessage('تم حذف العلامة');
    } catch (_) {
      if (!mounted) return;
      setState(() => _bookmarks = oldList);
      _showMessage('تعذّر تحديث العلامات المحفوظة');
    }
  }

  Future<void> _restoreLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedSurah = prefs.getInt('last_surah');
      final savedVerse = prefs.getInt('last_verse');
      final targetVerse = widget.initialVerse ??
          (savedSurah == widget.surahId ? savedVerse : null);
      if (targetVerse != null && targetVerse >= 1 && targetVerse <= verses.length) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (mounted) await _scrollToVerse(targetVerse - 1);
      }
    } catch (_) {}
  }

  void _showBookmarks() {
    final isDark = _themeMode == 2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.7,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'العلامات المرجعية المحفوظة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: _bookmarks.isEmpty
                            ? const Center(
                                child: Text('لا توجد علامات محفوظة بعد'),
                              )
                            : ListView.builder(
                                itemCount: _bookmarks.length,
                                itemBuilder: (context, index) {
                                  final bookmark = _bookmarks[index];
                                  final surahId =
                                      _intValue(bookmark['surahId']);
                                  final verse = _intValue(bookmark['verse']);
                                  final surahName =
                                      bookmark['surahName']?.toString() ??
                                          'سورة';

                                  return ListTile(
                                    leading: const Icon(
                                      Icons.bookmark,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    title: Text('$surahName - الآية $verse'),
                                    subtitle: Text(
                                      surahId == widget.surahId
                                          ? 'اضغط للانتقال إلى الآية'
                                          : 'افتح السورة للوصول إلى العلامة',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'حذف العلامة',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        await _deleteBookmark(bookmark);
                                        if (mounted) {
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                                    onTap: () {
                                      if (surahId != widget.surahId) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'افتح السورة المحفوظة للانتقال إلى علامتها',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.pop(sheetContext);
                                      _scrollToVerse(verse - 1);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onScroll() {
    _scrollSelectionDebounce?.cancel();
    _scrollSelectionDebounce = Timer(
      const Duration(milliseconds: 90),
      _updateSelectedVerseFromScroll,
    );
  }

  void _updateSelectedVerseFromScroll() {
    if (!mounted ||
        isLoading ||
        verses.isEmpty ||
        _updatingVerseFromScroll ||
        !_scrollController.hasClients) {
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
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }

      final globalPosition = renderObject.localToGlobal(Offset.zero);
      if (globalPosition.dy < kToolbarHeight ||
          globalPosition.dy > screenHeight) {
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
    if (target == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      target = _verseKeys[index].currentContext;
    }
    if (target == null) {
      _showMessage('تعذّر تحديد موضع الآية، حاول مرة أخرى');
      return;
    }

    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
      );
    } catch (_) {
      if (mounted) _showMessage('تعذّر الانتقال إلى الآية');
    }
  }

  Future<void> _showGoToVerseDialog() async {
    if (verses.isEmpty) return;

    final controller = TextEditingController();
    final isDark = _themeMode == 2;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'الذهاب إلى آية',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'رقم الآية من 1 إلى ${verses.length}',
              ),
              onSubmitted: (value) {
                final number = int.tryParse(value);
                if (number != null &&
                    number >= 1 &&
                    number <= verses.length) {
                  Navigator.pop(dialogContext, number);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final number = int.tryParse(controller.text);
                  if (number != null &&
                      number >= 1 &&
                      number <= verses.length) {
                    Navigator.pop(dialogContext, number);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'أدخل رقمًا من 1 إلى ${verses.length}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('انتقال'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (result != null && mounted) await _scrollToVerse(result - 1);
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }

    if (!_scrollController.hasClients) {
      _showMessage('انتظر حتى يكتمل تحميل المصحف');
      return;
    }

    setState(() => _isAutoScrolling = true);
    _autoScrollTimer?.cancel();

    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (timer) {
        if (!mounted || !_scrollController.hasClients) {
          timer.cancel();
          return;
        }

        final position = _scrollController.position;
        if (!position.hasContentDimensions ||
            position.pixels >= position.maxScrollExtent) {
          _stopAutoScroll();
          return;
        }

        _scrollController.jumpTo(
          (position.pixels + _scrollSpeed)
              .clamp(0.0, position.maxScrollExtent)
              .toDouble(),
        );
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted && _isAutoScrolling) {
      setState(() => _isAutoScrolling = false);
    }
  }

  void _openTafsirScreen() {
    final isDark = _themeMode == 2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التفسير الميسر - سورة ${widget.surahName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: tafsirVerses.isEmpty
                        ? const Center(
                            child: Text('التفسير غير متوفر حاليًا'),
                          )
                        : ListView.builder(
                            itemCount: tafsirVerses.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'الآية (${index + 1}):\n${tafsirVerses[index]}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.8,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSettingsBottomSheet() {
    final isDark = _themeMode == 2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final modalIsDark = _themeMode == 2;
            final textColor = modalIsDark ? Colors.white : Colors.black87;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'أدوات القراءة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: modalIsDark
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.bookmark_add,
                          color: Color(0xFF2E7D32),
                        ),
                        title: Text(
                          'حفظ علامة مرجعية',
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          'الآية الحالية: ${selectedVerseIndex + 1}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _saveBookmark();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.bookmarks,
                          color: Color(0xFF2E7D32),
                        ),
                        title: Text(
                          'علاماتي المحفوظة',
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          'عدد العلامات: ${_bookmarks.length}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showBookmarks();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.gps_fixed,
                          color: Color(0xFF2E7D32),
                        ),
                        title: Text(
                          'الذهاب إلى آية',
                          style: TextStyle(color: textColor),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showGoToVerseDialog();
                        },
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF2E7D32),
                        title: Text(
                          'التمرير التلقائي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          _isAutoScrolling
                              ? 'التمرير يعمل الآن'
                              : 'تشغيل أو إيقاف تمرير الصفحة',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        value: _isAutoScrolling,
                        onChanged: (value) {
                          if (value) {
                            _toggleAutoScroll();
                          } else {
                            _stopAutoScroll();
                          }
                          setModalState(() {});
                        },
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.slow_motion_video,
                            color: modalIsDark ? Colors.white70 : Colors.green,
                          ),
                          Expanded(
                            child: Slider(
                              value: _scrollSpeed,
                              min: 0.2,
                              max: 3.0,
                              divisions: 14,
                              activeColor: const Color(0xFF2E7D32),
                              label: _scrollSpeed.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() => _scrollSpeed = value);
                                _saveReadingPreference('quran_scroll_speed', value);
                                setModalState(() {});
                              },
                            ),
                          ),
                          Icon(
                            Icons.fast_forward,
                            color: modalIsDark ? Colors.white70 : Colors.green,
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'سرعة التمرير: ${_scrollSpeed.toStringAsFixed(1)}',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        'حجم خط القراءة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (_fontSize > 14) {
                                setState(() => _fontSize -= 2);
                                _saveReadingPreference('quran_font_size', _fontSize);
                                setModalState(() {});
                              }
                            },
                          ),
                          Text(
                            toArabicNumerals(_fontSize.round()),
                            style: TextStyle(fontSize: 18, color: textColor),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (_fontSize < 40) {
                                setState(() => _fontSize += 2);
                                _saveReadingPreference('quran_font_size', _fontSize);
                                setModalState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.menu_book,
                          color: Color(0xFF2E7D32),
                        ),
                        title: Text(
                          'فتح التفسير الميسر',
                          style: TextStyle(color: textColor),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openTafsirScreen();
                        },
                      ),
                      const Divider(height: 24),
                      Text(
                        'وضع العرض',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('فاتح'),
                            selected: _themeMode == 0,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _themeMode = 0);
                              _saveReadingPreference('quran_theme_mode', 0);
                              setModalState(() {});
                            },
                          ),
                          ChoiceChip(
                            label: const Text('دافئ'),
                            selected: _themeMode == 1,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _themeMode = 1);
                              _saveReadingPreference('quran_theme_mode', 1);
                              setModalState(() {});
                            },
                          ),
                          ChoiceChip(
                            label: const Text('ليلي'),
                            selected: _themeMode == 2,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _themeMode = 2);
                              _saveReadingPreference('quran_theme_mode', 2);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                    fontSize: 28, // تكبير اسم السورة في شريط القراءة
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '(${widget.versesCount})',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'التمرير التلقائي',
              icon: Icon(
                _isAutoScrolling
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
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
                    fontFamily: 'jzu12', // استخدام الخط المخصص للأجزاء بدقة
                    fontSize: 18,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'أدوات القراءة',
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _showSettingsBottomSheet,
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
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              )
            : verses.isEmpty
                ? const Center(child: Text('لا توجد آيات للعرض'))
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.surahId != 9)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                '27',
                                style: const TextStyle(
                                  fontFamily: 'bsm60',
                                  fontSize: 55,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                        Card(
                          elevation: isDark ? 0 : 3,
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                        color: selectedVerseIndex == i
                                            ? const Color(0xFF2E7D32)
                                            : _getTextColor(),
                                        fontWeight: selectedVerseIndex == i
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle, // توسيط رقم الآية مع السطر تماماً
                                      child: Container(
                                        key: _verseKeys[i],
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedVerseIndex == i
                                              ? const Color(0xFF2E7D32)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: const Color(0xFF2E7D32),
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          toArabicNumerals(i + 1),
                                          style: TextStyle(
                                            fontFamily: 'quran_num',
                                            fontSize: _fontSize * 0.65,
                                            color: selectedVerseIndex == i
                                                ? Colors.white
                                                : (isDark
                                                    ? const Color(0xFFFFD700)
                                                    : const Color(0xFF2E7D32)),
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
