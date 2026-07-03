class SearchHistoryRecord {
  final String id;
  final int createdAt;
  final Map<String, List<String>> groupQueries;
  final String searchGrouping;
  final List<Map<String, dynamic>> scopeItems;
  final Map<String, bool> searchSections;
  final Map<String, bool> options;

  const SearchHistoryRecord({
    required this.id,
    required this.createdAt,
    required this.groupQueries,
    required this.searchGrouping,
    required this.scopeItems,
    required this.searchSections,
    required this.options,
  });

  List<String> get queries => groupQueries.values
      .expand((queries) => queries)
      .where((query) => query.trim().isNotEmpty)
      .toList();

  String get title => queries.isEmpty ? 'بحث بلا عبارة' : queries.join(' | ');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt,
      'groupQueries': groupQueries,
      'searchGrouping': searchGrouping,
      'scopeItems': scopeItems
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      'searchSections': searchSections,
      'options': options,
    };
  }

  factory SearchHistoryRecord.fromJson(Map<String, dynamic> json) {
    return SearchHistoryRecord(
      id: json['id'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      groupQueries: _readStringListMap(json['groupQueries']),
      searchGrouping: json['searchGrouping'] as String? ?? 'all',
      scopeItems: _readMapList(json['scopeItems']),
      searchSections: _readBoolMap(json['searchSections']),
      options: _readBoolMap(json['options']),
    );
  }

  static Map<String, List<String>> _readStringListMap(dynamic value) {
    final source = value is Map ? value : const {};
    return source.map((key, rawList) {
      final values = rawList is List ? rawList : const [];
      return MapEntry(
        key.toString(),
        values.map((item) => item.toString()).toList(),
      );
    });
  }

  static List<Map<String, dynamic>> _readMapList(dynamic value) {
    final source = value is List ? value : const [];
    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, bool> _readBoolMap(dynamic value) {
    final source = value is Map ? value : const {};
    return source.map(
      (key, rawValue) => MapEntry(key.toString(), rawValue == true),
    );
  }
}
