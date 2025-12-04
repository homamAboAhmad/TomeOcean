// lib/Dialogs/Author/author_books_manager_view_model.dart
import '../../Models/BookCard.dart';
import 'author_books_manager_controller.dart';

/// ViewModel for author books manager dialog - handles state and business logic
class AuthorBooksManagerViewModel {
  final AuthorBooksManagerController _controller = AuthorBooksManagerController();
  
  List<BookCard> allBooks = [];
  List<BookCard> filteredBooks = [];
  Set<String> selectedBookIds = {};
  Set<String> authorBookIds = {};
  bool isLoading = false;
  bool isSaving = false;

  /// Loads all books and author's books
  Future<void> loadData(String authorId) async {
    isLoading = true;
    try {
      allBooks = await _controller.getAllBooks();
      final authorBooks = await _controller.getAuthorBooks(authorId);
      authorBookIds = authorBooks.map((b) => b.id).toSet();
      filteredBooks = allBooks;
    } finally {
      isLoading = false;
    }
  }

  /// Filters books based on search query
  void filterBooks(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty) {
      filteredBooks = allBooks;
    } else {
      filteredBooks = allBooks.where((book) {
        return book.title.toLowerCase().contains(lowerQuery);
      }).toList();
    }
  }

  /// Toggles book selection
  void toggleBookSelection(String bookId, bool isSelected) {
    if (isSelected) {
      selectedBookIds.add(bookId);
    } else {
      selectedBookIds.remove(bookId);
    }
  }

  /// Links selected books to author
  Future<void> linkBooks(String authorId) async {
    if (selectedBookIds.isEmpty) return;
    
    isSaving = true;
    try {
      await _controller.linkBooksToAuthor(
        selectedBookIds.toList(),
        authorId,
      );
      selectedBookIds.clear();
      await loadData(authorId);
    } finally {
      isSaving = false;
    }
  }

  /// Unlinks selected books from author
  Future<void> unlinkBooks(String authorId) async {
    final booksToUnlink = getBooksToUnlink();
    
    if (booksToUnlink.isEmpty) return;

    isSaving = true;
    try {
      await _controller.unlinkBooksFromAuthor(booksToUnlink);
      selectedBookIds.clear();
      await loadData(authorId);
    } finally {
      isSaving = false;
    }
  }

  /// Gets list of books to unlink
  List<String> getBooksToUnlink() {
    return selectedBookIds
        .where((id) => authorBookIds.contains(id))
        .toList();
  }
}

