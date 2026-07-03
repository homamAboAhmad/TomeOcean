import 'dart:io';

class BookSourceFingerprint {
  const BookSourceFingerprint._();

  static Future<String?> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
  }

  static DateTime? modifiedAt(String? fingerprint) {
    if (fingerprint == null || fingerprint.isEmpty) return null;
    final parts = fingerprint.split(':');
    if (parts.length != 2) return null;
    final millis = int.tryParse(parts[1]);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
