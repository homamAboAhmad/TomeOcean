import 'package:path/path.dart' as p;

abstract final class SearchBookSubsetBuilder {
  static List<Map<String, dynamic>> favoriteBooks(
    List<Map<String, dynamic>> allBooks,
    Set<String> favoritePaths,
  ) {
    final favorites = favoritePaths.map(_normalizePath).toSet();
    return allBooks.where((book) {
      return favorites.contains(_normalizePath(book['book_path'] as String));
    }).toList();
  }

  static List<Map<String, dynamic>> recentBooks(
    List<Map<String, dynamic>> allBooks,
    List<String> recentPaths,
  ) {
    final byPath = {
      for (final book in allBooks)
        _normalizePath(book['book_path'] as String): book,
    };
    return recentPaths
        .map((path) => byPath[_normalizePath(path)])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static String _normalizePath(String path) => p.normalize(path).toLowerCase();
}
