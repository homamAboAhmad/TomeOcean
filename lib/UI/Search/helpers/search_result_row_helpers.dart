class SearchResultRowHelpers {
  SearchResultRowHelpers._();

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');

  static int asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool isComment(Map<String, dynamic> result) {
    return result['section_type']?.toString() == 'comment';
  }

  static String firstKey(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return '';
    final result = results.first;
    final bookPath = (result['bookPath'] ?? result['book_path'])?.toString();
    if (bookPath == null || bookPath.isEmpty) return '';
    final pageNumber = asInt(result['pageNumber'] ?? result['page_number']);
    return '$bookPath|$pageNumber';
  }

  static String cleanSnippet(String content) {
    final cleaned = content
        .replaceAll(_pgMarkerRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length <= 220 ? cleaned : '${cleaned.substring(0, 220)}...';
  }
}
