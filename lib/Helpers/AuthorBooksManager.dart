// lib/Helpers/AuthorBooksManager.dart
import '../Models/BookCard.dart';
import 'BooksMetadataDatabase.dart';

/// Helper class for managing author-book relationships
class AuthorBooksManager {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();

  /// Gets all books for a specific author
  Future<List<BookCard>> getAuthorBooks(String authorId) async {
    await _db.initialize();
    return await _db.getBooks(authorId: authorId);
  }

  /// Gets all available books (with optional search query)
  Future<List<BookCard>> getAllBooks({String? searchQuery, int? limit}) async {
    await _db.initialize();
    return await _db.getBooks(searchQuery: searchQuery, limit: limit);
  }

  /// Links a book to an author by updating the book's author_id
  Future<void> linkBookToAuthor(String bookId, String authorId) async {
    await _db.initialize();
    final db = await _db.database;
    
    final book = await _db.getBookById(bookId);
    if (book == null) {
      throw Exception('Book not found');
    }

    final updatedBook = book.copyWith(authorId: authorId);
    final bookPath = await _getBookPath(bookId);
    if (bookPath == null) {
      throw Exception('Book path not found');
    }

    await _db.saveBook(updatedBook, bookPath);
  }

  /// Unlinks a book from an author by setting author_id to empty
  Future<void> unlinkBookFromAuthor(String bookId) async {
    await _db.initialize();
    final db = await _db.database;
    
    final book = await _db.getBookById(bookId);
    if (book == null) {
      throw Exception('Book not found');
    }

    final updatedBook = book.copyWith(authorId: '');
    final bookPath = await _getBookPath(bookId);
    if (bookPath == null) {
      throw Exception('Book path not found');
    }

    await _db.saveBook(updatedBook, bookPath);
  }

  /// Links multiple books to an author
  Future<void> linkBooksToAuthor(List<String> bookIds, String authorId) async {
    await _db.initialize();
    final db = await _db.database;
    final batch = db.batch();

    for (final bookId in bookIds) {
      final book = await _db.getBookById(bookId);
      if (book == null) continue;

      final bookPath = await _getBookPath(bookId);
      if (bookPath == null) continue;

      final updatedBook = book.copyWith(authorId: authorId);
      batch.update(
        'books',
        {
          'author_id': authorId,
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Unlinks multiple books from an author
  Future<void> unlinkBooksFromAuthor(List<String> bookIds) async {
    await _db.initialize();
    final db = await _db.database;
    final batch = db.batch();

    for (final bookId in bookIds) {
      batch.update(
        'books',
        {
          'author_id': null,
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Gets book path by book ID
  Future<String?> _getBookPath(String bookId) async {
    final db = await _db.database;
    final results = await db.query(
      'books',
      columns: ['book_path'],
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['book_path'] as String?;
  }

  /// Gets book by ID
  Future<BookCard?> getBookById(String bookId) async {
    await _db.initialize();
    return await _db.getBookById(bookId);
  }

  /// Gets book by path
  Future<BookCard?> getBookByPath(String bookPath) async {
    await _db.initialize();
    return await _db.getBookByPath(bookPath);
  }

  /// Counts books for an author
  Future<int> countAuthorBooks(String authorId) async {
    await _db.initialize();
    return await _db.countBooks(authorId: authorId);
  }
}

