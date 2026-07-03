import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/SystemFontMetadataResolver.dart';

class WindowsFontFamily {
  final String name;
  final Set<String> styles;
  final Set<String> paths;
  final Set<int> supportedCodePoints;

  const WindowsFontFamily({
    required this.name,
    required this.styles,
    required this.paths,
    this.supportedCodePoints = const <int>{},
  });

  bool supportsCodePoint(int codePoint) => supportedCodePoints.contains(codePoint);

  Map<String, Object> toJson() => {
        'name': name,
        'styles': styles.toList()..sort(),
        'paths': paths.toList()..sort(),
        'supportedCodePoints': supportedCodePoints.toList()..sort(),
      };

  static WindowsFontFamily fromJson(Map<String, dynamic> json) {
    return WindowsFontFamily(
      name: json['name']?.toString() ?? '',
      styles: _stringSet(json['styles']),
      paths: _stringSet(json['paths']),
      supportedCodePoints: {
        for (final value in (json['supportedCodePoints'] as List? ?? const []))
          if (value is num) value.toInt(),
      },
    );
  }

  static Set<String> _stringSet(Object? value) => {
        for (final item in (value as List? ?? const []))
          if (item != null && item.toString().trim().isNotEmpty) item.toString(),
      };
}

class WindowsFontCatalog {
  WindowsFontCatalog._();

  static List<WindowsFontFamily>? _families;

  static List<WindowsFontFamily> families() {
    final cached = _families;
    if (cached != null) return cached;
    final disk = _readDiskCache();
    if (disk.isNotEmpty) {
      _families = disk;
      return disk;
    }

    final list = _scanFamilies();
    _families = list;
    _writeDiskCache(list);
    return list;
  }

  static Future<List<WindowsFontFamily>> familiesAsync() async {
    final cached = _families;
    if (cached != null) return cached;
    final disk = _readDiskCache();
    if (disk.isNotEmpty) {
      _families = disk;
      return disk;
    }
    final refreshed = await Isolate.run(_scanFamilies);
    _families = refreshed;
    _writeDiskCache(refreshed);
    return refreshed;
  }

  static Future<void> refreshCacheInBackground() async {
    try {
      final cachePath = AppStoragePaths.windowsFontCatalogCachePath;
      final refreshed = await Isolate.run(_scanFamilies);
      _families = refreshed;
      await File(cachePath).parent.create(recursive: true);
      await File(cachePath).writeAsString(jsonEncode(_toJson(refreshed)));
    } catch (_) {}
  }

  static List<WindowsFontFamily> _scanFamilies() {
    final byName = <String, _FontBucket>{};
    for (final directoryPath in _fontDirectories()) {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) continue;

      for (final entity in directory.listSync()) {
        if (entity is! File || !_isFontFile(entity.path)) continue;
        final meta = _readFontMeta(entity);
        if (meta == null) continue;

        final bucket = byName.putIfAbsent(
          meta.family,
          () => _FontBucket(meta.family),
        );
        bucket.styles.add(meta.style);
        bucket.paths.add(entity.path);
        for (final codePoint in _cachedCodePoints) {
          if (SystemFontMetadataResolver.fontFileSupportsCodePoint(entity.path, codePoint)) {
            bucket.supportedCodePoints.add(codePoint);
          }
        }
      }
    }

    return byName.values
        .map((bucket) => WindowsFontFamily(
              name: bucket.family,
              styles: bucket.styles,
              paths: bucket.paths,
              supportedCodePoints: bucket.supportedCodePoints,
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static List<WindowsFontFamily> familiesForCodePoint(int codePoint) {
    return families().where((family) => family.supportsCodePoint(codePoint)).toList();
  }

  static List<String> stylesForFamily(String familyName) {
    final family = families().where((family) => family.name == familyName);
    final styles = family.isEmpty ? <String>['Regular'] : family.first.styles.toList();
    for (final fallback in const ['Regular', 'Bold', 'Italic', 'Bold Italic']) {
      if (!styles.any((style) => style.toLowerCase() == fallback.toLowerCase())) {
        styles.add(fallback);
      }
    }
    return styles
      ..sort((a, b) => _styleRank(a).compareTo(_styleRank(b)));
  }

  static bool _isFontFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.ttf') || lower.endsWith('.otf');
  }

  static _FontMeta? _readFontMeta(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final names = _readNameRecords(bytes);
      final family = names[16] ?? names[1];
      if (family == null || family.trim().isEmpty) return null;
      return _FontMeta(family.trim(), (names[2] ?? 'Regular').trim());
    } catch (_) {
      return null;
    }
  }

  static Map<int, String> _readNameRecords(Uint8List bytes) {
    if (bytes.length < 12) return const {};
    final data = ByteData.sublistView(bytes);
    final tableCount = _readU16(data, 4);
    final tableEnd = 12 + tableCount * 16;
    if (bytes.length < tableEnd) return const {};

    int? nameOffset;
    int? nameLength;
    for (int i = 0; i < tableCount; i++) {
      final offset = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (tag != 'name') continue;
      nameOffset = _readU32(data, offset + 8);
      nameLength = _readU32(data, offset + 12);
      break;
    }
    if (nameOffset == null ||
        nameLength == null ||
        nameOffset + nameLength > bytes.length) {
      return const {};
    }

    final table = ByteData.sublistView(bytes, nameOffset, nameOffset + nameLength);
    final count = _readU16(table, 2);
    final stringsOffset = _readU16(table, 4);
    final result = <int, String>{};

    for (int i = 0; i < count; i++) {
      final recordOffset = 6 + i * 12;
      if (recordOffset + 12 > table.lengthInBytes) break;
      final platform = _readU16(table, recordOffset);
      final encoding = _readU16(table, recordOffset + 2);
      final nameId = _readU16(table, recordOffset + 6);
      if (nameId != 1 && nameId != 2 && nameId != 16) continue;

      final length = _readU16(table, recordOffset + 8);
      final offset = _readU16(table, recordOffset + 10);
      final start = nameOffset + stringsOffset + offset;
      final end = start + length;
      if (length <= 0 || end > bytes.length) continue;

      final value = _decodeName(
        bytes.sublist(start, end),
        platform: platform,
        encoding: encoding,
      );
      if (value != null && value.trim().isNotEmpty) {
        result.putIfAbsent(nameId, () => value.trim());
      }
    }
    return result;
  }

  static String? _decodeName(
    List<int> raw, {
    required int platform,
    required int encoding,
  }) {
    if ((platform == 0 || platform == 3) && raw.length.isEven) {
      final units = <int>[];
      for (int i = 0; i < raw.length; i += 2) {
        units.add((raw[i] << 8) | raw[i + 1]);
      }
      return String.fromCharCodes(units).replaceAll('\u0000', '');
    }
    if (platform == 1 && encoding == 0) {
      return String.fromCharCodes(raw).replaceAll('\u0000', '');
    }
    return null;
  }

  static int _readU16(ByteData data, int offset) =>
      data.getUint16(offset, Endian.big);

  static int _readU32(ByteData data, int offset) =>
      data.getUint32(offset, Endian.big);

  static int _styleRank(String style) {
    final lower = style.toLowerCase();
    if (lower == 'regular') return 0;
    if (lower == 'bold') return 1;
    if (lower == 'italic') return 2;
    if (lower == 'bold italic') return 3;
    if (lower.contains('semi')) return 4;
    if (lower.contains('bold')) return 5;
    return 10;
  }

  static List<String> _fontDirectories() {
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

  static List<WindowsFontFamily> _readDiskCache() {
    try {
      final file = File(AppStoragePaths.windowsFontCatalogCachePath);
      if (!file.existsSync()) return const [];
      final decoded = jsonDecode(file.readAsStringSync()) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WindowsFontFamily.fromJson)
          .where((family) => family.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return const [];
    }
  }

  static void _writeDiskCache(List<WindowsFontFamily> families) {
    try {
      final file = File(AppStoragePaths.windowsFontCatalogCachePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_toJson(families)));
    } catch (_) {}
  }

  static List<Map<String, Object>> _toJson(List<WindowsFontFamily> families) => [
        for (final family in families) family.toJson(),
      ];

  static const _cachedCodePoints = [
    0x0642, // Arabic
    0x0041, // Latin
    0x0710, // Syriac
    0x0780, // Thaana
    0x0915, // Devanagari
    0x0995, // Bengali
    0x0A15, // Gurmukhi
    0x0A95, // Gujarati
    0x0B15, // Oriya
    0x0B95, // Tamil
    0x0C15, // Telugu
  ];
}

class _FontBucket {
  final String family;
  final Set<String> styles = {'Regular'};
  final Set<String> paths = {};
  final Set<int> supportedCodePoints = {};

  _FontBucket(this.family);
}

class _FontMeta {
  final String family;
  final String style;

  const _FontMeta(this.family, this.style);
}
