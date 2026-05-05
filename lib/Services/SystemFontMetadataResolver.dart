import 'dart:io';
import 'dart:typed_data';

class SystemFontMetadataResolver {
  SystemFontMetadataResolver._();

  static final Map<String, Set<String>> _pathsByNormalizedName =
      <String, Set<String>>{};
  static final Map<String, Map<int, bool>> _codePointSupportByPath =
      <String, Map<int, bool>>{};
  static final Map<String, bool> _legacySymbolOnlyByPath = <String, bool>{};
  static bool _didBuildIndex = false;

  static List<String>? resolveFontPaths(
    String fontFamily, {
    required List<String> fontDirectories,
  }) {
    _ensureIndex(fontDirectories);
    final normalized = _normalizeFontLookupKey(fontFamily);
    final matches = _pathsByNormalizedName[normalized];
    if (matches == null || matches.isEmpty) return null;
    return matches.toList()..sort();
  }

  static bool canResolveFontFamily(
    String fontFamily, {
    required List<String> fontDirectories,
  }) {
    _ensureIndex(fontDirectories);
    final normalized = _normalizeFontLookupKey(fontFamily);
    final matches = _pathsByNormalizedName[normalized];
    return matches != null && matches.isNotEmpty;
  }

  static bool fontFileSupportsCodePoint(String fontPath, int codePoint) {
    final cache = _codePointSupportByPath.putIfAbsent(
      fontPath,
      () => <int, bool>{},
    );
    final cached = cache[codePoint];
    if (cached != null) return cached;

    bool supports = false;
    try {
      final bytes = File(fontPath).readAsBytesSync();
      supports = _fontBytesSupportCodePoint(bytes, codePoint);
    } catch (_) {
      supports = false;
    }

    cache[codePoint] = supports;
    return supports;
  }

  static bool fontFileUsesLegacySymbolCmapOnly(String fontPath) {
    final cached = _legacySymbolOnlyByPath[fontPath];
    if (cached != null) return cached;

    bool isLegacySymbolOnly = false;
    try {
      final bytes = File(fontPath).readAsBytesSync();
      isLegacySymbolOnly = _fontBytesUseLegacySymbolCmapOnly(bytes);
    } catch (_) {
      isLegacySymbolOnly = false;
    }

    _legacySymbolOnlyByPath[fontPath] = isLegacySymbolOnly;
    return isLegacySymbolOnly;
  }

  static Uint8List prepareFontBytesForFlutter(Uint8List bytes) {
    if (!_fontBytesUseLegacySymbolCmapOnly(bytes)) {
      return bytes;
    }
    return _retagLegacySymbolFontAsUnicode(bytes);
  }

  static void _ensureIndex(List<String> fontDirectories) {
    if (_didBuildIndex) return;
    _didBuildIndex = true;

    for (final directoryPath in fontDirectories) {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) continue;

      try {
        for (final entity in directory.listSync()) {
          if (entity is! File) continue;

          final extension = entity.path.split('.').last.toLowerCase();
          if (extension != 'ttf' && extension != 'otf') continue;

          _indexFontFile(entity);
        }
      } catch (_) {
        // Ignore unreadable font directories and continue with the others.
      }
    }
  }

  static void _indexFontFile(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final names = _extractNameRecords(bytes);
      final fileName = file.uri.pathSegments.isEmpty
          ? file.path
          : file.uri.pathSegments.last;
      names.add(fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''));
      if (names.isEmpty) return;

      for (final rawName in names) {
        final normalized = _normalizeFontLookupKey(rawName);
        if (normalized.isEmpty) continue;
        _pathsByNormalizedName.putIfAbsent(normalized, () => <String>{}).add(
          file.path,
        );
      }
    } catch (_) {
      // Ignore individual unreadable or unsupported font files.
    }
  }

  static Set<String> _extractNameRecords(Uint8List bytes) {
    if (bytes.length < 12) return const <String>{};
    final byteData = ByteData.sublistView(bytes);

    final numTables = _readUint16(byteData, 4);
    final tableDirectoryEnd = 12 + (numTables * 16);
    if (bytes.length < tableDirectoryEnd) return const <String>{};

    int? nameTableOffset;
    int? nameTableLength;

    for (int i = 0; i < numTables; i++) {
      final recordOffset = 12 + (i * 16);
      final tag = String.fromCharCodes(bytes.sublist(recordOffset, recordOffset + 4));
      if (tag != 'name') continue;

      nameTableOffset = _readUint32(byteData, recordOffset + 8);
      nameTableLength = _readUint32(byteData, recordOffset + 12);
      break;
    }

    if (nameTableOffset == null || nameTableLength == null) {
      return const <String>{};
    }

    if (nameTableOffset < 0 ||
        nameTableLength <= 0 ||
        nameTableOffset + nameTableLength > bytes.length) {
      return const <String>{};
    }

    final tableData = ByteData.sublistView(
      bytes,
      nameTableOffset,
      nameTableOffset + nameTableLength,
    );

    if (tableData.lengthInBytes < 6) return const <String>{};

    final count = _readUint16(tableData, 2);
    final stringStorageOffset = _readUint16(tableData, 4);
    final recordsEnd = 6 + (count * 12);
    if (tableData.lengthInBytes < recordsEnd) return const <String>{};

    final names = <String>{};
    const interestingNameIds = <int>{1, 4, 6, 16, 21};

    for (int i = 0; i < count; i++) {
      final recordOffset = 6 + (i * 12);
      final platformId = _readUint16(tableData, recordOffset);
      final encodingId = _readUint16(tableData, recordOffset + 2);
      final nameId = _readUint16(tableData, recordOffset + 6);
      final length = _readUint16(tableData, recordOffset + 8);
      final offset = _readUint16(tableData, recordOffset + 10);

      if (!interestingNameIds.contains(nameId)) continue;

      final stringStart = stringStorageOffset + offset;
      final stringEnd = stringStart + length;
      if (stringStart < 0 ||
          length <= 0 ||
          stringEnd > tableData.lengthInBytes) {
        continue;
      }

      final rawBytes = bytes.sublist(
        nameTableOffset + stringStart,
        nameTableOffset + stringEnd,
      );

      final decoded = _decodeNameRecord(
        rawBytes,
        platformId: platformId,
        encodingId: encodingId,
      );
      if (decoded == null) continue;

      final cleaned = decoded.trim().replaceAll('\u0000', '');
      if (cleaned.isEmpty) continue;
      names.add(cleaned);
    }

    return names;
  }

  static String? _decodeNameRecord(
    List<int> rawBytes, {
    required int platformId,
    required int encodingId,
  }) {
    if (rawBytes.isEmpty) return null;

    if (platformId == 0 || platformId == 3) {
      if (rawBytes.length.isOdd) return null;
      final codeUnits = <int>[];
      for (int i = 0; i < rawBytes.length; i += 2) {
        codeUnits.add((rawBytes[i] << 8) | rawBytes[i + 1]);
      }
      return String.fromCharCodes(codeUnits);
    }

    if (platformId == 1 && encodingId == 0) {
      return String.fromCharCodes(rawBytes);
    }

    return String.fromCharCodes(rawBytes);
  }

  static int _readUint16(ByteData data, int offset) {
    return data.getUint16(offset, Endian.big);
  }

  static int _readUint32(ByteData data, int offset) {
    return data.getUint32(offset, Endian.big);
  }

  static int _readInt16(ByteData data, int offset) {
    return data.getInt16(offset, Endian.big);
  }

  static void _writeUint16(ByteData data, int offset, int value) {
    data.setUint16(offset, value, Endian.big);
  }

  static void _writeUint32(ByteData data, int offset, int value) {
    data.setUint32(offset, value, Endian.big);
  }

  static int _calculateTableChecksum(Uint8List bytes, int offset, int length) {
    int sum = 0;
    final paddedLength = (length + 3) & ~3;
    for (int i = 0; i < paddedLength; i += 4) {
      int value = 0;
      for (int j = 0; j < 4; j++) {
        final relativeIndex = i + j;
        final absoluteIndex = offset + relativeIndex;
        final byte = (relativeIndex < length && absoluteIndex < bytes.length)
            ? bytes[absoluteIndex]
            : 0;
        value = (value << 8) | byte;
      }
      sum = (sum + value) & 0xFFFFFFFF;
    }
    return sum;
  }

  static bool _fontBytesSupportCodePoint(Uint8List bytes, int codePoint) {
    if (bytes.length < 12) return false;

    final byteData = ByteData.sublistView(bytes);
    final subTables = _readCmapSubtables(byteData, bytes);
    for (final subTable in subTables) {
      final format = subTable.format;
      final subTableOffset = subTable.offset;
      switch (format) {
        case 4:
          if (_format4SupportsCodePoint(byteData, bytes.length, subTableOffset, codePoint)) {
            return true;
          }
          break;
        case 6:
          if (_format6SupportsCodePoint(byteData, bytes.length, subTableOffset, codePoint)) {
            return true;
          }
          break;
        case 12:
          if (_format12SupportsCodePoint(byteData, bytes.length, subTableOffset, codePoint)) {
            return true;
          }
          break;
      }
    }

    return false;
  }

  static bool _fontBytesUseLegacySymbolCmapOnly(Uint8List bytes) {
    if (bytes.length < 12) return false;

    final byteData = ByteData.sublistView(bytes);
    final subTables = _readCmapSubtables(byteData, bytes);
    if (subTables.isEmpty) return false;

    final hasLegacySymbol = subTables.any(
      (subTable) => subTable.platformId == 3 && subTable.encodingId == 0,
    );
    if (!hasLegacySymbol) return false;

    final hasUnicode = subTables.any(
      (subTable) =>
          subTable.platformId == 0 ||
          (subTable.platformId == 3 &&
              (subTable.encodingId == 1 || subTable.encodingId == 10)),
    );

    return !hasUnicode;
  }

  static Uint8List _retagLegacySymbolFontAsUnicode(Uint8List originalBytes) {
    final bytes = Uint8List.fromList(originalBytes);
    final byteData = ByteData.sublistView(bytes);
    final numTables = _readUint16(byteData, 4);

    int? cmapRecordOffset;
    int? cmapOffset;
    int? cmapLength;
    int? headRecordOffset;
    int? headOffset;

    for (int i = 0; i < numTables; i++) {
      final recordOffset = 12 + (i * 16);
      final tag = String.fromCharCodes(
        bytes.sublist(recordOffset, recordOffset + 4),
      );
      if (tag == 'cmap') {
        cmapRecordOffset = recordOffset;
        cmapOffset = _readUint32(byteData, recordOffset + 8);
        cmapLength = _readUint32(byteData, recordOffset + 12);
      } else if (tag == 'head') {
        headRecordOffset = recordOffset;
        headOffset = _readUint32(byteData, recordOffset + 8);
      }
    }

    if (cmapRecordOffset == null ||
        cmapOffset == null ||
        cmapLength == null ||
        cmapOffset + cmapLength > bytes.length) {
      return originalBytes;
    }

    final subTableCount = _readUint16(byteData, cmapOffset + 2);
    bool changed = false;
    for (int i = 0; i < subTableCount; i++) {
      final recordOffset = cmapOffset + 4 + (i * 8);
      if (recordOffset + 8 > bytes.length) continue;

      final platformId = _readUint16(byteData, recordOffset);
      final encodingId = _readUint16(byteData, recordOffset + 2);
      if (platformId == 3 && encodingId == 0) {
        _writeUint16(byteData, recordOffset + 2, 1);
        changed = true;
      }
    }

    if (!changed) {
      return originalBytes;
    }

    _writeUint32(
      byteData,
      cmapRecordOffset + 4,
      _calculateTableChecksum(bytes, cmapOffset, cmapLength),
    );

    if (headRecordOffset != null &&
        headOffset != null &&
        headOffset + 12 <= bytes.length) {
      _writeUint32(byteData, headOffset + 8, 0);
      final wholeFontChecksum = _calculateTableChecksum(bytes, 0, bytes.length);
      final adjustment = (0xB1B0AFBA - wholeFontChecksum) & 0xFFFFFFFF;
      _writeUint32(byteData, headOffset + 8, adjustment);
      _writeUint32(
        byteData,
        headRecordOffset + 4,
        _calculateTableChecksum(bytes, headOffset, 54),
      );
    }

    return bytes;
  }

  static List<_CmapSubtableHeader> _readCmapSubtables(
    ByteData byteData,
    Uint8List bytes,
  ) {
    final numTables = _readUint16(byteData, 4);
    final tableDirectoryEnd = 12 + (numTables * 16);
    if (bytes.length < tableDirectoryEnd) return const <_CmapSubtableHeader>[];

    int? cmapOffset;
    for (int i = 0; i < numTables; i++) {
      final recordOffset = 12 + (i * 16);
      final tag = String.fromCharCodes(
        bytes.sublist(recordOffset, recordOffset + 4),
      );
      if (tag == 'cmap') {
        cmapOffset = _readUint32(byteData, recordOffset + 8);
        break;
      }
    }

    if (cmapOffset == null || cmapOffset + 4 > bytes.length) {
      return const <_CmapSubtableHeader>[];
    }

    final subTableCount = _readUint16(byteData, cmapOffset + 2);
    final subTables = <_CmapSubtableHeader>[];
    for (int i = 0; i < subTableCount; i++) {
      final recordOffset = cmapOffset + 4 + (i * 8);
      if (recordOffset + 8 > bytes.length) continue;

      final platformId = _readUint16(byteData, recordOffset);
      final encodingId = _readUint16(byteData, recordOffset + 2);
      final subTableOffset = cmapOffset + _readUint32(byteData, recordOffset + 4);
      if (subTableOffset + 2 > bytes.length) continue;

      final format = _readUint16(byteData, subTableOffset);
      subTables.add(
        _CmapSubtableHeader(
          platformId: platformId,
          encodingId: encodingId,
          offset: subTableOffset,
          format: format,
        ),
      );
    }

    return subTables;
  }

  static bool _format4SupportsCodePoint(
    ByteData data,
    int byteLength,
    int offset,
    int codePoint,
  ) {
    if (codePoint < 0 || codePoint > 0xFFFF || offset + 8 > byteLength) {
      return false;
    }

    final length = _readUint16(data, offset + 2);
    if (length <= 0 || offset + length > byteLength) return false;

    final segCount = _readUint16(data, offset + 6) ~/ 2;
    final endCodeOffset = offset + 14;
    final startCodeOffset = endCodeOffset + (segCount * 2) + 2;
    final idDeltaOffset = startCodeOffset + (segCount * 2);
    final idRangeOffsetOffset = idDeltaOffset + (segCount * 2);

    if (idRangeOffsetOffset + (segCount * 2) > offset + length) {
      return false;
    }

    for (int i = 0; i < segCount; i++) {
      final endCode = _readUint16(data, endCodeOffset + (i * 2));
      final startCode = _readUint16(data, startCodeOffset + (i * 2));
      if (codePoint < startCode || codePoint > endCode) continue;

      final idDelta = _readInt16(data, idDeltaOffset + (i * 2));
      final idRangeOffset = _readUint16(data, idRangeOffsetOffset + (i * 2));

      if (idRangeOffset == 0) {
        final glyphIndex = (codePoint + idDelta) & 0xFFFF;
        return glyphIndex != 0;
      }

      final rangeBase = idRangeOffsetOffset + (i * 2);
      final glyphIndexOffset =
          rangeBase + idRangeOffset + ((codePoint - startCode) * 2);
      if (glyphIndexOffset + 2 > offset + length) return false;

      var glyphIndex = _readUint16(data, glyphIndexOffset);
      if (glyphIndex == 0) return false;

      glyphIndex = (glyphIndex + idDelta) & 0xFFFF;
      return glyphIndex != 0;
    }

    return false;
  }

  static bool _format6SupportsCodePoint(
    ByteData data,
    int byteLength,
    int offset,
    int codePoint,
  ) {
    if (offset + 10 > byteLength || codePoint < 0 || codePoint > 0xFFFF) {
      return false;
    }

    final length = _readUint16(data, offset + 2);
    if (length <= 0 || offset + length > byteLength) return false;

    final firstCode = _readUint16(data, offset + 6);
    final entryCount = _readUint16(data, offset + 8);
    if (codePoint < firstCode || codePoint >= firstCode + entryCount) {
      return false;
    }

    final glyphOffset = offset + 10 + ((codePoint - firstCode) * 2);
    if (glyphOffset + 2 > offset + length) return false;
    return _readUint16(data, glyphOffset) != 0;
  }

  static bool _format12SupportsCodePoint(
    ByteData data,
    int byteLength,
    int offset,
    int codePoint,
  ) {
    if (offset + 16 > byteLength || codePoint < 0) return false;

    final length = _readUint32(data, offset + 4);
    if (length <= 0 || offset + length > byteLength) return false;

    final groupCount = _readUint32(data, offset + 12);
    final groupsOffset = offset + 16;
    final groupsEnd = groupsOffset + (groupCount * 12);
    if (groupsEnd > offset + length) return false;

    for (int i = 0; i < groupCount; i++) {
      final groupOffset = groupsOffset + (i * 12);
      final startCharCode = _readUint32(data, groupOffset);
      final endCharCode = _readUint32(data, groupOffset + 4);
      if (codePoint >= startCharCode && codePoint <= endCharCode) {
        return true;
      }
    }

    return false;
  }
}

String _normalizeFontLookupKey(String fontFamily) {
  return fontFamily
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _CmapSubtableHeader {
  final int platformId;
  final int encodingId;
  final int offset;
  final int format;

  const _CmapSubtableHeader({
    required this.platformId,
    required this.encodingId,
    required this.offset,
    required this.format,
  });
}
