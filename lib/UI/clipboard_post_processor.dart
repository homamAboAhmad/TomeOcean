import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordPage.dart';

/// يعالج نص الحافظة بعد نسخ Flutter الافتراضي لإضافة فواصل فقرات (\n)
/// بين الفقرات، مما يحافظ على حدود الفقرات كما في مستند Word الأصلي.
///
/// المشكلة: Flutter's SelectableRegion يدمج كل الفقرات المحددة في نص
/// واحد متصل بدون فواصل. هذا الكلاس يعيد الفواصل بالبحث عن نص الحافظة
/// داخل النص المعروض لكل فقرة وإدراج \n عند حدود الفقرات.
class ClipboardPostProcessor {
  ClipboardPostProcessor._();

  /// يُنفّذ بعد نسخ Flutter الافتراضي (من قائمة السياق أو Ctrl+C)
  /// لإضافة فواصل فقرات بين الفقرات المحددة.
  ///
  /// الخوارزمية:
  /// 1. يقرأ نص الحافظة الذي وضعه Flutter
  /// 2. يجلب النص المعروض لكل فقرة مرئية من [WordPage]
  /// 3. يُطبّع كلا النصين (يطبّع = يزيل الاختلافات مثل رموز PUA و\t)
  /// 4. يبحث عن نص الحافظة المُطبّع داخل النص المُطبّع الكامل
  /// 5. يُقسّم نص الحافظة الأصلي عند حدود الفقرات مع إدراج \n
  static Future<String> postProcessClipboard(WordPage wordPage) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final flutterText = clipboardData?.text ?? '';
    if (flutterText.isEmpty) return '';

    // إزالة \uFFFC (عنصر WidgetSpan)
    final stripped = flutterText.replaceAll('\uFFFC', '');
    if (stripped.trim().isEmpty) return '';

    // النص المعروض لكل فقرة مرئية
    final renderedTexts = wordPage.getVisibleRenderedTexts();
    if (renderedTexts.isEmpty) {
      await Clipboard.setData(ClipboardData(text: stripped));
      return stripped;
    }

    // تطبيع كلا النصين للمطابقة
    final normTexts = renderedTexts.map(_normalizeForMatch).toList();
    final flatNorm = normTexts.join('');
    final clipNorm = _normalizeForMatch(stripped);

    // البحث عن نص الحافظة المُطبّع داخل النص المُطبّع الكامل
    final matchStart = flatNorm.indexOf(clipNorm);
    if (matchStart < 0) {
      await Clipboard.setData(ClipboardData(text: stripped));
      return stripped;
    }
    final matchEnd = matchStart + clipNorm.length;

    // بناء خريطة من مواضع clipNorm → مواضع stripped
    // (لأن التطبيع يحذف أحرف من stripped، نحتاج خريطة لإرجاع المواضع)
    final normToClipPos = _buildNormToSourceMap(stripped);

    // تقسيم نص الحافظة عند حدود الفقرات
    final parts = <String>[];
    int normPos = 0;

    for (int p = 0; p < renderedTexts.length; p++) {
      final normLen = normTexts[p].length;
      final paraNormStart = normPos;
      final paraNormEnd = normPos + normLen;

      if (paraNormEnd <= matchStart || paraNormStart >= matchEnd) {
        normPos = paraNormEnd;
        continue;
      }

      // حساب التداخل بنسبي clipNorm
      final overlapStartCN =
          (matchStart > paraNormStart ? matchStart : paraNormStart) -
              matchStart;
      final overlapEndCN =
          (matchEnd < paraNormEnd ? matchEnd : paraNormEnd) - matchStart;

      // تحويل المواضع المُطبّعة إلى مواضع أصلية في stripped
      if (overlapStartCN < normToClipPos.length &&
          overlapEndCN < normToClipPos.length) {
        final clipStart = normToClipPos[overlapStartCN];
        final clipEnd = normToClipPos[overlapEndCN];
        parts.add(stripped.substring(clipStart, clipEnd));
      }

      normPos = paraNormEnd;
    }

    if (parts.isEmpty) {
      await Clipboard.setData(ClipboardData(text: stripped));
      return stripped;
    }

    final result = parts.join('\n');
    await Clipboard.setData(ClipboardData(text: result));
    return result;
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
