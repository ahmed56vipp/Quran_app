
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
  List<String> tafsirVerses = [];

  final List<GlobalKey> _verseKeys = [];
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  bool _isAutoScrolling = false;
  bool _restoringPosition = false;

  int currentJuz = 1;
  int selectedVerseIndex = 0;
  int _themeMode = 0;

  double _fontSize = 24;
  double _scrollSpeed = 1.0;

  Timer? _autoScrollTimer;
  Timer? _scrollUpdateTimer;

  static const String _bookmarksKey = 'quran_saved_bookmarks';

  List<Map<String, dynamic>> _bookmarks = [];

  // بدايات الأجزاء في المصحف: رقم الجزء، رقم السورة، رقم الآية.
  // تُستخدم لتحديد الجزء بناءً على الآية الحالية.
  static const List<List<int>> _juzStarts = [
    [1, 1, 1],
    [2, 2, 142],
    [3, 2, 253],
    [4, 3, 93],
    [5, 4, 24],
    [6, 4, 148],
    [7, 5, 82],
    [8, 6, 111],
    [9, 7, 88],
    [10, 8, 41],
    [11, 9, 93],
    [12, 11, 6],
    [13, 12, 53],
    [14, 15, 1],
    [15, 17, 1],
    [16, 18, 75],
    [17, 21, 1],
    [18, 23, 1],
    [19, 25, 21],
    [20, 27, 56],
    [21, 29, 46],
    [22, 33, 31],
    [23, 36, 28],
    [24, 39, 32],
    [25, 41, 47],
    [26, 46, 1],
    [27, 51, 31],
    [28, 58, 1],
    [29, 67, 1],
    [30, 78, 1],
  ];

  @override
  void initState() {
    super.initState();

    currentJuz = widget.initialJuz.clamp(1, 30);

    _scrollController.addListener(_scheduleVerseUpdate);

    _loadData();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollUpdateTimer?.cancel();
    _scrollController.removeListener(_scheduleVerseUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------- تحديد الجزء الحالي ----------------

  int _getJuzForVerse(int surah, int verse) {
    int result = 1;

    for (final entry in _juzStarts) {
      final juz = entry[0];
      final startSurah = entry[1];
      final startVerse = entry[2];

      if (surah > startSurah ||
          (surah == startSurah && verse >= startVerse)) {
        result = juz;
      } else {
        break;
      }
    }

    return result;
  }

  void _updateSelectedVerse(int index) {
    if (index < 0 || index >= verses.length) return;

    final newJuz = _getJuzForVerse(widget.surahId, index + 1);

    if (!mounted) return;

    if (selectedVerseIndex != index || currentJuz != newJuz) {
      setState(() {
        selectedVerseIndex = index;
        currentJuz = newJuz;
      });
    }
  }

  // يُحدّث الآية المحددة عند تحريك الصفحة باليد أو تلقائيًا.
  void _scheduleVerseUpdate() {
    if (!mounted || isLoading || verses.isEmpty) return;

    _scrollUpdateTimer?.cancel();

    _scrollUpdateTimer = Timer(
      const Duration(milliseconds: 90),
      _updateVerseFromViewport,
    );
  }

  void _updateVerseFromViewport() {
    if (!mounted || !context.mounted || verses.isEmpty) return;

    final screenHeight = MediaQuery.of(context).size.height;

    int? bestIndex;
    double bestDistance = double.infinity;

    for (int i = 0; i < _verseKeys.length; i++) {
      final verseContext = _verseKeys[i].currentContext;
      if (verseContext == null) continue;

      final renderObject = verseContext.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }

      final position = renderObject.localToGlobal(Offset.zero);
      final y = position.dy;

      if (y < 70 || y > screenHeight - 30) continue;

      final distance = (y - 150).abs();

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    if (bestIndex != null) {
      _updateSelectedVerse(bestIndex);
    }
  }

  // ---------------- تحميل الآيات والتفسير ----------------

  int _numberFromKey(String key) {
    return int.tryParse(
          key.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
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
      ..sort(
        (a, b) => _numberFromKey(a.key).compareTo(
          _numberFromKey(b.key),
        ),
      );

    final result = <String>[];

    for (final entry in entries) {
      final value = entry.value;

      String text;

      if (value is Map) {
        text = (value['text'] ??
                value['verse'] ??
                value['translation'] ??
                value['content'] ??
                '')
            .toString()
            .trim();
      } else {
        text = value.toString().trim();
      }

      if (text.isEmpty) continue;

      result.add(text);
    }

    // لا نحذف آية لمجرد ورود البسملة ضمن نصها.
    // تُحذف فقط إذا كانت البسملة مستقلة في أول عنصر.
    if (removeBasmala &&
        result.isNotEmpty &&
        RegExp(r'^بِسْمِ\s+اللَّهِ|^بسم الله').hasMatch(result.first)) {
      result.removeAt(0);
    }

    return result;
  }

  Future<String?> _loadAsset(List<String> paths) async {
    for (final path in paths) {
      try {
        final value = await rootBundle.loadString(path);
        if (value.trim().isNotEmpty) return value;
      } catch (_) {
        // تجربة المسار التالي.
      }
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
          removeBasmala: widget.surahId != 1 && widget.surahId != 9,
        );
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(
          widget.versesCount,
          (i) => 'الآية الكريمة رقم ${i + 1}',
        );
      }

      List<String> loadedTafsir = [];

      final tafsirResponse = await _loadAsset([
        'assets/translation/ar/ar_translation_${widget.surahId}-json',
        'assets/translation/ar/ar_translation_${widget.surahId}.json',
        'assets/translation/ar/surah_${widget.surahId}-json',
        'assets/translation/ar/surah_${widget.surahId}.json',
      ]);

      if (tafsirResponse != null) {
        try {
          loadedTafsir = _extractTexts(
            _extractMap(json.decode(tafsirResponse)),
          );
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
          ..addAll(
            List.generate(
              loadedVerses.length,
              (_) => GlobalKey(),
            ),
          );

        isLoading = false;

        if (loadedVerses.isNotEmpty) {
          selectedVerseIndex = 0;
          currentJuz = _getJuzForVerse(widget.surahId, 1);
        }
      });

      await _restoreLastPosition();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        verses = List.generate(
          widget.versesCount,
          (i) => 'الآية الكريمة رقم ${i + 1}',
        );

        _verseKeys
          ..clear()
          ..addAll(
            List.generate(
              verses.length,
              (_) => GlobalKey(),
            ),
          );

        isLoading = false;
      });

      _showMessage('تعذر تحميل بعض بيانات السورة');
    }
  }

  // ---------------- العلامات المرجعية ----------------

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
            final surahId = _readInt(bookmark['surahId']);
            final verse = _readInt(bookmark['verse']);

            if (surahId == null ||
                verse == null ||
                surahId < 1 ||
                surahId > 114 ||
                verse < 1) {
              continue;
            }

            bookmark['surahId'] = surahId;
            bookmark['verse'] = verse;
            bookmark['surahName'] ??= 'سورة';

            loaded.add(bookmark);
          }
        }
      }

      // نقل العلامة القديمة إلى القائمة الجديدة عند الحاجة.
      final oldSurah = prefs.getInt('last_surah');
      final oldVerse = prefs.getInt('last_verse');

      if (oldSurah != null &&
          oldVerse != null &&
          oldSurah >= 1 &&
          oldSurah <= 114 &&
          oldVerse > 0 &&
          !loaded.any(
            (b) =>
                b['surahId'] == oldSurah &&
                b['verse'] == oldVerse,
          )) {
        loaded.add({
          'surahId': oldSurah,
          'surahName':
              prefs.getString('last_surah_name') ?? 'سورة',
          'verse': oldVerse,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      if (!mounted) return;

      setState(() {
        _bookmarks = loaded;
      });

      await prefs.setString(_bookmarksKey, json.encode(loaded));
    } catch (_) {
      // لا يمنع تعذر التخزين فتح المصحف.
    }
  }

  Future<void> _persistBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarksKey, json.encode(_bookmarks));
  }

  Future<void> _saveBookmark() async {
    if (verses.isEmpty ||
        selectedVerseIndex < 0 ||
        selectedVerseIndex >= verses.length) {
      return;
    }

    final verseNumber = selectedVerseIndex + 1;

    final exists = _bookmarks.any(
      (b) =>
          _readInt(b['surahId']) == widget.surahId &&
          _readInt(b['verse']) == verseNumber,
    );

    if (exists) {
      _showMessage('هذه العلامة محفوظة مسبقاً');
      return;
    }

    final bookmark = <String, dynamic>{
      'surahId': widget.surahId,
      'surahName': widget.surahName,
      'verse': verseNumber,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _bookmarks.add(bookmark);
    });

    try {
      await _persistBookmarks();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_surah', widget.surahId);
      await prefs.setString('last_surah_name', widget.surahName);
      await prefs.setInt('last_verse', verseNumber);

      if (!mounted) return;

      _showMessage('تم حفظ العلامة في الآية $verseNumber');
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر حفظ العلامة');
    }
  }

  Future<void> _deleteBookmark(
    Map<String, dynamic> bookmark,
  ) async {
    final oldList = List<Map<String, dynamic>>.from(_bookmarks);

    setState(() {
      _bookmarks.removeWhere(
        (b) =>
            _readInt(b['surahId']) ==
                _readInt(bookmark['surahId']) &&
            _readInt(b['verse']) == _readInt(bookmark['verse']),
      );
    });

    try {
      await _persistBookmarks();

      if (mounted) _showMessage('تم حذف العلامة');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _bookmarks = oldList;
      });

      _showMessage('تعذر تحديث العلامات المحفوظة');
    }
  }

  Future<void> _restoreLastPosition() async {
    if (verses.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      final savedSurah = prefs.getInt('last_surah');
      final savedVerse = prefs.getInt('last_verse');

      if (savedSurah == widget.surahId &&
          savedVerse != null &&
          savedVerse >= 1 &&
          savedVerse <= verses.length) {
        _restoringPosition = true;
        await _scrollToVerse(savedVerse - 1);
        _restoringPosition = false;
      }
    } catch (_) {
      _restoringPosition = false;
    }
  }

  void _showBookmarks() {
    final isDark = _themeMode == 2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
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
                            child: Text(
                              'لا توجد علامات محفوظة بعد',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _bookmarks.length,
                            itemBuilder: (context, index) {
                              final bookmark = _bookmarks[index];

                              final surahId =
                                  _readInt(bookmark['surahId']) ?? 0;
                              final verse =
                                  _readInt(bookmark['verse']) ?? 0;
                              final surahName =
                                  bookmark['surahName']?.toString() ??
                                      'سورة';

                              return ListTile(
                                leading: const Icon(
                                  Icons.bookmark,
                                  color: Color(0xFF2E7D32),
                                ),
                                title: Text(
                                  '$surahName - الآية $verse',
                                ),
                                subtitle: Text(
                                  surahId == widget.surahId
                                      ? 'اضغط للانتقال إلى الآية'
                                      : 'محفوظة في سورة أخرى',
                                ),
                                trailing: IconButton(
                                  tooltip: 'حذف العلامة',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _deleteBookmark(bookmark),
                                ),
                                onTap: () {
                                  if (surahId != widget.surahId) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'افتح السورة المحفوظة '
                                          'للانتقال إلى علامتها',
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
  }

  // ---------------- الانتقال إلى آية ----------------

  Future<void> _scrollToVerse(int index) async {
    if (!mounted || index < 0 || index >= verses.length) return;

    _updateSelectedVerse(index);

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || index >= _verseKeys.length) return;

    final target = _verseKeys[index].currentContext;
    if (target == null) return;

    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );

      _updateSelectedVerse(index);
    } catch (_) {}
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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
                          'أدخل رقماً من 1 إلى ${verses.length}',
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

    if (result != null && mounted) {
      await _scrollToVerse(result - 1);
    }
  }

  // ---------------- التمرير التلقائي ----------------

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }

    if (!_scrollController.hasClients) {
      _showMessage('انتظر حتى يكتمل تحميل المصحف');
      return;
    }

    setState(() {
      _isAutoScrolling = true;
    });

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
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  // ---------------- التفسير ----------------

  void _openTafsirScreen() {
    final isDark = _themeMode == 2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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
                            child: Text(
                              'التفسير غير متوفر حالياً',
                            ),
                          )
                        : ListView.builder(
                            itemCount: tafsirVerses.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'الآية (${index + 1}):\n'
                                  '${tafsirVerses[index]}',
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

  // ---------------- الإعدادات ----------------

  void _showSettingsBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _themeMode == 2;
            final textColor = isDark ? Colors.white : Colors.black87;

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
                          color: isDark
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
                            color: isDark ? Colors.white70 : Colors.green,
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
                                setModalState(() {});
                              },
                            ),
                          ),
                          Icon(
                            Icons.fast_forward,
                            color: isDark ? Colors.white70 : Colors.green,
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
                                setModalState(() {});
                              }
                            },
                          ),
                          Text(
                            toArabicNumerals(_fontSize.round()),
                            style: TextStyle(
                              fontSize: 18,
                              color: textColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (_fontSize < 40) {
                                setState(() => _fontSize += 2);
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
                            onSelected: (value) {
                              if (!value) return;
                              setState(() => _themeMode = 0);
                              setModalState(() {});
                            },
                          ),
                          ChoiceChip(
                            label: const Text('دافئ'),
                            selected: _themeMode == 1,
                            onSelected: (value) {
                              if (!value) return;
                              setState(() => _themeMode = 1);
                              setModalState(() {});
                            },
                          ),
                          ChoiceChip(
                            label: const Text('ليلي'),
                            selected: _themeMode == 2,
                            onSelected: (value) {
                              if (!value) return;
                              setState(() => _themeMode = 2);
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

  // ---------------- أدوات مساعدة ----------------

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

  // ---------------- واجهة المصحف ----------------

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
            onPressed: () {
              _stopAutoScroll();
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.surahName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'surah_nam',
                    fontSize: 24,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '(${widget.versesCount})',
                style: const TextStyle(
                  fontSize: 11,
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

            // لا تحوّل الرقم إلى أرقام عربية.
            // الخط jzu12 مسؤول عن الشكل المزخرف.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  currentJuz.toString(),
                  style: const TextStyle(
                    fontFamily: 'jzu12',
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
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                ],
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
                ? const Center(
                    child: Text('لا توجد آيات للعرض'),
                  )
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                '27',
                                style: TextStyle(
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
                                      alignment: PlaceholderAlignment.middle,
                                      child: Container(
                                        key: _verseKeys[i],
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
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
                                          '${i + 1}',
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
