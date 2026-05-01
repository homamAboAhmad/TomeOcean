import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/RichClipboardBuilder.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// نتيجة مطابقة الفقرات المحددة في الحافظة.
class _MatchResult {
  final List<String> parts;
  final List<Paragraph> paragraphs;
  const _MatchResult(this.parts, this.paragraphs);
}

/// يعالج نص الحافظة بعد نسخ Flutter الافتراضي لإضافة فواصل فقرات (\n)
/// بين الفقرات، مما يحافظ على حدود الفقرات كما في مستند Word الأصلي.
///
/// المشكلة: Flutter's SelectableRegion يدمج كل الفقرات المحددة في نص
/// واحد متصل بدون فواصل. هذا الكلاس يعيد الفواصل بالبحث عن نص الحافظة
/// داخل النص المعروض لكل فقرة وإدراج \n عند حدود الفقرات.
class ClipboardPostProcessor {
  ClipboardPostProcessor._();

  /// يُنفّذ بعد نسخ Flutter الافتراضي لإضافة فواصل فقرات بين الفقرات المحددة.
  static Future<String> postProcessClipboard(WordPage wordPage) async {
    final result = await _matchSelectedParagraphs(wordPage);
    if (result == null) return '';

    final plainText = result.parts.join('\n');
    await Clipboard.setData(ClipboardData(text: plainText));
    return plainText;
  }

  /// نسخ مع التنسيق: يضع نصًا عاديًا + HTML على الحافظة.
  /// عند اللصق في Word أو محررات أخرى يُحافظ على التنسيق.
  static Future<String> postProcessClipboardRich(WordPage wordPage) async {
    final result = await _matchSelectedParagraphs(wordPage);
    if (result == null) return '';

    final plainText = result.parts.join('\n');
    final htmlText = result.paragraphs.isNotEmpty
        ? RichClipboardBuilder.buildHtmlFromParagraphs(result.paragraphs)
        : '';

    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.htmlText(htmlText));
        item.add(Formats.plainText(plainText));
        await clipboard.write([item]);
      } else {
        await Clipboard.setData(ClipboardData(text: plainText));
      }
    } catch (e) {
      print('RichClipboard: super_clipboard failed: $e');
      await Clipboard.setData(ClipboardData(text: plainText));
    }

    return plainText;
  }

  /// يطابق نص الحافظة مع الفقرات المرئية ويعيد أجزاء النص العادي
  /// وكائنات الفقرات المحددة.
  ///
  /// الخوارزمية:
  /// 1. يقرأ نص الحافظة الذي وضعه Flutter
  /// 2. يجلب النص المعروض لكل فقرة مرئية من [WordPage]
  /// 3. يُطبّع كلا النصين (يزيل الاختلافات مثل رموز PUA و\t)
  /// 4. يبحث عن نص الحافظة المُطبّع داخل النص المُطبّع الكامل
  /// 5. يُقسّم نص الحافظة الأصلي عند حدود الفقرات مع إدراج \n
  static Future<_MatchResult?> _matchSelectedParagraphs(
      WordPage wordPage) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final flutterText = clipboardData?.text ?? '';
    if (flutterText.isEmpty) return null;

    final stripped = flutterText.replaceAll('\uFFFC', '');
    if (stripped.trim().isEmpty) return null;

    final renderedTexts = wordPage.getVisibleRenderedTexts();
    final visibleParagraphs = wordPage.getVisibleParagraphs();

    if (renderedTexts.isEmpty || visibleParagraphs.isEmpty) {
      return _MatchResult([stripped], []);
    }

    final normTexts = renderedTexts.map(_normalizeForMatch).toList();
    final flatNorm = normTexts.join('');
    final clipNorm = _normalizeForMatch(stripped);

    final matchStart = flatNorm.indexOf(clipNorm);
    if (matchStart < 0) return _MatchResult([stripped], []);
    final matchEnd = matchStart + clipNorm.length;

    final normToClipPos = _buildNormToSourceMap(stripped);
    final parts = <String>[];
    final selectedParagraphs = <Paragraph>[];
    int normPos = 0;

    for (int p = 0; p < renderedTexts.length; p++) {
      final normLen = normTexts[p].length;
      final paraNormStart = normPos;
      final paraNormEnd = normPos + normLen;

      if (paraNormEnd <= matchStart || paraNormStart >= matchEnd) {
        normPos = paraNormEnd;
        continue;
      }

      if (p < visibleParagraphs.length) {
        selectedParagraphs.add(visibleParagraphs[p]);
      }

      final overlapStartCN =
          (matchStart > paraNormStart ? matchStart : paraNormStart) -
              matchStart;
      final overlapEndCN =
          (matchEnd < paraNormEnd ? matchEnd : paraNormEnd) - matchStart;

      if (overlapStartCN < normToClipPos.length &&
          overlapEndCN < normToClipPos.length) {
        final clipStart = normToClipPos[overlapStartCN];
        final clipEnd = normToClipPos[overlapEndCN];
        parts.add(stripped.substring(clipStart, clipEnd));
      }

      normPos = paraNormEnd;
    }

    if (parts.isEmpty) return _MatchResult([stripped], []);
    return _MatchResult(parts, selectedParagraphs);
  }

  /// يُطبّع النص للمطابقة: يزيل الأحرف التي تختلف بين حافظة Flutter
  /// ونصنا المعروض، ويستبدل المسافة غير المنقسمة بمسافة عادية.
  ///
  /// الاختلافات المعالجة:
  /// - Private Use Area (U+E000–F8FF): رموز w:sym تظهر في نصنا لكن
  ///   Flutter يستبدلها بـ WidgetSpan في الحافظة
  /// - \t (U+0009): لاحقة الترقيم (numbering suffix)
  /// - \uFFFC: عنصر استبدال WidgetSpan
  /// - \u00A0 → مسافة عادية: مسافة غير منقسمة
  static String _normalizeForMatch(String s) {
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 0xE000 && code <= 0xF8FF) continue;
      if (code == 0x09) continue;
      if (code == 0xFFFC) continue;
      if (code == 0xA0) {
        buf.write(' ');
        continue;
      }
      buf.writeCharCode(code);
    }
    return buf.toString();
  }

  /// يبني خريطة من مواضع النص المُطبّع إلى مواضع النص الأصلي.
  /// كل عنصر في القائمة هو موضع في [source] يقابل موضع في النص المُطبّع.
  /// العنصر الأخير هو sentinel (طول source).
  static List<int> _buildNormToSourceMap(String source) {
    final map = <int>[];
    for (int i = 0; i < source.length; i++) {
      final code = source.codeUnitAt(i);
      final isSkipped = (code >= 0xE000 && code <= 0xF8FF) ||
          code == 0x09 ||
          code == 0xFFFC;
      if (!isSkipped) map.add(i);
    }
    map.add(source.length);
    return map;
  }
}
