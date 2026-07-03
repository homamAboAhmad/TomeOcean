import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:path/path.dart' as p;
import 'indexed_book_title_resolver.dart';

/// Helper class to manage selected books and authors for search
class SelectedBooksManager {
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();
  
  /// Add books to selected list with metadata
  Future<List<Map<String, dynamic>>> addBooksToSelectedList(
    List<String> bookPaths,
    List<Author> allAuthors,
    Map<String, String> authorDeathYears,
    List<Map<String, dynamic>> indexedBooks,
  ) async {
    await _metadataDb.initialize();

    final indexedBooksByPath = {
      for (final book in indexedBooks)
        if (book['book_path'] is String)
          _normalizePath(book['book_path'] as String): book,
    };
    final newItems = <Map<String, dynamic>>[];
    for (var bookPath in bookPaths) {
      final bookCard = await _metadataDb.getBookByPath(bookPath);
      final indexedBook = indexedBooksByPath[_normalizePath(bookPath)];
      final indexedTitle = indexedBook == null
          ? null
          : IndexedBookTitleResolver.resolve(indexedBook);
      if (bookCard != null) {
        String? deathYear;
        if (bookCard.authorId.isNotEmpty) {
          final author = allAuthors.firstWhere(
            (a) => a.id == bookCard.authorId,
            orElse: () => Author(id: '', name: '', description: ''),
          );
          if (author.id.isNotEmpty) {
            deathYear = author.deathYear ?? authorDeathYears[author.id];
          }
        }
        
        newItems.add({
          'type': 'book',
          'name': indexedTitle ?? bookCard.title,
          'deathYear': deathYear,
          'bookPath': bookPath,
          'authorId': bookCard.authorId,
        });
      } else {
        final bookName =
            indexedTitle ?? AppStoragePaths.displayTitleFromPath(bookPath);
        newItems.add({
          'type': 'book',
          'name': bookName,
          'deathYear': null,
          'bookPath': bookPath,
          'authorId': null,
        });
      }
    }
    
    return newItems;
  }

  String _normalizePath(String path) => p.normalize(path).toLowerCase();

  /// Add an author as a search-scope item.
  Future<Map<String, dynamic>> addAuthorToSelectedList(
    String authorId,
    Author author,
    String? deathYear,
  ) async {
    final authorItem = {
      'type': 'author',
      'name': author.name,
      'deathYear': deathYear,
      'authorId': authorId,
      'bookPath': null,
    };

    return {'authorItem': authorItem};
  }
}
