class SurahDetailsScreen extends StatefulWidget {
  final Map surah;
  const SurahDetailsScreen({super.key, required this.surah});

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  List verses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSurahContent();
  }

  Future<void> loadSurahContent() async {
    // جلب رقم السورة (يجب أن يكون 'index' مطابقاً لاسم الملف)
    String index = widget.surah['index']; 
    // التخلص من الأصفار الزائدة إذا كانت موجودة في رقم السورة (مثلاً "001" تصبح "1")
    String fileName = int.parse(index).toString(); 
    
    final String response = await rootBundle.loadString('assets/$fileName.json');
    final data = await json.decode(response);
    
    setState(() {
      // بناءً على ملفات quranjson التي حملتها، الآيات تكون في مفتاح 'verse' أو قائمة مباشرة
      verses = data is Map ? data['verse'] : data; 
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.surah['titleAr'])),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  "${verses[index]}", 
                  style: const TextStyle(fontSize: 22, fontFamily: 'Uthmanic'),
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
    );
  }
}
