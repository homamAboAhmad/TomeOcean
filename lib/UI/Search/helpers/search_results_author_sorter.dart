import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';

class SearchResultsAuthorSorter {
  const SearchResultsAuthorSorter._();

  static void sort(
    List<Map<String, dynamic>> results, {
    required Map<String, String> bookAuthorMap,
    required Map<String, String> authorDeathYears,
  }) {
    if (results.length < 2 || bookAuthorMap.isEmpty) return;
    final normalizedBookAuthorMap = {
      for (final entry in bookAuthorMap.entries)
        _normalizePath(entry.key): entry.value,
    };
    results.sort((left, right) {
      final death = AuthorDeathDateParser.compare(
        _deathYearFor(
          left,
          bookAuthorMap,
          normalizedBookAuthorMap,
          authorDeathYears,
        ),
        _deathYearFor(
          right,
          bookAuthorMap,
          normalizedBookAuthorMap,
          authorDeathYears,
        ),
      );
      if (death != 0) return death;
      final book = _bookName(left).compareTo(_bookName(right));
      if (book != 0) return book;
      return _pageNumber(left).compareTo(_pageNumber(right));
    });
  }

  static String? _deathYearFor(
    Map<String, dynamic> result,
    Map<String, String> bookAuthorMap,
    Map<String, String> normalizedBookAuthorMap,
    Map<String, String> authorDeathYears,
  ) {
    final path = _bookPath(result);
    final authorId =
        bookAuthorMap[path] ?? normalizedBookAuthorMap[_normalizePath(path)];
    return authorDeathYears[authorId];
  }

  static String _bookPath(Map<String, dynamic> result) {
    return (result['book_path'] ?? result['bookPath'])?.toString() ?? '';
  }

  static String _bookName(Map<String, dynamic> result) {
    return (result['book_name'] ?? result['bookTitle'])?.toString() ?? '';
  }

  static int _pageNumber(Map<String, dynamic> result) {
    final value = result['page_number'] ?? result['pageNumber'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  static String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase().trim();
  }
}
