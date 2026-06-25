import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'dart:async';
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
  List<dynamic> juzData = [];
  bool isLoading = true;
  int currentJuz = 1;
  
  // التحكم في الشاشة والتمرير الآلي
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 0.1; 

  // إدارة الصوتيات
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();
  bool isPlaying = false;
  int? activeVerseIndex; 
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  double _fontSize = 24.0;
  int _themeMode = 0; // 0: فاتح، 1: دافئ، 2: ليلي

  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool isAudioDownloaded = false;

  final List<Map<String, String>> reciters = [
    {"name": "عبد الباسط عبد الصمد", "server": "https://server7.mp3quran.net/basit/"},
    {"name": "مشاري راشد العفاسي", "server": "https://server8.mp3quran.net/afs/"},
    {"name": "محمد صديق المنشاوي", "server": "https://server10.mp3quran.net/minsh/"},
    {"name": "سعد الغامدي", "server": "https://server7.mp3quran.net/s_gmd/"},
    {"name": "أحمد بن علي العجمي", "server": "https://server11.mp3quran.net/ajm/"},
    {"name": "أبو بكر الشاطري", "server": "https://server11.mp3quran.net/shatri/"},
  ];
  int selectedReciterIndex = 3; 

  @override
  void initState() {
    super.initState();
    currentJuz = widget.initialJuz;
    _loadData();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            isPlaying = false;
            activeVerseIndex = null;
          }
        });
      }
    });

    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _dio.close();
    super.dispose();
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.position.pixels;
          
          if (currentScroll >= maxScroll) {
            timer.cancel();
            setState(() => _isAutoScrolling = false);
          } else {
            _scrollController.jumpTo(currentScroll + (_scrollSpeed * 5));
          }
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  Future<void> _checkAudioFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String folderName = reciters[selectedReciterIndex]['name']!;
      final String fileName = "${widget.surahId.toString().padLeft(3, '0')}.mp3";
      final file = File('${directory.path}/audio/$folderName/$fileName');
      
      setState(() {
        isAudioDownloaded = file.existsSync();
      });
    } catch (_) {}
  }

  Future<void> _downloadAudio(StateSetter setModalState) async {
    setModalState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final String folderName = reciters[selectedReciterIndex]['name']!;
      final String fileName = "${widget.surahId.toString().padLeft(3, '0')}.mp3";
      
      final saveDir = Directory('${directory.path}/audio/$folderName');
      if (!saveDir.existsSync()) {
        saveDir.createSync(recursive: true);
      }

      final String savePath = '${saveDir.path}/$fileName';
      final String audioUrl = "${reciters[selectedReciterIndex]['server']}${widget.surahId.toString().padLeft(3, '0')}.mp3";

      await _dio.download(
        audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setModalState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      setModalState(() {
        isDownloading = false;
        isAudioDownloaded = true;
      });
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تحميل سورة ${widget.surahName} بنجاح!"), backgroundColor: const Color(0xFF2E7D32)),
      );
    } catch (e) {
      setModalState(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل التحميل، يرجى التحقق من الاتصال"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleAudio() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String folderName = reciters[selectedReciterIndex]['name']!;
        final String fileName = "${widget.surahId.toString().padLeft(3, '0')}.mp3";
        final String localPath = '${directory.path}/audio/$folderName/$fileName';

        if (File(localPath).existsSync()) {
          await _audioPlayer.setFilePath(localPath);
        } else {
          final String audioUrl = "${reciters[selectedReciterIndex]['server']}${widget.surahId.toString().padLeft(3, '0')}.mp3";
          await _audioPlayer.setUrl(audioUrl);
        }
        await _audioPlayer.play();
        if (activeVerseIndex == null) activeVerseIndex = 0;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطأ في تشغيل الصوت"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadData() async {
    try {
      await _checkAudioFile();
      final String juzResponse = await rootBundle.loadString('assets/data/juz.json');
      juzData = json.decode(juzResponse);

      final String response = await rootBundle.loadString('assets/surah/surah_${widget.surahId}.json');
      final data = json.decode(response);
      final Map<String, dynamic> verseMap = data['verse'];
      
      List<String> loadedVerses = [];
      for (int i = 0; i < verseMap.length; i++) {
        if (verseMap.containsKey('verse_$i')) {
          String text = verseMap['verse_$i'].toString().trim();
          
          if (widget.surahId != 1 && widget.surahId != 9 && i == 0) {
            final RegExp basmalahRegExp = RegExp(
              r'^بِسْمِ\s+اللَّهِ\s+الرَّحْمَٰنِ\s+الرَّحِيمِ\s*',
              caseSensitive: false,
            );
            text = text.replaceFirst(basmalahRegExp, "").trim();
          }
          loadedVerses.add(text);
        }
      }

      setState(() {
        verses = loadedVerses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        verses = List.generate(widget.versesCount, (index) => "الآية الكريمة رقم ${index + 1}");
        isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String loveSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$loveSeconds";
  }

  Color _getBackgroundColor() {
    if (_themeMode == 1) return const Color(0xFFFBF7EE);
    if (_themeMode == 2) return const Color(0xFF121212);
    return Colors.white;
  }

  Color _getTextColor() {
    if (_themeMode == 2) return Colors.white;
    return const Color(0xFF2C3E50);
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _themeMode == 2;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 10),
                    Text("حجم خط القراءة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    Slider(
                      value: _fontSize, min: 20, max: 40, divisions: 10,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        setModalState(() => _fontSize = v);
                      },
                    ),
                    const Divider(),
                    Text("وضع العرض والوضوح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(label: const Text("فاتح"), selected: _themeMode == 0, onSelected: (s) { setState(() => _themeMode = 0); setModalState(() {}); }),
                        ChoiceChip(label: const Text("دافئ"), selected: _themeMode == 1, onSelected: (s) { setState(() => _themeMode = 1); setModalState(() {}); }),
                        ChoiceChip(label: const Text("ليلي"), selected: _themeMode == 2, onSelected: (s) { setState(() => _themeMode = 2); setModalState(() {}); }),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("التمرير الآلي ذكي (أثناء القراءة):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _isAutoScrolling ? Colors.red : const Color(0xFF2E7D32)),
                          onPressed: () {
                            _toggleAutoScroll();
                            setModalState(() {});
                          },
                          icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          label: Text(_isAutoScrolling ? "إيقاف" : "تشغيل", style: const TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                    Slider(
                      value: _scrollSpeed, min: 0.1, max: 1.0, divisions: 9,
                      activeColor: Colors.orange,
                      label: "السرعة: $_scrollSpeed",
                      onChanged: (v) {
                        setModalState(() => _scrollSpeed = v);
                        setState(() => _scrollSpeed = v);
                        if (_isAutoScrolling) {
                          _scrollTimer?.cancel();
                          _isAutoScrolling = false;
                          _toggleAutoScroll();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAudioPlayerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _themeMode == 2 ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 20),
                    Text(
                      "الاستماع الصوتي لسورة ${widget.surahName}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _themeMode == 2 ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<int>(
                      value: selectedReciterIndex,
                      dropdownColor: _themeMode == 2 ? const Color(0xFF222222) : Colors.white,
                      style: TextStyle(color: _themeMode == 2 ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: "اختر القارئ",
                        labelStyle: TextStyle(color: _themeMode == 2 ? Colors.white70 : Colors.black54),
                        border: const OutlineInputBorder(),
                      ),
                      items: List.generate(reciters.length, (idx) => DropdownMenuItem(value: idx, child: Text(reciters[idx]['name']!))),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedReciterIndex = val);
                          setModalState(() {});
                          _checkAudioFile();
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position), style: TextStyle(color: _themeMode == 2 ? Colors.white70 : Colors.black54, fontFamily: 'quran_num')),
                        Expanded(
                          child: Slider(
                            activeColor: const Color(0xFF2E7D32),
                            inactiveColor: Colors.grey[300],
                            min: 0.0,
                            max: _duration.inMilliseconds.toDouble(),
                            value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                            onChanged: (value) {
                              _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Text(_formatDuration(_duration), style: TextStyle(color: _themeMode == 2 ? Colors.white70 : Colors.black54, fontFamily: 'quran_num')),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Color(0xFF2E7D32), size: 36),
                          onPressed: () {
                            if (activeVerseIndex != null && activeVerseIndex! < verses.length - 1) {
                              setState(() => activeVerseIndex = activeVerseIndex! + 1);
                            }
                          },
                        ),
                        const SizedBox(width: 15),
                        isDownloading
                            ? SizedBox(width: 50, height: 50, child: CircularProgressIndicator(value: downloadProgress, color: const Color(0xFF2E7D32)))
                            : (!isAudioDownloaded
                                ? FloatingActionButton.extended(
                                    backgroundColor: Colors.orange,
                                    onPressed: () => _downloadAudio(setModalState),
                                    icon: const Icon(Icons.cloud_download, color: Colors.white),
                                    label: const Text("تحميل دون اتصال", style: TextStyle(color: Colors.white)),
                                  )
                                : FloatingActionButton(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    onPressed: () async {
                                      await _toggleAudio();
                                      setModalState(() {});
                                    },
                                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30),
                                  )),
                        const SizedBox(width: 15),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Color(0xFF2E7D32), size: 36),
                          onPressed: () {
                            if (activeVerseIndex != null && activeVerseIndex! > 0) {
                              setState(() => activeVerseIndex = activeVerseIndex! - 1);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
          },
        );
      },
    ); 
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _getBackgroundColor(),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "سُورَةُ ${widget.surahId == 2 ? 'البَقَرَةِ' : widget.surahName}",
                    style: const TextStyle(fontFamily: 'nam', fontSize: 24, color: Color(0xFFFFFFD700), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "آياتها: ${widget.versesCount}", 
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$currentJuz", 
                    style: const TextStyle(fontFamily: 'jzu12', fontSize: 22, color: Color(0xFFFFFFD700), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    onPressed: _showSettingsBottomSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.headset, color: Colors.white),
                    onPressed: _showAudioPlayerDialog,
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
              gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
            ),
          ),
          elevation: 2,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Column(
                  children: [
                    if (widget.surahId != 1 && widget.surahId != 9) ...[
                      const Center(
                        child: Text(
                          "1", 
                          style: TextStyle(fontFamily: 'bsm60', fontSize: 55, color: Color(0xFF2E7D32)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    RichText(
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                      text: TextSpan(
                        children: List.generate(verses.length, (index) {
                          final bool isCurrentActive = isPlaying && activeVerseIndex == index;

                          return TextSpan(
                            children: [
                              TextSpan(
                                text: "${verses[index]} ",
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  fontFamily: 'nss', 
                                  color: isCurrentActive ? const Color(0xFF2E7D32) : _getTextColor(),
                                  fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                                  backgroundColor: isCurrentActive ? const Color(0xFFE8F5E9).withOpacity(0.5) : Colors.transparent,
                                ),
                              ),
                              TextSpan(
                                text: " ${index + 1} ", 
                                style: const TextStyle(fontFamily: 'quran_num', fontSize: 22, color: Color(0xFFC19A6B)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
      }
