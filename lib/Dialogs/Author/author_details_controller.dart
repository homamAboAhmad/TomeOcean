// lib/Dialogs/Author/author_details_controller.dart
import '../../Models/Author.dart';
import '../../Models/BookCard.dart';
import '../../Helpers/AuthorStorage.dart';
import '../../Helpers/AuthorBooksManager.dart';

/// Controller for author details dialog business logic
class AuthorDetailsController {
  final AuthorStorage _authorStorage = AuthorStorage();
  final AuthorBooksManager _booksManager = AuthorBooksManager();

  /// Loads author data
  Future<Author?> loadAuthor(String authorId) async {
    return await AuthorStorage.getAuthorById(authorId);
  }

  /// Loads author's books
  Future<List<BookCard>> loadAuthorBooks(String authorId) async {
    return await _booksManager.getAuthorBooks(authorId);
  }

  /// Deletes an author
  Future<void> deleteAuthor(String authorId) async {
    await _authorStorage.removeAuthor(authorId);
  }

  /// Counts author's books
  Future<int> countAuthorBooks(String authorId) async {
    return await _booksManager.countAuthorBooks(authorId);
  }
}

