// lib/Dialogs/BookCard/book_card_dialog_controller.dart
import '../../Models/BookCard.dart';
import '../../Models/Author.dart';
import '../../Models/Section.dart';
import '../../Helpers/AuthorStorage.dart';
import '../../Helpers/SectionStorage.dart';

/// Controller for book card dialog business logic
class BookCardDialogController {
  final AuthorStorage _authorStorage = AuthorStorage();
  final SectionStorage _sectionStorage = SectionStorage();

  /// Loads all data needed for the dialog
  Future<BookCardDialogData> loadDialogData(BookCard book) async {
    final sections = await _sectionStorage.getSectionsAsync(limit: 1000);
    final authors = await _authorStorage.getAuthorsAsync(limit: 1000);
    
    final section = await _sectionStorage.getSectionById(book.sectionId);
    final author = await AuthorStorage.getAuthorById(book.authorId);

    return BookCardDialogData(
      sections: sections,
      authors: authors,
      sectionTitle: section?.title ?? 'غير محدد',
      authorName: author?.name ?? 'غير محدد',
      selectedSectionId: book.sectionId,
      selectedAuthorId: book.authorId,
    );
  }

  /// Reloads authors list after adding a new author
  Future<List<Author>> reloadAuthors() async {
    return await _authorStorage.getAuthorsAsync(limit: 1000);
  }

  /// Creates updated book card from form data
  BookCard createUpdatedBookCard({
    required BookCard originalBook,
    required String title,
    required String? sectionId,
    required String? authorId,
    required String description,
    required String? bookType,
    required bool matchesPrinted,
    required String publisher,
    required String edition,
    required String pageCount,
  }) {
    return originalBook.copyWith(
      title: title.trim(),
      sectionId: sectionId ?? '',
      authorId: authorId ?? '',
      description: description.trim(),
      bookType: bookType ?? '',
      matchesPrinted: matchesPrinted,
      publisher: publisher.trim(),
      edition: edition.trim(),
      pageCount: pageCount.trim(),
    );
  }
}

/// Data class for dialog state
class BookCardDialogData {
  final List<Section> sections;
  final List<Author> authors;
  final String sectionTitle;
  final String authorName;
  final String? selectedSectionId;
  final String? selectedAuthorId;

  BookCardDialogData({
    required this.sections,
    required this.authors,
    required this.sectionTitle,
    required this.authorName,
    required this.selectedSectionId,
    required this.selectedAuthorId,
  });
}

