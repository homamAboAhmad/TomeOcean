import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:path/path.dart' as p;
import 'indexed_book_title_resolver.dart';

class IndexedBookLibraryAdapter {
  const IndexedBookLibraryAdapter._();

  static List<LibraryBookItem> toItems(
    List<Map<String, dynamic>> books, {
    List<Author> authors = const [],
    Map<String, String> bookAuthorMap = const {},
    Map<String, String> authorDeathYears = const {},
  }) {
    final authorsById = {for (final author in authors) author.id: author};
    final normalizedAuthorMap = {
      for (final entry in bookAuthorMap.entries)
        _normalizePath(entry.key): entry.value,
    };
    final items = books.map((book) {
      final bookPath = book['book_path'] as String;
      final authorId = resolveAuthorId(
        book,
        normalizedBookAuthorMap: normalizedAuthorMap,
      );
      final author = authorsById[authorId];
      return LibraryBookItem(
        bookPath: bookPath,
        book: BookCard(
          title: IndexedBookTitleResolver.resolve(book),
          authorId: authorId,
        ),
        authorName: author?.name ?? _directAuthorName(book),
        authorDeathYear:
            author?.deathYear ?? authorDeathYears[authorId] ?? '',
      );
    }).toList();
    items.sort(LibraryBookItem.compareByAuthorDeathThenTitle);
    return items;
  }

  static String resolveAuthorId(
    Map<String, dynamic> book, {
    Map<String, String> bookAuthorMap = const {},
    Map<String, String> normalizedBookAuthorMap = const {},
  }) {
    final bookPath = book['book_path'] as String? ?? '';
    final normalizedMap = normalizedBookAuthorMap.isEmpty
        ? {
            for (final entry in bookAuthorMap.entries)
              _normalizePath(entry.key): entry.value,
          }
        : normalizedBookAuthorMap;
    return normalizedMap[_normalizePath(bookPath)] ??
        _firstNonEmpty([book['authorId'], book['author_id']]) ??
        '';
  }

  static String _directAuthorName(Map<String, dynamic> book) =>
      _firstNonEmpty([book['authorName'], book['author_name']]) ?? '';

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String _normalizePath(String path) => p.normalize(path).toLowerCase();
}
