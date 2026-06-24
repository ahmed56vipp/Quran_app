import 'package:flutter/material.dart';
import 'surah_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true, // تفعيل سمات Material 3 الحديثة تلقائياً
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
          background: const Color(0xFFFDFBF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
      ),
      home: const SurahListScreen(),
    );
  }
}
