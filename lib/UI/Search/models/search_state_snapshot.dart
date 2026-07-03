class SearchStateSnapshot {
  final Map<String, List<String>> groupQueries;
  final String searchGrouping;
  final Map<String, bool> searchSections;
  final Map<String, bool> options;

  const SearchStateSnapshot({
    this.groupQueries = const {},
    this.searchGrouping = 'all',
    this.searchSections = const {},
    this.options = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'groupQueries': groupQueries.map(
        (key, values) => MapEntry(key, List<String>.from(values)),
      ),
      'searchGrouping': searchGrouping,
      'searchSections': Map<String, bool>.from(searchSections),
      'options': Map<String, bool>.from(options),
    };
  }

  factory SearchStateSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SearchStateSnapshot();
    return SearchStateSnapshot(
      groupQueries: _readStringListMap(json['groupQueries']),
      searchGrouping: json['searchGrouping'] as String? ?? 'all',
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

  static Map<String, bool> _readBoolMap(dynamic value) {
    final source = value is Map ? value : const {};
    return source.map(
      (key, rawValue) => MapEntry(key.toString(), rawValue == true),
    );
  }
}
