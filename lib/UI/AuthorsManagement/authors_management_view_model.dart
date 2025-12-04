// lib/UI/AuthorsManagement/authors_management_view_model.dart
import '../../Models/Author.dart';
import '../../Helpers/AuthorStorage.dart';
import '../../Helpers/AuthorBooksManager.dart';

/// ViewModel for authors management screen - handles state and business logic
class AuthorsManagementViewModel {
  final AuthorStorage _authorStorage = AuthorStorage();
  final AuthorBooksManager _booksManager = AuthorBooksManager();
  
  List<Author> allAuthors = [];
  List<Author> filteredAuthors = [];
  Map<String, int> authorBookCounts = {};
  bool isLoading = false;

  /// Loads all authors and their book counts
  Future<void> loadAuthors() async {
    isLoading = true;
    try {
      final authors = await _authorStorage.getAuthorsAsync(limit: 10000);
      final bookCounts = <String, int>{};
      
      // Load book counts for each author
      for (var author in authors) {
        try {
          final books = await _booksManager.getAuthorBooks(author.id);
          bookCounts[author.id] = books.length;
        } catch (e) {
          bookCounts[author.id] = 0;
        }
      }
      
      allAuthors = authors;
      filteredAuthors = authors;
      authorBookCounts = bookCounts;
    } finally {
      isLoading = false;
    }
  }

  /// Filters authors based on search query
  void filterAuthors(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty) {
      filteredAuthors = allAuthors;
    } else {
      filteredAuthors = allAuthors.where((author) {
        return author.name.toLowerCase().contains(lowerQuery) ||
               (author.deathYear?.toLowerCase().contains(lowerQuery) ?? false) ||
               author.description.toLowerCase().contains(lowerQuery);
      }).toList();
    }
  }

  /// Deletes an author
  Future<void> deleteAuthor(String authorId) async {
    await _authorStorage.removeAuthor(authorId);
  }

  /// Gets total books count
  int getTotalBooksCount() {
    return authorBookCounts.values.fold(0, (a, b) => a + b);
  }
}

