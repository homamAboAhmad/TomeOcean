import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';
import 'library_text_normalizer.dart';

class LibraryBookItem {
  final String bookPath;
  final BookCard book;
  final String authorName;
  final String authorDeathYear;
  final String authorDescription;
  final String sectionTitle;
  final String bookBrief;
  late final String normalizedTitle = LibraryTextNormalizer.normalize(title);
  late final String normalizedTitleAuthor =
      LibraryTextNormalizer.normalize('$title $authorName');
  late final String bookCardSearchText = [
    title,
    authorDisplay,
    sectionTitle,
    BookMetadataOptions.typeLabel(book.bookType),
    book.matchesPrinted ? 'موافق للمطبوع' : 'غير موافق للمطبوع',
    book.publisher,
    book.edition,
    book.pageCount,
    book.description,
    bookBrief,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  LibraryBookItem({
    required this.bookPath,
    required this.book,
    this.authorName = '',
    this.authorDeathYear = '',
    this.authorDescription = '',
    this.sectionTitle = '',
    this.bookBrief = '',
  });

  String get title => book.title;

  static int compareByAuthorDeathThenTitle(
    LibraryBookItem left,
    LibraryBookItem right,
  ) {
    final death = AuthorDeathDateParser.compare(
      left.authorDeathYear,
      right.authorDeathYear,
    );
    if (death != 0) return death;
    return left.title.compareTo(right.title);
  }

  LibraryBookItem withDetails({
    required BookCard book,
    required String authorDescription,
    String? bookBrief,
  }) {
    return LibraryBookItem(
      bookPath: bookPath,
      book: book,
      authorName: authorName,
      authorDeathYear: authorDeathYear,
      authorDescription: authorDescription,
      sectionTitle: sectionTitle,
      bookBrief: bookBrief ?? this.bookBrief,
    );
  }

  String get authorDisplay {
    if (authorName.isEmpty) return 'مؤلف غير محدد';
    if (authorDeathYear.isEmpty) return authorName;
    return '$authorName ($authorDeathYear)';
  }
}
