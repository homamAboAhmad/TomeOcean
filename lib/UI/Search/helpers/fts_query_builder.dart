class FtsQueryBuilder {
  static final RegExp _tokenSeparator = RegExp(
    r'[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFFa-zA-Z0-9\u0660-\u0669\s]+',
  );

  static String clean(String value) {
    return value
        .replaceAll(_tokenSeparator, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> tokens(String value) {
    final cleaned = clean(value);
    if (cleaned.isEmpty) return const [];
    return cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  static String formatTerm(String value, {required bool affixSearch}) {
    final queryTokens = tokens(value);
    if (queryTokens.isEmpty) return '';

    if (affixSearch) {
      return queryTokens.map((token) => '$token*').join(' AND ');
    }

    if (queryTokens.length == 1) {
      return queryTokens.first;
    }

    return '"${queryTokens.join(' ')}"';
  }

  static String joinTerms(
    Iterable<String> terms,
    String operator, {
    required bool affixSearch,
  }) {
    final formatted = terms
        .map((term) => formatTerm(term, affixSearch: affixSearch))
        .where((term) => term.isNotEmpty)
        .toList();
    if (formatted.isEmpty) return '';
    if (formatted.length == 1) return formatted.first;
    return formatted.map((term) => '($term)').join(' $operator ');
  }
}
