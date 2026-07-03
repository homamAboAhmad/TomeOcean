import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_selection.dart';

/// Logic for determining which books to search in based on filters and selections.
class BookSelectionLogic {
  final SearchExecutor _searchExecutor;
  final BooksMetadataDatabase _metadataDb;

  BookSelectionLogic({
    required SearchExecutor searchExecutor,
    required BooksMetadataDatabase metadataDb,
  })  : _searchExecutor = searchExecutor,
        _metadataDb = metadataDb;

  /// Determines which books to search in based on selected filters.
  Future<List<String>?> determineBooksToSearch({
    required List<Map<String, dynamic>> selectedBooksForSearch,
    required List<Map<String, dynamic>> filteredIndexedBooks,
    required List<Map<String, dynamic>> allIndexedBooks,
    required Map<String, bool> selectedBooks,
    Map<String, String> bookAuthorMap = const {},
  }) async {
    final selection = SearchScopeSelection.fromItems(selectedBooksForSearch);
    if (!selection.isEmpty) {
      final paths = await SearchScopeBookResolver(_metadataDb).resolveBookPaths(
        selection: selection,
        filteredIndexedBooks: allIndexedBooks,
        bookAuthorMap: bookAuthorMap,
      );
      return paths.toList();
    }

    return _searchExecutor.determineBooksToSearch(
      filteredIndexedBooks: filteredIndexedBooks,
      allIndexedBooks: allIndexedBooks,
      selectedBooks: selectedBooks,
    );
  }
}
