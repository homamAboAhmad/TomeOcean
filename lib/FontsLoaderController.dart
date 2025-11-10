import 'package:flutter/services.dart';

final List<String> _fontFiles = [
  'Traditional Arabic.ttf',
  'Bold Italic Art.ttf',
  "Calibri.ttf",
  "Calibri Light.ttf",
  "Othmani.ttf",
  "Tholoth Rounded.ttf",
  "Simplified Arabic.ttf",
  "Farsi Simple Bold.ttf",
  "Aljazeera.ttf",
  "AL-Qairwan.otf",
  "Al-Jazeera-Arabic-Bold.ttf",
  "AGA-Arabesque.otf",
  "(A) Arslan Wessam B.ttf",
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
