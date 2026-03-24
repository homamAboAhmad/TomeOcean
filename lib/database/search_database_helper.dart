// Legacy stub — kept only so the unused search_dialog.dart compiles.
// The active search system uses ShamelaSearchEngine / SQLite FTS5.

enum SearchType { normalized, exact, stemmed }

class SearchResult {
  final String bookName;
  final String snippet;
  final int pageIndex;
  SearchResult({this.bookName = '', this.snippet = '', this.pageIndex = 0});
}

class PaginatedSearchResults {
  final List<SearchResult> results;
  final int totalCount;
  PaginatedSearchResults({this.results = const [], this.totalCount = 0});
}

class SearchDatabaseHelper {
  SearchDatabaseHelper._();
  static final instance = SearchDatabaseHelper._();

  Future<PaginatedSearchResults> search(
    String query,
    SearchType type, {
    int limit = 50,
    int offset = 0,
    String? authorId,
    String? sectionId,
  }) async {
    return PaginatedSearchResults();
  }
}
