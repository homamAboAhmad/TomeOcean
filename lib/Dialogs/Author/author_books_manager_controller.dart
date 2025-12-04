// lib/Dialogs/Author/author_books_manager_controller.dart
import '../../Models/BookCard.dart';
import '../../Helpers/AuthorBooksManager.dart';

/// Controller for author books manager dialog business logic
class AuthorBooksManagerController {
  final AuthorBooksManager _booksManager = AuthorBooksManager();

  /// Gets all available books
  Future<List<BookCard>> getAllBooks({String? searchQuery}) async {
    return await _booksManager.getAllBooks(
      searchQuery: searchQuery,
      limit: 1000,
    );
  }

  /// Gets author's books
  Future<List<BookCard>> getAuthorBooks(String authorId) async {
    return await _booksManager.getAuthorBooks(authorId);
  }

  /// Links books to author
  Future<void> linkBooksToAuthor(List<String> bookIds, String authorId) async {
    await _booksManager.linkBooksToAuthor(bookIds, authorId);
  }

  /// Unlinks books from author
  Future<void> unlinkBooksFromAuthor(List<String> bookIds) async {
    await _booksManager.unlinkBooksFromAuthor(bookIds);
  }
}

