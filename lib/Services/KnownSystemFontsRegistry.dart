import 'dart:io';


/*
أضف الخط اسم الخط إلى قائمة KnownSystemFontsRegistry بحيث يُحمَّل عند الحاجة فقط إذا طلبه الكتاب، مع أسماء ملفات ويندوز المحتملة لهذا الخط.*/
const Map<String, List<String>> _knownSystemFontFiles = {
  'mohammad bold art 1': [
    'mohammad-bold-art-1.ttf',
  ],
  'mohammad bold normal': [
    'Mohammad-Bold-normal.ttf',
  ],
  'al jazeera arabic bold': [
    'Al-Jazeera-Arabic-Bold.ttf',
    'Aljazeera.ttf',
  ],
  'al jazeera arabic regular': [
    'Al-Jazeera-Arabic-Regular.ttf',
    'Aljazeera.ttf',
  ],
  'al jazeera arabic light': [
    'Al-Jazeera-Arabic-Light.ttf',
  ],
  'al jazeera arabic': [
    'Al-Jazeera-Arabic-Regular.ttf',
    'Aljazeera.ttf',
  ],
  'aljazeera': [
    'Aljazeera.ttf',
    'Al-Jazeera-Arabic-Regular.ttf',
  ],
  'lotus linotype': [
    'mylotus Regular.ttf',
  ],
  'yakout linotype light': [
    'Yakout-Linotype-Light.ttf',
  ],
};

List<String>? resolveKnownSystemFontPaths(String fontFamily) {
  final normalizedFamily = normalizeKnownSystemFontKey(fontFamily);
  final candidateFiles = _knownSystemFontFiles[normalizedFamily];
  if (candidateFiles == null) return null;

  final fontDirectories = _getSystemFontDirectories();
  final paths = <String>[];

  for (final fontDirectory in fontDirectories) {
    for (final fontFileName in candidateFiles) {
      paths.add('$fontDirectory\\$fontFileName');
    }
  }

  return paths;
}

bool isKnownSystemFontFamily(String fontFamily) {
  final normalizedFamily = normalizeKnownSystemFontKey(fontFamily);
  return _knownSystemFontFiles.containsKey(normalizedFamily);
}

String normalizeKnownSystemFontKey(String fontFamily) {
  return fontFamily
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

List<String> _getSystemFontDirectories() {
  final directories = <String>[];

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    directories.add('$localAppData\\Microsoft\\Windows\\Fonts');
    directories.add('$localAppData\\Fonts');
  }

  final windowsDir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  directories.add('$windowsDir\\Fonts');

  return directories;
}
