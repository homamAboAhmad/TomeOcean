import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/BookPart.dart';

class PageCommentsBookResolver {
  const PageCommentsBookResolver._();

  static Future<Map<String, PageCommentsBookMatch>> booksBySourceId(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final metadataDb = BooksMetadataDatabase();
    final db = await metadataDb.database;
    final rows = await db.query('books', columns: [
      'id',
      'book_id',
      'book_path',
      'book_name',
    ]);
    final result = <String, PageCommentsBookMatch>{};
    for (final row in rows) {
      final bookPath = row['book_path']?.toString() ?? '';
      final match = PageCommentsBookMatch(
        bookPath: bookPath,
        bookName: row['book_name']?.toString() ?? '',
        parts: await metadataDb.getBookParts(bookPath),
      );
      final bookId = row['book_id']?.toString();
      final id = row['id']?.toString();
      if (bookId != null && ids.contains(bookId)) result[bookId] = match;
      if (id != null && ids.contains(id)) result[id] = match;
    }
    return result;
  }

  static Future<Map<String, String>> bookIdsByPath() async {
    final db = await BooksMetadataDatabase().database;
    final rows = await db.query('books', columns: ['book_path', 'book_id']);
    return {
      for (final row in rows)
        if (_nonEmpty(row['book_path']?.toString()) != null)
          row['book_path'].toString(): row['book_id']?.toString() ?? '',
    };
  }

  static Future<Map<String, List<BookPart>>> partsByPath() async {
    final db = await BooksMetadataDatabase().database;
    final rows = await db.query(
      'book_parts',
      orderBy: 'book_path ASC, part_number ASC',
    );
    final result = <String, List<BookPart>>{};
    for (final row in rows) {
      final part = BookPart.fromRow(row);
      result.putIfAbsent(part.bookPath, () => []).add(part);
    }
    return result;
  }

  static BookPart? partForGlobalPage(List<BookPart> parts, int pageIndex) {
    for (final part in parts) {
      if (pageIndex >= part.pageOffset &&
          pageIndex < part.pageOffset + part.pageCount) {
        return part;
      }
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class PageCommentsBookMatch {
  final String bookPath;
  final String bookName;
  final List<BookPart> parts;

  const PageCommentsBookMatch({
    required this.bookPath,
    required this.bookName,
    required this.parts,
  });

  int globalPageIndex(String? partNumberText, int pageNumber) {
    final partNumber = int.tryParse(partNumberText ?? '');
    if (partNumber == null || parts.isEmpty) return pageNumber - 1;
    for (final part in parts) {
      if (part.partNumber == partNumber) {
        return part.pageOffset + pageNumber - 1;
      }
    }
    return pageNumber - 1;
  }
}
