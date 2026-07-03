class SearchSummaryFormatter {
  static List<String> lines({
    required Map<String, List<String>> groupQueries,
    required String searchGrouping,
    required Map<String, bool> searchSections,
    required Map<String, bool> options,
    required List<Map<String, dynamic>> scopeItems,
  }) {
    return [
      _queryLine(groupQueries),
      _optionsLine(options, searchGrouping),
      _sectionsLine(searchSections),
      _scopeLine(scopeItems),
    ].where((line) => line.isNotEmpty).toList();
  }

  static String _queryLine(Map<String, List<String>> groupQueries) {
    final parts = <String>[];
    for (final key in const ['and', 'or', 'not']) {
      final queries = _cleanQueries(groupQueries[key]);
      if (queries.isEmpty) continue;
      parts.add('${_groupLabel(key)} ${_formatQueries(queries)}');
    }
    return parts.isEmpty ? '' : parts.join('  ');
  }

  static String _optionsLine(Map<String, bool> options, String searchGrouping) {
    final additions = <String>[];
    if (searchGrouping != 'all') additions.add('واحدة أو أكثر');
    if (options['morphologicalSearch'] == true) additions.add('صرفي');
    if (options['affixSearch'] == true) additions.add('لواصق');
    if (options['considerHamzas'] == true) additions.add('همزات');
    if (options['considerDiacritics'] == true) additions.add('تشكيل');
    if (options['considerNumbers'] == false) additions.add('دون أرقام');
    if (options['ordered'] == true) additions.add('مرتبة');
    if (options['proximity'] == true) additions.add('متقاربة');
    final suffix = additions.isEmpty ? '' : ' + ${additions.join(' - ')}';
    return 'الخيارات: الافتراضية$suffix';
  }

  static String _sectionsLine(Map<String, bool> searchSections) {
    final enabled = searchSections.entries
        .where((entry) => entry.value)
        .map((entry) => _sectionLabel(entry.key))
        .where((label) => label.isNotEmpty)
        .toList();
    if (enabled.isEmpty) return '';
    return 'البحث في: ${enabled.join(' - ')}';
  }

  static String _scopeLine(List<Map<String, dynamic>> scopeItems) {
    final counts = <String, int>{};
    for (final item in scopeItems) {
      final type = item['type']?.toString();
      if (type == null || type.isEmpty) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final parts = <String>[];
    _addCount(parts, counts, 'section', 'أقسام');
    _addCount(parts, counts, 'author', 'مؤلفون');
    _addCount(parts, counts, 'period', 'فترات');
    _addCount(parts, counts, 'book', 'كتب');
    return parts.isEmpty ? 'المجال: كل الكتب' : 'المجال: ${parts.join(' - ')}';
  }

  static List<String> _cleanQueries(List<String>? values) {
    return (values ?? const [])
        .map((query) => query.trim())
        .where((query) => query.isNotEmpty)
        .toList();
  }

  static String _formatQueries(List<String> queries) {
    if (queries.length == 1) return '[${queries.first}]';
    return '[${queries.join(' - ')}]';
  }

  static String _groupLabel(String key) {
    return switch (key) {
      'and' => 'و',
      'or' => 'أو',
      'not' => 'ليس',
      _ => key,
    };
  }

  static String _sectionLabel(String key) {
    return switch (key) {
      'main' => 'المتن',
      'footnote' => 'الحواشي',
      'title' => 'العناوين',
      'comment' => 'التعليقات',
      _ => '',
    };
  }

  static void _addCount(
    List<String> parts,
    Map<String, int> counts,
    String key,
    String label,
  ) {
    final count = counts[key] ?? 0;
    if (count > 0) parts.add('$label ($count)');
  }
}
