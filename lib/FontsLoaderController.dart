import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

final List<String> _fontFiles = [
  'Traditional Arabic.ttf',
  'Bold Italic Art.ttf',
  "Calibri.ttf",
  "Calibri Light.ttf",
  "Othmani.ttf",
  "Tholoth Rounded.ttf",
  "Simplified Arabic.ttf",
  "Farsi Simple Bold.ttf",
  "AL-Qairwan.otf",
  "AGA-Arabesque.otf",
  "(A) Arslan Wessam B.ttf",
  "rwmwws.ttf",
];

Future<void> loadFonts(List<String> fonts) async {
  for (String assetFont in _fontFiles) {
    await _loadCustomFont(assetFont);
  }
}

Future<void> _loadCustomFont(String assetFont) async {
  // print(assetFont);
  final ByteData fontData = await rootBundle.load('assets/fonts/$assetFont');
  String nameNoExt = removeExt(assetFont);
  // تحميل الخط باستخدام FontLoader
  final fontLoader = FontLoader(nameNoExt);
  fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
  await fontLoader.load();
}

String removeExt(String fileName) {
  int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex != -1) fileName = fileName.substring(0, dotIndex);
  return fileName;
}

// Future<void> _loadFontFromFile(String fontFamily, File fontFile) async {
//   final fontData = await fontFile.readAsBytes();
//   final fontLoader = FontLoader(fontFamily);
//   fontLoader.addFont(
//       Future.value(ByteData.view(Uint8List.fromList(fontData).buffer)));
//   await fontLoader.load();
// }
//
// Future<void> _downloadAndSaveFont(String fontFileName, File fontFile) async {
//   final ByteData fontData = await rootBundle.load('assets/fonts/$fontFileName');
//   await fontFile.writeAsBytes(fontData.buffer.asUint8List());
// }

/// تحميل خطوط مستخرجة من ملف docx
Future<void> loadExtractedFonts(Map<String, String> fontPaths) async {
  for (var entry in fontPaths.entries) {
    String fontFamily = entry.key;
    String fontPath = entry.value;

    try {
      File fontFile = File(fontPath);
      if (!await fontFile.exists()) continue;

      final fontData = await fontFile.readAsBytes();
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(fontData).buffer)),
      );
      await fontLoader.load();
    } catch (e) {
      debugPrint('⚠️ فشل تحميل خط "$fontFamily": $e');
    }
  }
}
