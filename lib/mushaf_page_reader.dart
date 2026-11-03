import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// قارئ صفحات مصحف المدينة المنورة (604 صفحة).
/// يعرض صفحات المصدر كما هي دون إعادة تشكيل النص القرآني بخطوط النظام.
class MushafPageReader extends StatefulWidget {
  final int? initialPage;
  const MushafPageReader({super.key, this.initialPage});

  @override
  State<MushafPageReader> createState() => _MushafPageReaderState();
}

class _MushafPageReaderState extends State<MushafPageReader> {
  static const _green = Color(0xFF174D35);
  static const _gold = Color(0xFFD6B45C);
  static const _pageCount = 604;
  static const _lastPageKey = 'mushaf_last_page_v1';
  static const _bookmarksKey = 'mushaf_page_bookmarks_v1';

  final TransformationController _zoomController = TransformationController();
  final TextEditingController _pageInputController = TextEditingController();
  List<Map<String, dynamic>> _pages = [];
  Set<int> _bookmarks = {};
  int _page = 1;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> get _current => _pages[_page - 1];
  Map<String, dynamic> get _start => Map<String, dynamic>.from(_current['start'] as Map);
  Map<String, dynamic> get _end => Map<String, dynamic>.from(_current['end'] as Map);

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _pageInputController.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    try {
      final raw = await rootBundle.loadString('assets/mushaf/pages.json');
      final decoded = jsonDecode(raw) as List;
      final pages = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (pages.length != _pageCount) {
        throw FormatException('عدد صفحات الفهرس ${pages.length} وليس $_pageCount');
      }
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_lastPageKey) ?? 1;
      final rawBookmarks = prefs.getStringList(_bookmarksKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _bookmarks = rawBookmarks.map(int.tryParse).whereType<int>().where((p) => p >= 1 && p <= _pageCount).toSet();
        _page = (widget.initialPage ?? saved).clamp(1, _pageCount).toInt();
        _loading = false;
      });
      _saveLastPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل فهرس صفحات المصحف: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPageKey, _page);
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_bookmarksKey, _bookmarks.map((e) => e.toString()).toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b))));
  }

  void _goToPage(int value) {
    final target = value.clamp(1, _pageCount).toInt();
    if (target == _page) return;
    setState(() => _page = target);
    _zoomController.value = Matrix4.identity();
    _saveLastPage();
  }

  void _step(int amount) {
    if (_page + amount >= 1 && _page + amount <= _pageCount) {
      _goToPage(_page + amount);
    }
  }

  Future<void> _toggleBookmark() async {
    setState(() {
      if (!_bookmarks.add(_page)) _bookmarks.remove(_page);
    });
    await _saveBookmarks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_bookmarks.contains(_page) ? 'تم حفظ الصفحة في الإشارات المرجعية' : 'تم حذف الإشارة المرجعية'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _showGoToPage() async {
    _pageInputController.text = _page.toString();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: TextField(
          controller: _pageInputController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'رقم الصفحة (1–604)', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(_pageInputController.text)), child: const Text('انتقال')),
        ],
      ),
    );
    if (value != null) _goToPage(value);
  }

  Future<void> _showBookmarks() async {
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد إشارات مرجعية بعد')));
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 12), child: Text('الإشارات المرجعية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ...(_bookmarks.toList()..sort()).map((p) => ListTile(
              leading: const Icon(Icons.bookmark, color: _green),
              title: Text('صفحة $p'),
              subtitle: Text(_pageRangeLabel(_pages[p - 1])),
              onTap: () => Navigator.pop(context, p),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                setState(() => _bookmarks.remove(p));
                await _saveBookmarks();
                if (context.mounted) Navigator.pop(context);
              }),
            )),
          ],
        ),
      ),
    );
    if (selected != null) _goToPage(selected);
  }

  Future<void> _showSurahPicker() async {
    // يُستخرج فهرس السور من نقاط بداية السور داخل بيانات الصفحات.
    final starts = <Map<String, dynamic>>[];
    for (final p in _pages) {
      final start = Map<String, dynamic>.from(p['start'] as Map);
      if ((start['verse'] as num?)?.toInt() == 1) starts.add({'surah': (start['surah_number'] as num).toInt(), 'name': (start['name'] as Map)['ar'] ?? '', 'page': (p['page'] as num).toInt()});
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: starts.length,
          itemBuilder: (context, i) {
            final s = starts[i];
            return ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFE8F0EA), foregroundColor: _green, child: Text('${s['surah']}')),
              title: Text(s['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('صفحة ${s['page']}'),
              onTap: () => Navigator.pop(context, s['page'] as int),
            );
          },
        ),
      ),
    );
    if (selected != null) _goToPage(selected);
  }

  String _pageRangeLabel(Map<String, dynamic> page) {
    final a = Map<String, dynamic>.from(page['start'] as Map);
    final b = Map<String, dynamic>.from(page['end'] as Map);
    final an = (a['name'] as Map)['ar'] ?? '';
    final bn = (b['name'] as Map)['ar'] ?? '';
    final av = a['verse'];
    final bv = b['verse'];
    if (a['surah_number'] == b['surah_number']) return '$an • الآيات $av–$bv';
    return '$an ($av) – $bn ($bv)';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2EBDD),
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text('مصحف المدينة • 604 صفحة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(tooltip: 'الإشارات المرجعية', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
            IconButton(tooltip: 'حفظ الصفحة', onPressed: _loading ? null : _toggleBookmark, icon: Icon(_bookmarks.contains(_page) ? Icons.bookmark : Icons.bookmark_border)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : Column(
                    children: [
                      Container(
                        color: const Color(0xFFE7E0D1),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Expanded(child: Text(_pageRangeLabel(_current), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _green, fontWeight: FontWeight.w600))),
                            TextButton.icon(onPressed: _showSurahPicker, icon: const Icon(Icons.list_alt, size: 18), label: const Text('السور')),
                            TextButton.icon(onPressed: _showGoToPage, icon: const Icon(Icons.numbers, size: 18), label: const Text('صفحة')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AspectRatio(
                              aspectRatio: 1024 / 1656,
                              child: Material(
                                elevation: 3,
                                color: Colors.white,
                                child: InteractiveViewer(
                                  transformationController: _zoomController,
                                  minScale: 1,
                                  maxScale: 4,
                                  child: Image.asset(
                                    'assets/mushaf/pages/$_page.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stack) => Center(child: Text('تعذّر تحميل صورة الصفحة $_page\n$error', textAlign: TextAlign.center)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color: _green,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              IconButton(onPressed: _page > 1 ? () => _step(-1) : null, color: Colors.white, disabledColor: Colors.white30, icon: const Icon(Icons.chevron_right, size: 32)),
                              Expanded(
                                child: InkWell(
                                  onTap: _showGoToPage,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$_page من $_pageCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 5),
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: _page / _pageCount, minHeight: 4, backgroundColor: Colors.white24, color: _gold)),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(onPressed: _page < _pageCount ? () => _step(1) : null, color: Colors.white, disabledColor: Colors.white30, icon: const Icon(Icons.chevron_left, size: 32)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
