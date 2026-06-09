import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';

/// Helper class to manage selected books and authors for search
class SelectedBooksManager {
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();
  
  /// Add books to selected list with metadata
  Future<List<Map<String, dynamic>>> addBooksToSelectedList(
    List<String> bookPaths,
    List<Author> allAuthors,
    Map<String, String> authorDeathYears,
  ) async {
    await _metadataDb.initialize();
    
    final newItems = <Map<String, dynamic>>[];
    for (var bookPath in bookPaths) {
      final bookCard = await _metadataDb.getBookByPath(bookPath);
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
          'name': bookCard.title,
          'deathYear': deathYear,
          'bookPath': bookPath,
          'authorId': bookCard.authorId,
        });
      } else {
        final bookName = AppStoragePaths.displayTitleFromPath(bookPath);
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

  /// Add author and get their books
  Future<Map<String, dynamic>> addAuthorToSelectedList(
    String authorId,
    Author author,
    String? deathYear,
    List<Map<String, dynamic>> filteredIndexedBooks,
  ) async {
    await _metadataDb.initialize();
    
    final authorItem = {
      'type': 'author',
      'name': author.name,
      'deathYear': deathYear,
      'authorId': authorId,
      'bookPath': null,
    };
    
    final bookPaths = await _metadataDb.getBookPaths(authorId: authorId);
    final availableBookPaths = bookPaths.where((bookPath) {
      return filteredIndexedBooks.any((book) => 
          book['book_path'] == bookPath);
    }).toList();
    
    return {
      'authorItem': authorItem,
      'bookPaths': availableBookPaths,
    };
  }
}
