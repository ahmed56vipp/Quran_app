
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

  // مفتاح مستقل لكل آية للانتقال إليها بدقة.
  final List<GlobalKey> _verseKeys = [];

  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  int currentJuz = 1;
  int selectedVerseIndex = 0;

  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  double _scrollSpeed = 1.0;

  double _fontSize = 20.0;

  // 0: فاتح، 1: دافئ، 2: ليلي
  int _themeMode = 0;

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // استخراج الآيات من صيغ JSON المختلفة.
  Map<String, dynamic> _extractVerseMap(dynamic data) {
    if (data is! Map) return {};

    final Map<String, dynamic> result = {};
    final dynamic verseData = data['verse'];

    if (verseData is Map) {
      verseData.forEach((key, value) {
        result[key.toString()] = value;
      });
      return result;
    }

    if (verseData is List) {
      for (int i = 0; i < verseData.length; i++) {
        result['verse_${i + 1}'] = verseData[i];
      }
      return result;
    }

    data.forEach((key, value) {
      result[key.toString()] = value;
    });

    return result;
  }

  int _verseNumber(String key) {
    return int.tryParse(
          key.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  List<String> _extractTexts(
    Map<String, dynamic> verseMap, {
    bool removeBasmala = false,
  }) {
    final entries = verseMap.entries.toList()
      ..sort(
        (a, b) => _verseNumber(a.key).compareTo(_verseNumber(b.key)),
      );

    final List<String> result = [];

    for (final entry in entries) {
      final text = entry.value.toString().trim();

      if (text.isEmpty) continue;

      if (removeBasmala &&
          (text.contains('بِسْمِ') || text.contains('بسم'))) {
        continue;
      }

      result.add(text);
    }

    return result;
  }

  Future<String?> _loadFirstAvailableAsset(
    List<String> paths,
  ) async {
    for (final path in paths) {
      try {
        final response = await rootBundle.loadString(path);

        if (response.trim().isNotEmpty) {
          return response;
        }
      } catch (_) {
        // تجربة المسار التالي.
      }
    }

    return null;
  }

  Future<void> _loadData() async {
    try {
      final response = await _loadFirstAvailableAsset([
        'assets/surah/surah_${widget.surahId}-json',
        'assets/surah/surah_${widget.surahId}.json',
      ]);

      List<String> loadedVerses = [];

      if (response != null) {
        final data = json.decode(response);
        final verseMap = _extractVerseMap(data);

        loadedVerses = _extractTexts(
          verseMap,
          removeBasmala:
              widget.surahId != 1 && widget.surahId != 9,
        );
      }

      if (loadedVerses.isEmpty) {
        loadedVerses = List.generate(
          widget.versesCount,
          (index) => 'الآية الكريمة رقم ${index + 1}',
        );
      }

      // تحميل التفسير.
      List<String> loadedTafsir = [];

      try {
        final tafsirResponse = await _loadFirstAvailableAsset([
          'assets/translation/ar/ar_translation_${widget.surahId}-json',
          'assets/translation/ar/ar_translation_${widget.surahId}.json',
          'assets/translation/ar/surah_${widget.surahId}-json',
          'assets/translation/ar/surah_${widget.surahId}.json',
        ]);

        if (tafsirResponse != null) {
          final tafsirData = json.decode(tafsirResponse);
          final tafsirMap = _extractVerseMap(tafsirData);

          loadedTafsir = _extractTexts(tafsirMap);
        }
      } catch (_) {
        loadedTafsir = [];
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
      });

      // لا نحاول تحميل العلامة قبل وصول الآيات.
      await _loadBookmark();
    } catch (e) {
      if (!mounted) return;

      final fallbackVerses = List.generate(
        widget.versesCount,
        (index) => 'الآية الكريمة رقم ${index + 1}',
      );

      setState(() {
        verses = fallbackVerses;

        _verseKeys
          ..clear()
          ..addAll(
            List.generate(
              fallbackVerses.length,
              (_) => GlobalKey(),
            ),
          );

        isLoading = false;
      });

      await _loadBookmark();
    }
  }

  // الانتقال الفعلي إلى الآية باستخدام مفتاحها.
  Future<void> _scrollToVerse(int index) async {
    if (!mounted || index < 0 || index >= verses.length) return;

    setState(() {
      selectedVerseIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || index >= _verseKeys.length) return;

      final targetContext = _verseKeys[index].currentContext;

      if (targetContext == null) return;

      try {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      } catch (_) {
        // قد يكون عنصر الآية قد أزيل أثناء الانتقال.
      }
    });
  }

  // استرجاع العلامة المرجعية بعد تحميل الآيات.
  Future<void> _loadBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedSurah = prefs.getInt('last_surah');
      final savedVerse = prefs.getInt('last_verse');

      if (!mounted || savedSurah != widget.surahId) return;

      if (savedVerse == null ||
          savedVerse < 1 ||
          savedVerse > verses.length) {
        return;
      }

      await _scrollToVerse(savedVerse - 1);
    } catch (_) {
      // تبقى الشاشة قابلة للاستخدام حتى لو تعذر الوصول للتفضيلات.
    }
  }

  // حفظ العلامة المرجعية.
  Future<void> _saveBookmark() async {
    if (verses.isEmpty ||
        selectedVerseIndex < 0 ||
        selectedVerseIndex >= verses.length) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('last_surah', widget.surahId);
      await prefs.setString('last_surah_name', widget.surahName);
      await prefs.setInt('last_verse', selectedVerseIndex + 1);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ العلامة المرجعية في سورة '
            '${widget.surahName} - الآية ${selectedVerseIndex + 1}',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ العلامة المرجعية'),
        ),
      );
    }
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

  // إيقاف التمرير التلقائي بأمان.
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    if (mounted && _isAutoScrolling) {
      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  // تشغيل وإيقاف التمرير التلقائي.
  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }

    if (!_scrollController.hasClients) return;

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

        final nextOffset = position.pixels + _scrollSpeed;

        _scrollController.jumpTo(
          nextOffset.clamp(0.0, position.maxScrollExtent).toDouble(),
        );
      },
    );
  }

  // نافذة الذهاب إلى آية محددة.
  Future<void> _showGoToVerseDialog() async {
    if (verses.isEmpty) return;

    final controller = TextEditingController();
    final isDark = _themeMode == 2;

    final int? verseNumber = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'الذهاب إلى آية',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'رقم الآية من 1 إلى ${verses.length}',
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
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
                          'أدخل رقمًا صحيحًا بين 1 و${verses.length}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'انتقال',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (!mounted || verseNumber == null) return;

    await _scrollToVerse(verseNumber - 1);
  }

  // شاشة التفسير.
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
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
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
                  const Divider(height: 20),
                  Expanded(
                    child: tafsirVerses.isEmpty
                        ? const Center(
                            child: Text(
                              'التفسير غير متوفر لهذه السورة حالياً',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tafsirVerses.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الآية (${index + 1}):',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tafsirVerses[index],
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.6,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
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

  // التبويب المدمج للإعدادات وأدوات القراءة.
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

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 45,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'التبويب المدمج لأدوات القراءة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                        const Divider(height: 24),

                        // العلامة المرجعية والانتقال.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF2E7D32),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _saveBookmark();
                              },
                              icon: const Icon(
                                Icons.bookmark_add,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'حفظ علامة',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF1B5E20),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _showGoToVerseDialog();
                              },
                              icon: const Icon(
                                Icons.gps_fixed,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'الذهاب لآية',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 24),

                        // حجم الخط.
                        Text(
                          'حجم خط القراءة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'تصغير الخط',
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2E7D32),
                              ),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            IconButton(
                              tooltip: 'تكبير الخط',
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2E7D32),
                              ),
                              onPressed: () {
                                if (_fontSize < 32) {
                                  setState(() => _fontSize += 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // سرعة التمرير.
                        Text(
                          'سرعة التمرير التلقائي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.slow_motion_video,
                              color: Color(0xFF2E7D32),
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
                            const Icon(
                              Icons.fast_forward,
                              color: Color(0xFF2E7D32),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // التفسير.
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.menu_book,
                            color: Color(0xFF2E7D32),
                          ),
                          title: Text(
                            'فتح التفسير الميسر',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: const Text(
                            'عرض تفسير السورة بشكل منفصل',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openTafsirScreen();
                          },
                        ),

                        const Divider(height: 20),

                        // أوضاع العرض.
                        Text(
                          'وضع العرض والوضوح',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('فاتح'),
                              selected: _themeMode == 0,
                              selectedColor: const Color(0xFFE8F5E9),
                              labelStyle: TextStyle(
                                color: _themeMode == 0
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() => _themeMode = 0);
                                setModalState(() {});
                              },
                            ),
                            ChoiceChip(
                              label: const Text('دافئ'),
                              selected: _themeMode == 1,
                              selectedColor: const Color(0xFFFFECB3),
                              labelStyle: TextStyle(
                                color: _themeMode == 1
                                    ? const Color(0xFF5B4636)
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() => _themeMode = 1);
                                setModalState(() {});
                              },
                            ),
                            ChoiceChip(
                              label: const Text('ليلي'),
                              selected: _themeMode == 2,
                              selectedColor: const Color(0xFF37474F),
                              labelStyle: TextStyle(
                                color: _themeMode == 2
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                if (!selected) return;

                                // إصلاح الخطأ: تعيين القيمة بدل مقارنتها.
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
              ),
            );
          },
        );
      },
    );
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
          title: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.surahName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'surah_nam',
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.versesCount})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _isAutoScrolling
                        ? 'إيقاف التمرير'
                        : 'التمرير التلقائي',
                    icon: Icon(
                      _isAutoScrolling
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: const Color(0xFFFFD700),
                      size: 24,
                    ),
                    onPressed: _toggleAutoScroll,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentJuz.toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'jzu12',
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'التبويب المدمج والإعدادات',
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.white,
                      size: 22,
                    ),
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
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                ],
              ),
            ),
          ),
          elevation: 0,
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              )
            : verses.isEmpty
                ? const Center(
                    child: Text('لا توجد آيات لعرضها'),
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
                        if (widget.surahId != 9) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Text(
                                '27',
                                style: const TextStyle(
                                  fontFamily: 'bsm60',
                                  fontSize: 55,
                                  color: Color(0xFF2E7D32),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

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
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0; i < verses.length; i++)
                                  Container(
                                    key: _verseKeys[i],
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedVerseIndex == i
                                          ? (isDark
                                              ? const Color(0xFF26372A)
                                              : const Color(0xFFE8F5E9))
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${verses[i]} ',
                                            style: TextStyle(
                                              fontSize: _fontSize,
                                              fontFamily: 'nss',
                                              height: 2.4,
                                              color: selectedVerseIndex == i
                                                  ? const Color(0xFF2E7D32)
                                                  : _getTextColor(),
                                              fontWeight:
                                                  selectedVerseIndex == i
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' ${i + 1} ',
                                            style: TextStyle(
                                              fontFamily: 'quran_num',
                                              fontSize: _fontSize * 0.9,
                                              color: isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFF2E7D32),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.justify,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                              ],
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
