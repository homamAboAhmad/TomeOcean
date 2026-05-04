import 'dart:ui';

import 'package:golden_shamela/Models/WordDocument.dart';

const Map<String, int> _vmlNamedColors = {
  'aqua': 0xFF00FFFF,
  'black': 0xFF000000,
  'blue': 0xFF0000FF,
  'fuchsia': 0xFFFF00FF,
  'gray': 0xFF808080,
  'green': 0xFF008000,
  'lime': 0xFF00FF00,
  'maroon': 0xFF800000,
  'navy': 0xFF000080,
  'olive': 0xFF808000,
  'purple': 0xFF800080,
  'red': 0xFFFF0000,
  'silver': 0xFFC0C0C0,
  'teal': 0xFF008080,
  'white': 0xFFFFFFFF,
  'yellow': 0xFFFFFF00,
};

const Map<String, String> _vmlSchemeColorAliases = {
  // VML scheme colors are document-level logical colors. In OOXML-backed
  // Word documents we map them to the nearest active theme entry.
  'scheme.background': 'light1',
  'scheme.text': 'dark1',
  'scheme.shadow': 'dark1',
  'scheme.title': 'dark1',
  'scheme.fill': 'light1',
  'scheme.accent': 'accent1',
  'scheme.hyperlink': 'hyperlink',
  'scheme.followed': 'followedHyperlink',
};

/// Resolves VML color tokens as documented by Microsoft VML:
/// HTML keyword names, #rgb/#rrggbb, rgb(r,g,b), and scheme colors.
Color? parseVmlColorValue(String? rawValue, {WordDocument? wordDocument}) {
  if (rawValue == null) return null;

  final value = rawValue.trim().toLowerCase();
  if (value.isEmpty || value == 'none' || value == 'auto') return null;

  final namedColor = _vmlNamedColors[value];
  if (namedColor != null) {
    return Color(namedColor);
  }

  if (value.startsWith('#')) {
    return _parseHexColor(value.substring(1));
  }

  final rgbMatch = RegExp(
    r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
  ).firstMatch(value);
  if (rgbMatch != null) {
    final r = int.tryParse(rgbMatch.group(1) ?? '');
    final g = int.tryParse(rgbMatch.group(2) ?? '');
    final b = int.tryParse(rgbMatch.group(3) ?? '');
    if (r != null && g != null && b != null) {
      return Color.fromARGB(
        255,
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }
  }

  return _resolveVmlSchemeColor(value, wordDocument: wordDocument);
}

Color? _parseHexColor(String hex) {
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }

  if (hex.length != 6) return null;

  try {
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return null;
  }
}

Color? _resolveVmlSchemeColor(
  String value, {
  required WordDocument? wordDocument,
}) {
  if (wordDocument == null) return null;

  final directThemeName = _vmlSchemeColorAliases[value];
  if (directThemeName != null) {
    return _resolveThemeColorByName(wordDocument, directThemeName);
  }

  final schemeIndex = RegExp(r'^scheme\(\s*(\d+)\s*\)$').firstMatch(value);
  if (schemeIndex == null) return null;

  final index = int.tryParse(schemeIndex.group(1) ?? '');
  if (index == null) return null;

  const indexedThemeNames = <int, String>{
    0: 'light1',
    1: 'dark1',
    2: 'dark1',
    3: 'dark1',
    4: 'light1',
    5: 'accent1',
    6: 'hyperlink',
    7: 'followedHyperlink',
  };

  final themeName = indexedThemeNames[index];
  if (themeName == null) return null;

  return _resolveThemeColorByName(wordDocument, themeName);
}

Color? _resolveThemeColorByName(WordDocument wordDocument, String themeName) {
  String? hex = wordDocument.themeColors[themeName];
  if ((hex == null || hex.isEmpty) && themeName == 'light1') {
    hex = wordDocument.autoLightColor;
  } else if ((hex == null || hex.isEmpty) && themeName == 'dark1') {
    hex = wordDocument.autoDarkColor;
  }

  return _parseHexColor(hex ?? '');
}
