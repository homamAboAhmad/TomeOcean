import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';

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
  }) async {
    final booksFromSections = await _getBooksFromSelectedSections(
      selectedBooksForSearch,
      filteredIndexedBooks,
    );
    final bookPathsFromSearch = _getBookPathsFromSelectedItems(selectedBooksForSearch);
    final booksFromAuthors = await _getBooksFromSelectedAuthors(
      selectedBooksForSearch,
      filteredIndexedBooks,
    );
    
    final allBooksToSearch = <String>{};
    if (booksFromSections != null) allBooksToSearch.addAll(booksFromSections);
    if (bookPathsFromSearch.isNotEmpty) allBooksToSearch.addAll(bookPathsFromSearch);
    if (booksFromAuthors != null) allBooksToSearch.addAll(booksFromAuthors);
    
    if (allBooksToSearch.isNotEmpty) {
      return allBooksToSearch.toList();
    }
    
    return _searchExecutor.determineBooksToSearch(
      filteredIndexedBooks: filteredIndexedBooks,
      allIndexedBooks: allIndexedBooks,
      selectedBooks: selectedBooks,
    );
  }

  /// Gets book paths from selected sections.
  Future<List<String>?> _getBooksFromSelectedSections(
    List<Map<String, dynamic>> selectedBooksForSearch,
    List<Map<String, dynamic>> filteredIndexedBooks,
  ) async {
    final sectionIds = selectedBooksForSearch
        .where((item) => item['type'] == 'section' && item['sectionId'] != null)
        .map((item) => item['sectionId'] as String)
        .toList();
    
    if (sectionIds.isEmpty) return null;
    
    await _metadataDb.initialize();
    final allBookPaths = <String>[];
    for (var sectionId in sectionIds) {
      final bookPaths = await _metadataDb.getBookPaths(sectionId: sectionId);
      allBookPaths.addAll(bookPaths);
    }
    
    return _filterBookPaths(allBookPaths, filteredIndexedBooks);
  }

  /// Gets book paths directly from selected items.
  List<String> _getBookPathsFromSelectedItems(
    List<Map<String, dynamic>> selectedBooksForSearch,
  ) {
    return selectedBooksForSearch
        .where((item) => item['type'] == 'book' && item['bookPath'] != null)
        .map((item) => item['bookPath'] as String)
        .toList();
  }

  /// Gets book paths from selected authors.
  Future<List<String>?> _getBooksFromSelectedAuthors(
    List<Map<String, dynamic>> selectedBooksForSearch,
    List<Map<String, dynamic>> filteredIndexedBooks,
  ) async {
    final authorIds = selectedBooksForSearch
        .where((item) => item['type'] == 'author' && item['authorId'] != null)
        .map((item) => item['authorId'] as String)
        .toSet();
    
    if (authorIds.isEmpty) return null;
    
    await _metadataDb.initialize();
    final allBookPaths = <String>[];
    for (var authorId in authorIds) {
      final bookPaths = await _metadataDb.getBookPaths(authorId: authorId);
      allBookPaths.addAll(bookPaths);
    }
    
    return _filterBookPaths(allBookPaths, filteredIndexedBooks);
  }

  /// Filters book paths to only include those in filtered indexed books.
  List<String> _filterBookPaths(
    List<String> bookPaths,
    List<Map<String, dynamic>> filteredIndexedBooks,
  ) {
    return bookPaths.where((bookPath) {
      return filteredIndexedBooks.any((book) => 
          book['book_path'] == bookPath);
    }).toList();
  }
}






