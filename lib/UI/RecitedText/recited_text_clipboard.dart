import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/UI/Settings/app_recited_text_copy_settings.dart';
import 'package:super_clipboard/super_clipboard.dart';

class RecitedTextClipboard {
  RecitedTextClipboard._();

  static Future<void> setFormatted({
    required String plainText,
    required String bodyText,
    required String reference,
    required RecitedTextFontOption fontOption,
    String? tafsirTitle,
    String? tafsirText,
  }) async {
    final html = _html(
      bodyText: bodyText,
      reference: reference,
      fontOption: fontOption,
      tafsirTitle: tafsirTitle,
      tafsirText: tafsirText,
    );
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) throw StateError('No system clipboard');
      final item = DataWriterItem();
      item.add(Formats.htmlText(html));
      item.add(Formats.plainText(plainText));
      await clipboard.write([item]);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: plainText));
    }
  }

  static String _html({
    required String bodyText,
    required String reference,
    required RecitedTextFontOption fontOption,
    String? tafsirTitle,
    String? tafsirText,
  }) {
    final settings = RecitedTextCopySettings.instance.draft();
    final bodyFamily = _bodyFontFamily(fontOption);
    final bodyFontCss = _fontCss(bodyFamily);
    final bodySize = _bodyFontSize(fontOption, settings);
    final ref = settings.referenceFont;
    final refFamily = ref.fontFamily.isEmpty ? 'Traditional Arabic' : ref.fontFamily;
    final refFontCss = _fontCss(refFamily);
    final refWeight = AppUiFonts.weightFor(ref.styleName) == FontWeight.bold ? 'bold' : 'normal';
    final refStyle = AppUiFonts.fontStyleFor(ref.styleName) == FontStyle.italic ? 'italic' : 'normal';
    final refHtml = reference.trim().isEmpty
        ? ''
        : ' <span style="font-family:$refFontCss;mso-bidi-font-family:$refFontCss;font-size:${ref.fontSize}pt;font-weight:$refWeight;font-style:$refStyle;">'
            '[${_escape(reference)}]</span>';
    final extra = tafsirText == null || tafsirText.trim().isEmpty
        ? ''
        : '<p style="direction:rtl;text-align:right;font-size:14pt;">'
            '<b>${_escape(tafsirTitle ?? '')}</b><br>${_escape(tafsirText)}</p>';
    return '<!DOCTYPE html><html><head><meta charset="utf-8"></head>'
        '<body dir="rtl" style="direction:rtl;text-align:right;">'
        '<p style="direction:rtl;text-align:right;">'
        '<span style="font-family:$bodyFontCss;mso-bidi-font-family:$bodyFontCss;font-size:${bodySize}pt;">${_escape(bodyText)}</span>'
        '$refHtml</p>$extra</body></html>';
  }

  static String _bodyFontFamily(RecitedTextFontOption option) {
    if (option.fontFamily == 'recited_complex') return 'KFGQPC HafsEx1 Uthmanic Script';
    if (option.fontFamily == 'recited_amiri') return 'Amiri';
    return 'Traditional Arabic';
  }

  static double _bodyFontSize(RecitedTextFontOption option, RecitedTextCopyDraft settings) {
    if (option.fontFamily == 'recited_complex') return settings.complexFontSize;
    if (option.fontFamily == 'recited_amiri') return settings.amiriFontSize;
    return settings.referenceFont.fontSize;
  }

  static String _fontCss(String family) => family.split(',').map((item) => "'${item.trim()}'").join(',');

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
