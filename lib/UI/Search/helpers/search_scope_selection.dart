import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/UI/Search/helpers/indexed_book_library_adapter.dart';
import 'package:golden_shamela/UI/Search/helpers/search_period_range.dart';
import 'package:path/path.dart' as p;

class SearchScopeSelection {
  final Set<String> bookPaths;
  final Set<String> authorIds;
  final Set<String> sectionIds;
  final List<SearchPeriodRange> periodRanges;

  const SearchScopeSelection({
    this.bookPaths = const {},
    this.authorIds = const {},
    this.sectionIds = const {},
    this.periodRanges = const [],
  });

  factory SearchScopeSelection.fromItems(List<Map<String, dynamic>> items) {
    return SearchScopeSelection(
      bookPaths: _valuesFor(items, type: 'book', key: 'bookPath'),
      authorIds: _valuesFor(items, type: 'author', key: 'authorId'),
      sectionIds: _valuesFor(items, type: 'section', key: 'sectionId'),
      periodRanges: SearchPeriodRange.fromSearchItems(items),
    );
  }

  bool get isEmpty =>
      bookPaths.isEmpty &&
      authorIds.isEmpty &&
      sectionIds.isEmpty &&
      periodRanges.isEmpty;

  static Set<String> _valuesFor(
    List<Map<String, dynamic>> items, {
    required String type,
    required String key,
  }) {
    return items
        .where((item) => item['type'] == type && item[key] != null)
        .map((item) => item[key].toString())
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}

class SearchScopeBookResolver {
  final BooksMetadataDatabase metadataDb;

  const SearchScopeBookResolver(this.metadataDb);

  Future<Set<String>> resolveBookPaths({
    required SearchScopeSelection selection,
    required List<Map<String, dynamic>> filteredIndexedBooks,
    Map<String, String> bookAuthorMap = const {},
  }) async {
    final resolved = <String>{...selection.bookPaths};
    if (selection.authorIds.isNotEmpty ||
        selection.sectionIds.isNotEmpty ||
        selection.periodRanges.isNotEmpty) {
      await metadataDb.initialize();
    }
    final availableByPath = _availableBooksByNormalizedPath(
      filteredIndexedBooks,
    );

    resolved.addAll(
      await _pathsForAuthors(
        selection.authorIds,
        availableByPath,
        filteredIndexedBooks,
        bookAuthorMap,
      ),
    );
    resolved.addAll(
      await _pathsForSections(selection.sectionIds, availableByPath),
    );
    resolved.addAll(
      await _pathsForPeriods(
        selection.periodRanges,
        availableByPath,
        filteredIndexedBooks,
        bookAuthorMap,
      ),
    );
    return resolved;
  }

  Future<Set<String>> selectedBookPathsForDisplay({
    required SearchScopeSelection selection,
    required List<Map<String, dynamic>> filteredIndexedBooks,
    Map<String, String> bookAuthorMap = const {},
  }) {
    return resolveBookPaths(
      selection: selection,
      filteredIndexedBooks: filteredIndexedBooks,
      bookAuthorMap: bookAuthorMap,
    );
  }

  Future<Set<String>> _pathsForAuthors(
    Set<String> authorIds,
    Map<String, String> availableByPath,
    List<Map<String, dynamic>> filteredIndexedBooks,
    Map<String, String> bookAuthorMap,
  ) async {
    if (authorIds.isEmpty) return {};
    final paths = <String>{};
    for (final authorId in authorIds) {
      final dbPaths = await metadataDb.getBookPaths(authorId: authorId);
      paths.addAll(_filterAvailablePaths(dbPaths, availableByPath));
    }
    if (paths.isNotEmpty) return paths;

    for (final book in filteredIndexedBooks) {
      final bookPath = book['book_path'] as String? ?? '';
      final authorId = IndexedBookLibraryAdapter.resolveAuthorId(
        book,
        bookAuthorMap: bookAuthorMap,
      );
      if (authorIds.contains(authorId)) paths.add(bookPath);
    }
    return paths;
  }

  Future<Set<String>> _pathsForSections(
    Set<String> sectionIds,
    Map<String, String> availableByPath,
  ) async {
    if (sectionIds.isEmpty) return {};
    final paths = <String>{};
    for (final sectionId in sectionIds) {
      final dbPaths = await metadataDb.getBookPaths(sectionId: sectionId);
      paths.addAll(_filterAvailablePaths(dbPaths, availableByPath));
    }
    return paths;
  }

  Future<Set<String>> _pathsForPeriods(
    List<SearchPeriodRange> ranges,
    Map<String, String> availableByPath,
    List<Map<String, dynamic>> filteredIndexedBooks,
    Map<String, String> bookAuthorMap,
  ) async {
    if (ranges.isEmpty) return {};
    final authors = await metadataDb.getAuthors();
    final matchingAuthorIds = authors
        .where(
          (author) => ranges.any((range) => range.containsDeathYear(
                author.deathYear,
              )),
        )
        .map((author) => author.id)
        .toSet();
    return _pathsForAuthors(
      matchingAuthorIds,
      availableByPath,
      filteredIndexedBooks,
      bookAuthorMap,
    );
  }

  Set<String> _filterAvailablePaths(
    List<String> paths,
    Map<String, String> availableByPath,
  ) {
    return paths
        .map((path) => availableByPath[_normalizePath(path)])
        .whereType<String>()
        .toSet();
  }

  Map<String, String> _availableBooksByNormalizedPath(
    List<Map<String, dynamic>> books,
  ) {
    return {
      for (final book in books)
        if (book['book_path'] is String)
          _normalizePath(book['book_path'] as String):
              book['book_path'] as String,
    };
  }

  String _normalizePath(String path) => p.normalize(path).toLowerCase();
}
