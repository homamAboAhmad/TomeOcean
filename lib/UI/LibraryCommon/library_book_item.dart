import 'package:golden_shamela/Models/BookCard.dart';
import 'library_text_normalizer.dart';

class LibraryBookItem {
  final String bookPath;
  final BookCard book;
  final String authorName;
  final String authorDeathYear;
  final String authorDescription;
  final String sectionTitle;
  late final String normalizedTitle = LibraryTextNormalizer.normalize(title);
  late final String normalizedTitleAuthor =
      LibraryTextNormalizer.normalize('$title $authorName');

  LibraryBookItem({
    required this.bookPath,
    required this.book,
    this.authorName = '',
    this.authorDeathYear = '',
    this.authorDescription = '',
    this.sectionTitle = '',
  });

  String get title => book.title;

  LibraryBookItem withDetails({
    required BookCard book,
    required String authorDescription,
  }) {
    return LibraryBookItem(
      bookPath: bookPath,
      book: book,
      authorName: authorName,
      authorDeathYear: authorDeathYear,
      authorDescription: authorDescription,
      sectionTitle: sectionTitle,
    );
  }

  String get authorDisplay {
    if (authorName.isEmpty) return 'مؤلف غير محدد';
    if (authorDeathYear.isEmpty) return authorName;
    return '$authorName ($authorDeathYear)';
  }
}
