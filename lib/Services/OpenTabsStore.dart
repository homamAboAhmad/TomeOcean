import 'dart:convert';

import 'package:golden_shamela/Services/BookPositionStore.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

class OpenTabRecord {
  static const typeBook = 'book';
  static const typeLibraryData = 'libraryData';
  static const typeRecitedText = 'recitedText';

  final String type;
  final String bookPath;
  final int pageIndex;
  final String source;

  const OpenTabRecord({
    this.type = typeBook,
    required this.bookPath,
    required this.pageIndex,
    required this.source,
  });

  factory OpenTabRecord.fromJson(Map<String, dynamic> json) {
    return OpenTabRecord(
      type: json['type'] as String? ?? typeBook,
      bookPath: json['bookPath'] as String? ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? BookOpenSource.other,
    );
  }

  bool get isBook => type == typeBook;

  bool get isFixedTab => type == typeLibraryData || type == typeRecitedText;

  bool get isRestorable => (isBook && bookPath.isNotEmpty) || isFixedTab;

  Map<String, Object> toJson() => {
        'type': type,
        'bookPath': bookPath,
        'pageIndex': pageIndex,
        'source': source,
      };
}

class OpenTabsStore {
  static final instance = OpenTabsStore._();
  static const _prefsKey = 'open_tabs_v1';

  OpenTabsStore._();

  List<OpenTabRecord> load() {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => OpenTabRecord.fromJson(Map<String, dynamic>.from(item)))
          .where((record) => record.isRestorable)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<OpenTabRecord> records) {
    final rows = records.where((record) => record.isRestorable).toList();
    return PreferencesHelper.prefs.setString(
      _prefsKey,
      jsonEncode(rows.map((record) => record.toJson()).toList()),
    );
  }
}
