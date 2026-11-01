import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int versesCount;
  final String surahType;
  final int initialJuz;
  final int? initialVerse;
  final String reciterId;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.versesCount,
    required this.surahType,
    required this.initialJuz,
    this.initialVerse,
    this.reciterId = '123',
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final List<GlobalKey> _verseKeys = [];
  final ScrollController _scrollController = ScrollController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;

  List<String> verses = [];
  String? _openingBasmala;
  List<Map<String, dynamic>> _bookmarks = [];

  bool isLoading = true;
  String? _loadError;
  bool _isAutoScrolling = false;
  bool _updatingVerseFromScroll = false;
  bool _isFullscreen = false;

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

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isAudioPlaying = state.playing);
      }
    });
  }

  @override
  void dispose() {
    _scrollSelectionDebounce?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _audioPlayer.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _loadReadingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _themeMode = (prefs.getInt('quran_theme_mode') ?? 0).clamp(0, 2).toInt();
      _fontSize =
          (prefs.getDouble('quran_font_size') ?? 24.0).clamp(14.0, 40.0).toDouble();
      _scrollSpeed =
          (prefs.getDouble('quran_scroll_speed') ?? 1.0).clamp(0.2, 5.0).toDouble();
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
      source.forEach((key, value) => result[key.toString()] = value);
      return result;
    }
    if (source is List) {
      for (int i = 0; i < source.length; i++) {
        result['verse_${i + 1}'] = source[i];
      }
      return result;
    }
    data.forEach((key, value) => result[key.toString()] = value);
    return result;
  }

  bool _isBasmala(String value) {
    final normalized = value
        .replaceFirst('\uFEFF', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640\s]'), '')
        .replaceAll('ٱ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
    return normalized == 'بسماللهالرحمنالرحيم';
  }

  List<String> _extractTexts(Map<String, dynamic> data,
      {bool removeBasmala = false}) {
    final entries = data.entries.toList()
      ..sort((a, b) => _numberFromKey(a.key).compareTo(_numberFromKey(b.key)));
    final result = <String>[];
    for (final entry in entries) {
      final text = entry.value.toString().replaceFirst('\uFEFF', '').trim();
      if (text.isEmpty) continue;
      final isZeroIndex = _numberFromKey(entry.key) == 0;
      if (_isBasmala(text) && (removeBasmala || isZeroIndex)) continue;
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
      final response =
          await _loadAsset(['assets/surah/surah_${widget.surahId}.json']);
      List<String> loadedVerses = [];
      String? openingBasmala;
      if (response != null) {
        final verseMap = _extractMap(json.decode(response));
        for (final entry in verseMap.entries) {
          if (_numberFromKey(entry.key) == 0 &&
              _isBasmala(entry.value.toString())) {
            openingBasmala =
                entry.value.toString().replaceFirst('\uFEFF', '').trim();
            break;
          }
        }
        loadedVerses = _extractTexts(verseMap, removeBasmala: false);
      }
      if (loadedVerses.length != widget.versesCount) {
        throw FormatException(
          'عدد الآيات في ملف السورة (${loadedVerses.length}) لا يطابق العدد المتوقع (${widget.versesCount}).',
        );
      }
      if (!mounted) return;
      setState(() {
        verses = loadedVerses;
        _openingBasmala = openingBasmala;
        _loadError = null;
        _verseKeys
          ..clear()
          ..addAll(List.generate(loadedVerses.length, (_) => GlobalKey()));
        isLoading = false;
      });
      await _restoreLastPosition();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        verses = [];
        _openingBasmala = null;
        _verseKeys.clear();
        _loadError =
            'تعذّر تحميل آيات السورة بشكل صحيح. أعد فتح السورة أو تحقق من ملفات البيانات.';
        isLoading = false;
      });
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
      final raw = prefs.getString(kBookmarksKey);
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
      final targetVerse = widget.initialVerse ??
          (savedSurah == widget.surahId ? savedVerse : null);
      if (targetVerse != null &&
          targetVerse >= 1 &&
          targetVerse <= verses.length) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (mounted) await _scrollToVerse(targetVerse - 1);
      }
    } catch (_) {}
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kBookmarksKey, json.encode(_bookmarks));
  }

  Future<void> _addBookmark() async {
    final verse = selectedVerseIndex + 1;
    final exists = _bookmarks.any(
        (b) => b['surahId'] == widget.surahId && b['verse'] == verse);
    if (exists) {
      _showMessage('هذه الآية محفوظة مسبقاً');
      return;
    }
    setState(() {
      _bookmarks.add({
        'surahId': widget.surahId,
        'surahName': widget.surahName,
        'verse': verse,
      });
    });
    await _saveBookmarks();
    _showMessage('تم حفظ الإشارة المرجعية');
  }

  Future<void> _showBookmarks() async {
    await _loadBookmarks();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .65,
            child: Column(children: [
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('الإشارات المرجعية',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              Expanded(
                child: _bookmarks.isEmpty
                    ? const Center(child: Text('لا توجد إشارات محفوظة'))
                    : ListView.builder(
                        itemCount: _bookmarks.length,
                        itemBuilder: (_, i) {
                          final b = _bookmarks[i];
                          return ListTile(
                            leading: const Icon(Icons.bookmark,
                                color: Color(0xFF2E7D32)),
                            title: Text(
                                '${b['surahName']} - الآية ${b['verse']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                setState(() => _bookmarks.removeAt(i));
                                await _saveBookmarks();
                                if (mounted) Navigator.pop(sheetContext);
                                if (mounted) _showBookmarks();
                              },
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              if (_intValue(b['surahId']) == widget.surahId) {
                                _scrollToVerse(_intValue(b['verse']) - 1);
                              }
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showGoToVerse() async {
    final controller =
        TextEditingController(text: '${selectedVerseIndex + 1}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الذهاب إلى آية'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration:
              InputDecoration(hintText: '1 - ${verses.length}'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('انتقال')),
        ],
      ),
    );
    if (value != null && value >= 1 && value <= verses.length) {
      await _scrollToVerse(value - 1);
    } else if (value != null) {
      _showMessage('رقم الآية خارج نطاق السورة');
    }
    controller.dispose();
  }

  Future<void> _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    await SystemChrome.setEnabledSystemUIMode(
        _isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  Future<void> _toggleAudio() async {
    if (_isAudioPlaying) {
      await _audioPlayer.pause();
      return;
    }
    try {
      String audioUrl = '';
      final raw = await rootBundle
          .loadString('assets/audiourls/${widget.reciterId}.json');
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.length >= widget.surahId) {
        final item = decoded[widget.surahId - 1];
        if (item is String) {
          audioUrl = item;
        } else if (item is Map) {
          audioUrl = (item['F2'] ?? item['url'] ?? '').toString();
        }
      }
      if (audioUrl.trim().isEmpty) {
        throw StateError('لا رابط صوتي');
      }
      await _audioPlayer.setUrl(audioUrl.trim());
      await _audioPlayer.play();
    } catch (_) {
      _showMessage('تعذّر تشغيل التلاوة الصوتية لهذه السورة');
    }
  }

  Future<void> _showTafsir() async {
    final verse = selectedVerseIndex + 1;
    try {
      final raw = await rootBundle.loadString(
          'assets/tafsir/${widget.surahId}_$verse.json');
      final decoded = jsonDecode(raw);
      final text = decoded is Map
          ? (decoded['text'] ?? decoded['tafsir'] ?? '').toString()
          : decoded.toString();
      if (!mounted) return;
      _showTextSheet('تفسير الآية $verse', text);
    } catch (_) {
      _showMessage('التفسير غير متوفر لهذه الآية');
    }
  }

  Future<void> _showTajweed() async {
    final
