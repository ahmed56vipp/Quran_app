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

  // دالة جلب البيانات مع دعم الهيكل المتداخل
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
        Map<String, dynamic> targetMap = {};
        if (parsedText.containsKey('verse') && parsedText['verse'] is Map) {
          targetMap = parsedText['verse'] as Map<String, dynamic>;
        } else {
          targetMap = parsedText as Map<String, dynamic>;
        }

        targetMap.forEach((key, value) {
          String cleanKey = key.toString();
          if (!cleanKey.startsWith('verse_') && cleanKey != '0') {
            localVersesMap['verse_$cleanKey'] = value;
          } else {
            localVersesMap[cleanKey] = value;
          }
          String rawNum = cleanKey.replaceAll('verse_', '');
          localVersesMap[rawNum] = value;
        });
      } else if (parsedText is List) {
        if (parsedText.length == widget.versesCount) {
          for (int i = 0; i < parsedText.length; i++) {
            localVersesMap['verse_${i + 1}'] = parsedText[i].toString();
            localVersesMap['${i + 1}'] = parsedText[i].toString();
          }
        } else {
          for (int i = 0; i < parsedText.length; i++) {
            localVersesMap['verse_$i'] = parsedText[i].toString();
            localVersesMap['$i'] = parsedText[i].toString();
          }
        }
      }

      setState(() {
        _versesMap = localVersesMap;
      });

    } catch (e) {
      debugPrint("خطأ أثناء جلب آيات السورة: $e");
      setState(() {
        _versesMap = {'verse_0': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'};
      });
    }
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

  void _jumpToVerseAction(int targetVerse) {
    final targetContext = _verseKeys[targetVerse].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    } else {
      double maxScroll = _scrollController.position.maxScrollExtent;
      double estimatedOffset = (targetVerse / widget.versesCount) * maxScroll;
      _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    }
  }

  // التبويب الموحد والشامل لجميع الإضافات والميزات العائمة ⛓️‍💥🔂
  void _showUnifiedSettingsPanel() {
    final TextEditingController dialogTextController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Color sheetBg = _isNightMode ? const Color(0xFF1E1E1E) : (_isEyeProtection ? const Color(0xFFEFE5CD) : Colors.white);
            Color textCol = _isNightMode ? Colors.white : (_isEyeProtection ? const Color(0xFF3E2723) : const Color(0xFF1A1A1A));
            
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: textCol.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Center(
                      child: Text(
                        "خيارات التحكم والإضافات ⛓️‍💥🔂",
                        style: TextStyle(fontFamily: 'ahmed', fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
                      ),
                    ),
                    const Divider(height: 25),

                    // 1. قسم الانتقال المباشر للآيات
                    Text("انتقال سريع لآية:", style: TextStyle(fontFamily: 'ahmed', fontWeight: FontWeight.bold, color: textCol, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dialogTextController,
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
                            final int? target = int.tryParse(dialogTextController.text);
                            if (target != null && target > 0 && target <= widget.versesCount) {
                              Navigator.pop(context);
                              _jumpToVerseAction(target);
                            }
                          },
                          child: const Text("ذهاب", style: TextStyle(fontFamily: 'ahmed', color: Colors.white)),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. قسم أوضاع الرؤية (المظهر)
                    Text("أوضاع القراءة وحماية العين:", style: TextStyle(fontFamily: 'ahmed', fontWeight: FontWeight.bold, color: textCol, fontSize: 14)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.dark_mode, color: textCol),
                            const SizedBox(width: 8),
                            Text("الوضع الليلي", style: TextStyle(fontFamily: 'ahmed', color: textCol)),
                          ],
                        ),
                        Switch(
                          value: _isNightMode,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: (val) {
                            setState(() {
                              _isNightMode = val;
                              if (_isNightMode) _isEyeProtection = false;
                            });
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility, color: textCol),
                            const SizedBox(width: 8),
                            Text("وضع حماية العين (الدافئ)", style: TextStyle(fontFamily: 'ahmed', color: textCol)),
                          ],
                        ),
                        Switch(
                          value: _isEyeProtection,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: (val) {
                            setState(() {
                              _isEyeProtection = val;
                              if (_isEyeProtection) _isNightMode = false;
                            });
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 3. قسم حجم الخط
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("حجم خط الآيات الكريمة:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: textCol, size: 26),
                              onPressed: () {
                                if (_currentFontSize > 18) {
                                  setState(() => _currentFontSize -= 2);
                                  setModalState(() {});
                                }
                              },
                            ),
                            Text("${_currentFontSize.toInt()}", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: textCol, size: 26),
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

                    // 4. قسم التمرير التلقائي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("تشغيل التمرير التلقائي للأعلى:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
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
                      Row(
                        children: [
                          Text("سرعة التدفق:", style: TextStyle(fontFamily: 'ahmed', color: textCol, fontSize: 12)),
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
                    const SizedBox(height: 10),
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
      if (juz['verse'] != null && juz['verse']['start'] != null && juz['verse']['end'] != null) {
        final startStr = juz['verse']['start'].toString().replaceAll('verse_', '');
        final endStr = juz['verse']['end'].toString().replaceAll('verse_', '');
        
        int start = int.tryParse(startStr) ?? 1;
        int end = int.tryParse(endStr) ?? widget.versesCount;
        
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

    final String currentJuz = _getDynamicJuzNumber();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
                style: TextStyle(
                  fontFamily: 'ahmed',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.70),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'تبويب التحكم والإضافات',
              onPressed: _showUnifiedSettingsPanel,
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
                          _versesMap?['verse_0'] ?? _versesMap?['0'] ?? "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
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

                    final String verseText = _versesMap?['verse_$index'] ?? _versesMap?['$index'] ?? '';

                    return Container(
                      key: _verseKeys[index],
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: textColor.withOpacity(0.05), width: 0.5),
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
