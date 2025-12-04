// lib/Dialogs/Author/author_details_view_model.dart
import '../../Models/Author.dart';
import '../../Models/BookCard.dart';
import 'author_details_controller.dart';

/// ViewModel for author details dialog - handles state and business logic
class AuthorDetailsViewModel {
  final AuthorDetailsController _controller = AuthorDetailsController();
  
  Author? author;
  List<BookCard> books = [];
  bool isLoading = false;
  bool isDeleting = false;

  /// Loads author and books data
  Future<void> loadData(String authorId) async {
    isLoading = true;
    try {
      author = await _controller.loadAuthor(authorId);
      books = await _controller.loadAuthorBooks(authorId);
    } finally {
      isLoading = false;
    }
  }

  /// Deletes the author
  Future<void> deleteAuthor(String authorId) async {
    isDeleting = true;
    try {
      await _controller.deleteAuthor(authorId);
    } finally {
      isDeleting = false;
    }
  }

  /// Reloads data after update
  Future<void> reloadData(String authorId) async {
    await loadData(authorId);
  }
}

