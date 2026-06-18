import 'package:flutter/material.dart';

class TajweedRule {
  final String name;
  final Color color;
  final String arabicName;
  final List<String> patterns;

  TajweedRule({
    required this.name,
    required this.color,
    required this.arabicName,
    required this.patterns,
  });
}

class TajweedHighlighter {
  static final List<TajweedRule> tajweedRules = [
    // القلب (Qalb)
    TajweedRule(
      name: 'Qalb',
      arabicName: 'القلب',
      color: const Color(0xFFFF6B6B),
      patterns: ['بم', 'نب'],
    ),
    // الإدغام (Idgham)
    TajweedRule(
      name: 'Idgham',
      arabicName: 'الإدغام',
      color: const Color(0xFF4ECDC4),
      patterns: ['ننـ', 'ميم', 'نن', 'لل'],
    ),
    // الإظهار (Izhar)
    TajweedRule(
      name: 'Izhar',
      arabicName: 'الإظهار',
      color: const Color(0xFFFFE66D),
      patterns: ['نح', 'نخ', 'نع', 'نغ', 'نه'],
    ),
    // الإخفاء (Ikhfa)
    TajweedRule(
      name: 'Ikhfa',
      arabicName: 'الإخفاء',
      color: const Color(0xFFBB86FC),
      patterns: ['نص', 'نس', 'نز', 'نط', 'نت', 'ند', 'نث', 'نك', 'نج', 'نش', 'نق', 'نف'],
    ),
    // الغنة (Ghunnah)
    TajweedRule(
      name: 'Ghunnah',
      arabicName: 'الغنة',
      color: const Color(0xFF95F0FF),
      patterns: ['نـــ', 'ـنـــ', 'ـمـــ', 'مـــ'],
    ),
    // الرقق (Raqq - Light)
    TajweedRule(
      name: 'Raqq',
      arabicName: 'التفخيم والترقيق',
      color: const Color(0xFF90EE90),
      patterns: ['ص', 'ض', 'ط', 'ظ'],
    ),
    // الحروف المقلقلة (Qalqalah)
    TajweedRule(
      name: 'Qalqalah',
      arabicName: 'الحروف المقلقلة',
      color: const Color(0xFFFF9999),
      patterns: ['ق', 'ط', 'ب', 'ج', 'د'],
    ),
  ];

  /// تحليل النص وتحديد قواعد التجويد
  static List<TajweedSpan> analyzeTajweed(String text) {
    List<TajweedSpan> spans = [];
    
    if (text.isEmpty) {
      return spans;
    }

    Set<int> processedIndices = {};

    for (var rule in tajweedRules) {
      for (var pattern in rule.patterns) {
        int startIndex = 0;
        while (startIndex < text.length) {
          int index = text.indexOf(pattern, startIndex);
          if (index == -1) break;

          if (!processedIndices.contains(index)) {
            spans.add(
              TajweedSpan(
                start: index,
                end: index + pattern.length,
                color: rule.color,
                ruleName: rule.arabicName,
              ),
            );
            processedIndices.add(index);
          }
          startIndex = index + 1;
        }
      }
    }

    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  /// تحويل النص إلى TextSpan مع تسطير ملون (Underline Style)
  static TextSpan applyTajweedColoring(String text, double fontSize) {
    final spans = analyzeTajweed(text);
    
    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'ahmed',
          height: 2.2,
          color: Colors.black87,
        ),
      );
    }

    List<TextSpan> textSpans = [];
    int lastIndex = 0;

    for (var span in spans) {
      // إضافة النص العادي قبل القاعدة
      if (lastIndex < span.start) {
        textSpans.add(
          TextSpan(
            text: text.substring(lastIndex, span.start),
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'ahmed',
              height: 2.2,
              color: Colors.black87,
            ),
          ),
        );
      }

      // إضافة النص مع تسطير ملون تحته
      textSpans.add(
        TextSpan(
          text: text.substring(span.start, span.end),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'ahmed',
            height: 2.2,
            color: Colors.black87,
            decoration: TextDecoration.underline,
            decorationColor: span.color,
            decorationThickness: 3.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      lastIndex = span.end;
    }

    // إضافة النص المتبقي
    if (lastIndex < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'ahmed',
            height: 2.2,
            color: Colors.black87,
          ),
        ),
      );
    }

    return TextSpan(children: textSpans);
  }

  /// الحصول على معلومات قاعدة التجويد
  static TajweedRule? getTajweedRuleByName(String name) {
    try {
      return tajweedRules.firstWhere(
        (rule) => rule.arabicName == name || rule.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  /// إرجاع جميع ألوان التجويد للإشارة (Legend)
  static List<Map<String, dynamic>> getTajweedLegend() {
    return tajweedRules
        .map((rule) => {
              'name': rule.arabicName,
              'color': rule.color,
            })
        .toList();
  }
}

class TajweedSpan {
  final int start;
  final int end;
  final Color color;
  final String ruleName;

  TajweedSpan({
    required this.start,
    required this.end,
    required this.color,
    required this.ruleName,
  });
}
