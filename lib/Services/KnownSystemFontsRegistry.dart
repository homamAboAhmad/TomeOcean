import 'dart:io';


/*
أضف الخط اسم الخط إلى قائمة KnownSystemFontsRegistry بحيث يُحمَّل عند الحاجة فقط إذا طلبه الكتاب، مع أسماء ملفات ويندوز المحتملة لهذا الخط.*/ */
const Map<String, List<String>> _knownSystemFontFiles = {
  'mohammad bold art 1': [
    'mohammad-bold-art-1.ttf',
  ],
};

List<String>? resolveKnownSystemFontPaths(String fontFamily) {
  final normalizedFamily = fontFamily.trim().toLowerCase();
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
