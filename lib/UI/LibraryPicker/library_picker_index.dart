import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';

class LibraryPickerIndex {
  final List<LibraryBookItem> books;
  late final Map<String, LibraryBookItem> byPath = {
    for (final book in books) book.bookPath: book,
  };
  late final Map<String, int> sectionCounts =
      _countBy((book) => book.book.sectionId);
  late final Map<String, int> authorCounts =
      _countBy((book) => book.book.authorId);

  LibraryPickerIndex(this.books);

  bool matchesTitle(LibraryBookItem book, String query) {
    return book.normalizedTitle.contains(LibraryTextNormalizer.normalize(query));
  }

  bool matchesTitleAuthor(LibraryBookItem book, String query) {
    return book.normalizedTitleAuthor.contains(
      LibraryTextNormalizer.normalize(query),
    );
  }

  Map<String, int> _countBy(String Function(LibraryBookItem) idOf) {
    final counts = <String, int>{};
    for (final book in books) {
      final id = idOf(book);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  static List<Author> sortedAuthors(
    List<Author> authors, {
    required bool byName,
  }) {
    final sorted = List<Author>.of(authors);
    sorted.sort(byName ? _compareByName : _compareByDeathYear);
    return sorted;
  }

  static int _compareByName(Author left, Author right) =>
      left.name.compareTo(right.name);

  static int _compareByDeathYear(Author left, Author right) {
    final leftValue = _deathSortValue(left.deathYear);
    final rightValue = _deathSortValue(right.deathYear);
    if (leftValue != rightValue) return leftValue.compareTo(rightValue);
    return left.name.compareTo(right.name);
  }

  static int _deathSortValue(String? deathYear) {
    final value = deathYear?.trim() ?? '';
    if (value.isEmpty || value.contains('غير')) return 999999;
    if (value.contains('معاصر')) return 999998;
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? 999999;
  }
}
