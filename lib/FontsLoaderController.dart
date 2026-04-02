import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Services/KnownSystemFontsRegistry.dart';

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

Future<void> loadFonts(List<String> fonts) async {
  for (String assetFont in _fontFiles) {
    await _loadCustomFont(assetFont);
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
  Iterable<String> requestedFamilies,
) async {
  for (final rawFamily in requestedFamilies) {
    final family = rawFamily.trim();
    if (family.isEmpty) continue;

    final candidatePaths = resolveKnownSystemFontPaths(family);
    if (candidatePaths == null) continue;
    if (!_markFontFamilyAsPending(family)) continue;

    bool loaded = false;
    for (final fontPath in candidatePaths) {
      final file = File(fontPath);
      if (!await file.exists()) continue;

      try {
        final fontBytes = Uint8List.fromList(await file.readAsBytes());
        final fontLoader = FontLoader(family);
        fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await fontLoader.load();
        debugPrint('Loaded known system font: $family <- $fontPath');
        loaded = true;
        break;
      } catch (e) {
        debugPrint('Failed to load known system font "$family": $e');
      }
    }

    if (!loaded) {
      _loadedFontFamilies.remove(family.toLowerCase());
    }
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

      final fontBytes = Uint8List.fromList(await fontFile.readAsBytes());
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Failed to load extracted font "$fontFamily": $e');
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

String removeExt(String fileName) {
  int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex != -1) fileName = fileName.substring(0, dotIndex);
  return fileName;
}
