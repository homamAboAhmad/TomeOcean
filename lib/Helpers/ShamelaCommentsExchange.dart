import 'dart:convert';
import 'dart:typed_data';

class ShamelaCommentRecord {
  final String bookId;
  final int anchor;
  final String? part;
  final int? page;
  final String text;

  const ShamelaCommentRecord({
    required this.bookId,
    required this.anchor,
    required this.part,
    required this.page,
    required this.text,
  });
}

class ShamelaCommentsExchange {
  const ShamelaCommentsExchange._();

  static List<ShamelaCommentRecord> decode(Uint8List bytes) {
    final root = _MsgpackReader(bytes).readValue();
    if (root is! Map) {
      throw const FormatException('ملف التعليقات غير صالح');
    }

    final records = <ShamelaCommentRecord>[];
    for (final entry in root.entries) {
      final bookId = entry.key.toString();
      final comments = entry.value;
      if (comments is! List) continue;
      for (final item in comments) {
        final record = _recordFromItem(bookId, item);
        if (record != null) records.add(record);
      }
    }
    return records;
  }

  static Uint8List encode(List<ShamelaCommentRecord> records) {
    final grouped = <String, List<Object?>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.bookId, () => []).add([
        [record.anchor, record.part, record.page, null],
        record.text,
      ]);
    }

    final sorted = Map<String, Object?>.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return Uint8List.fromList(_MsgpackWriter().write(sorted));
  }

  static ShamelaCommentRecord? _recordFromItem(String bookId, Object? item) {
    if (item is! List || item.length < 2) return null;
    final location = item[0];
    final text = item[1]?.toString() ?? '';
    if (location is! List || location.length < 3 || text.trim().isEmpty) {
      return null;
    }
    return ShamelaCommentRecord(
      bookId: bookId,
      anchor: _asInt(location[0]) ?? 0,
      part: location[1]?.toString(),
      page: _asInt(location[2]),
      text: text,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _MsgpackReader {
  final Uint8List bytes;
  int _offset = 0;

  _MsgpackReader(this.bytes);

  Object? readValue() {
    final byte = _readByte();
    if (byte <= 0x7f) return byte;
    if (byte >= 0x80 && byte <= 0x8f) return _readMap(byte & 0x0f);
    if (byte >= 0x90 && byte <= 0x9f) return _readArray(byte & 0x0f);
    if (byte >= 0xa0 && byte <= 0xbf) return _readString(byte & 0x1f);
    if (byte >= 0xe0) return byte - 0x100;

    switch (byte) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xcc:
        return _readByte();
      case 0xcd:
        return _readUint16();
      case 0xce:
        return _readUint32();
      case 0xd0:
        return _readInt8();
      case 0xd1:
        return _readInt16();
      case 0xd2:
        return _readInt32();
      case 0xd9:
        return _readString(_readByte());
      case 0xda:
        return _readString(_readUint16());
      case 0xdb:
        return _readString(_readUint32());
      case 0xdc:
        return _readArray(_readUint16());
      case 0xdd:
        return _readArray(_readUint32());
      case 0xde:
        return _readMap(_readUint16());
      case 0xdf:
        return _readMap(_readUint32());
    }
    throw FormatException('نوع MessagePack غير مدعوم: 0x${byte.toRadixString(16)}');
  }

  List<Object?> _readArray(int length) =>
      List<Object?>.generate(length, (_) => readValue());

  Map<Object?, Object?> _readMap(int length) {
    final map = <Object?, Object?>{};
    for (var i = 0; i < length; i++) {
      map[readValue()] = readValue();
    }
    return map;
  }

  String _readString(int length) {
    final end = _offset + length;
    if (end > bytes.length) throw const FormatException('نص مقطوع');
    final value = utf8.decode(bytes.sublist(_offset, end));
    _offset = end;
    return value;
  }

  int _readByte() {
    if (_offset >= bytes.length) throw const FormatException('ملف مقطوع');
    return bytes[_offset++];
  }

  int _readUint16() {
    final value = ByteData.sublistView(bytes, _offset, _offset + 2)
        .getUint16(0, Endian.big);
    _offset += 2;
    return value;
  }

  int _readUint32() {
    final value = ByteData.sublistView(bytes, _offset, _offset + 4)
        .getUint32(0, Endian.big);
    _offset += 4;
    return value;
  }

  int _readInt8() {
    final value = ByteData.sublistView(bytes, _offset, _offset + 1).getInt8(0);
    _offset += 1;
    return value;
  }

  int _readInt16() {
    final value = ByteData.sublistView(bytes, _offset, _offset + 2)
        .getInt16(0, Endian.big);
    _offset += 2;
    return value;
  }

  int _readInt32() {
    final value = ByteData.sublistView(bytes, _offset, _offset + 4)
        .getInt32(0, Endian.big);
    _offset += 4;
    return value;
  }
}

class _MsgpackWriter {
  final _bytes = <int>[];

  List<int> write(Object? value) {
    _writeValue(value);
    return _bytes;
  }

  void _writeValue(Object? value) {
    if (value == null) {
      _bytes.add(0xc0);
    } else if (value is bool) {
      _bytes.add(value ? 0xc3 : 0xc2);
    } else if (value is int) {
      _writeInt(value);
    } else if (value is String) {
      _writeString(value);
    } else if (value is List) {
      _writeArray(value);
    } else if (value is Map) {
      _writeMap(value);
    } else {
      throw ArgumentError('Unsupported value: $value');
    }
  }

  void _writeInt(int value) {
    if (value >= 0 && value <= 0x7f) {
      _bytes.add(value);
    } else if (value >= 0 && value <= 0xff) {
      _bytes.addAll([0xcc, value]);
    } else if (value >= 0 && value <= 0xffff) {
      _bytes.add(0xcd);
      _addUint16(value);
    } else if (value >= 0 && value <= 0xffffffff) {
      _bytes.add(0xce);
      _addUint32(value);
    } else {
      throw ArgumentError('Integer out of supported range: $value');
    }
  }

  void _writeString(String value) {
    final encoded = utf8.encode(value);
    final length = encoded.length;
    if (length <= 31) {
      _bytes.add(0xa0 | length);
    } else if (length <= 0xff) {
      _bytes.addAll([0xd9, length]);
    } else if (length <= 0xffff) {
      _bytes.add(0xda);
      _addUint16(length);
    } else {
      _bytes.add(0xdb);
      _addUint32(length);
    }
    _bytes.addAll(encoded);
  }

  void _writeArray(List value) {
    final length = value.length;
    if (length <= 15) {
      _bytes.add(0x90 | length);
    } else if (length <= 0xffff) {
      _bytes.add(0xdc);
      _addUint16(length);
    } else {
      _bytes.add(0xdd);
      _addUint32(length);
    }
    for (final item in value) {
      _writeValue(item);
    }
  }

  void _writeMap(Map value) {
    final length = value.length;
    if (length <= 15) {
      _bytes.add(0x80 | length);
    } else if (length <= 0xffff) {
      _bytes.add(0xde);
      _addUint16(length);
    } else {
      _bytes.add(0xdf);
      _addUint32(length);
    }
    for (final entry in value.entries) {
      _writeValue(entry.key);
      _writeValue(entry.value);
    }
  }

  void _addUint16(int value) {
    _bytes.addAll([(value >> 8) & 0xff, value & 0xff]);
  }

  void _addUint32(int value) {
    _bytes.addAll([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }
}
