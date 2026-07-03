import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Services/KnownSystemFontsRegistry.dart';
import 'package:golden_shamela/Services/SystemFontMetadataResolver.dart';

final List<String> _fontFiles = [
  'Traditional Arabic.ttf',
  'Bold Italic Art.ttf',
  'Calibri.ttf',
  'Calibri Light.ttf',
  'Othmani.ttf',
  'Tholoth Rounded.ttf',
  'Simplified Arabic.ttf',
  'Farsi Simple Bold.ttf',
  'AL-Qairwan.otf',
  'AGA-Arabesque.otf',
  '(A) Arslan Wessam B.ttf',
  'rwmwws.ttf',
];

final Set<String> _loadedFontFamilies = <String>{};

Future<void> loadFonts(
  List<String> fonts, {
    bool yieldBetweenFonts = false,
  }) async {
  for (String assetFont in _fontFiles) {
    await _loadCustomFont(assetFont);
    if (yieldBetweenFonts) await _yieldForUi();
  }
}

Future<void> _loadCustomFont(String assetFont) async {
  final ByteData fontData = await rootBundle.load('assets/fonts/$assetFont');
  String nameNoExt = removeExt(assetFont);
  _loadedFontFamilies.add(nameNoExt.trim().toLowerCase());

  final fontLoader = FontLoader(nameNoExt);
  fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
  await fontLoader.load();
}

Future<void> loadKnownSystemFontsForDocument(
  Iterable<String> requestedFamilies, {
    bool yieldBetweenFamilies = false,
    bool logQueuedFaces = true,
  }) async {
  for (final rawFamily in requestedFamilies) {
    final family = rawFamily.trim();
    if (family.isEmpty) continue;

    final candidatePaths = resolveKnownSystemFontPaths(family);
    if (candidatePaths == null) continue;
    if (!_markFontFamilyAsPending(family)) continue;

    final normalizedPaths = <String>{...candidatePaths};
    final fontLoader = FontLoader(family);
    bool addedAnyFace = false;

    for (final fontPath in normalizedPaths) {
      final file = File(fontPath);
      if (!await file.exists()) continue;

      try {
        final fontBytes = await _readPreparedFontBytes(file);
        fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        addedAnyFace = true;
        if (logQueuedFaces) {
          debugPrint('Queued known system font face: $family <- $fontPath');
        }
      } catch (e) {
        debugPrint('Failed to load known system font "$family": $e');
      }
    }

    if (!addedAnyFace) {
      _unmarkFontFamily(family);
      continue;
    }

    try {
      await fontLoader.load();
      debugPrint('Loaded known system font family: $family');
    } catch (e) {
      debugPrint('Failed to finalize known system font family "$family": $e');
      _unmarkFontFamily(family);
    }

    if (yieldBetweenFamilies) await _yieldForUi();
  }
}

Future<void> loadExtractedFonts(Map<String, String> fontPaths) async {
  for (var entry in fontPaths.entries) {
    String fontFamily = entry.key;
    String fontPath = entry.value;

    try {
      File fontFile = File(fontPath);
      if (!await fontFile.exists()) continue;
      if (!_markFontFamilyAsPending(fontFamily)) continue;

      final fontBytes = await _readPreparedFontBytes(fontFile);
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Failed to load extracted font "$fontFamily": $e');
      _unmarkFontFamily(fontFamily);
    }
  }
}

bool _markFontFamilyAsPending(String fontFamily) {
  final normalized = fontFamily.trim().toLowerCase();
  if (_loadedFontFamilies.contains(normalized)) {
    return false;
  }
  _loadedFontFamilies.add(normalized);
  return true;
}

void _unmarkFontFamily(String fontFamily) {
  _loadedFontFamilies.remove(fontFamily.trim().toLowerCase());
}

Future<Uint8List> _readPreparedFontBytes(File fontFile) async {
  final rawBytes = Uint8List.fromList(await fontFile.readAsBytes());
  return SystemFontMetadataResolver.prepareFontBytesForFlutter(rawBytes);
}

Future<void> _yieldForUi() {
  return Future<void>.delayed(const Duration(milliseconds: 50));
}

String removeExt(String fileName) {
  int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex != -1) fileName = fileName.substring(0, dotIndex);
  return fileName;
}

/// أشهر عائلات خطوط ويندوز المستعملة في مستندات Word العربية واللاتينية.
///
/// تُحمَّل مرة واحدة عند إقلاع التطبيق في الخلفية حتى لا يدفع أول فتح كتاب
/// كلفة بناء فهرس الخطوط وقراءة ملفاتها. هذه قائمة محدودة عمدًا: لا نحمّل كل
/// خطوط ويندوز (مئات الملفات) لأن ذلك ينقل البطء إلى الإقلاع ويهدر الذاكرة.
/// العائلات غير المدرجة هنا تبقى تُحمَّل عند الطلب عبر
/// [loadKnownSystemFontsForDocument] حين يطلبها كتاب فعليًا.
const List<String> _commonSystemFontFamilies = [
  // لاتينية شائعة جدًا
  'Arial',
  'Arial Narrow',
  'Times New Roman',
  'Courier New',
  'Calibri',
  'Cambria',
  'Verdana',
  'Tahoma',
  'Georgia',
  'Trebuchet MS',
  'Comic Sans MS',
  'Segoe UI',
  'Consolas',
  // رمزية (تحتاج تجهيز bytes للـ legacy symbol cmap)
  'Symbol',
  'Wingdings',
  'Webdings',
  // عربية شائعة على ويندوز
  'Traditional Arabic',
  'Simplified Arabic',
  'Arabic Typesetting',
  'Sakkal Majalla',
  'Andalus',
  'DecoType Naskh',
  'DecoType Thuluth',
  'Microsoft Uighur',
  'Microsoft Yi Baiti',
];

/// يحمّل خطوط التطبيق المرفقة (assets) وقائمة أشهر خطوط النظام مرة واحدة.
///
/// مخصّص للاستدعاء بعد ظهور أول إطار في الخلفية (`unawaited`). لا يحجب الإقلاع،
/// ويترك فواصل قصيرة بين العائلات حتى لا يزاحم واجهة البداية.
/// لا يكرّر العمل لأن `_loadedFontFamilies` يمنع إعادة تحميل العائلة نفسها.
/// لا يرمي استثناءً للأعلى حتى لا يكسر الإقلاع إذا تعذّر خط ما.
Future<void> preloadAppAndCommonFonts() async {
  try {
    await loadFonts(const [], yieldBetweenFonts: true);
  } catch (e) {
    debugPrint('Failed to preload bundled app fonts: $e');
  }

  try {
    await loadKnownSystemFontsForDocument(
      _commonSystemFontFamilies,
      yieldBetweenFamilies: true,
      logQueuedFaces: false,
    );
  } catch (e) {
    debugPrint('Failed to preload common system fonts: $e');
  }
}
