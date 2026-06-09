import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';

class LibraryPickerRepository {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();
  final Map<String, LibraryBookItem> _detailsCache = {};
  static const _detailsCacheLimit = 24;

  Future<List<LibraryBookItem>> loadBooks() async {
    _detailsCache.clear();
    await _db.initialize();
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.id, b.book_name, b.book_path, b.author_id, b.section_id,
             b.book_type, b.matches_printed,
             a.name AS author_name, a.death_year AS author_death_year,
             s.title AS section_title
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      ORDER BY b.book_name ASC
    ''');
    final items = <LibraryBookItem>[];
    for (final row in rows) {
      final path = row['book_path'] as String? ?? '';
      if (path.isEmpty) continue;
      items.add(_itemFromRow(row, path));
    }
    return items;
  }

  Future<List<Author>> loadAuthors() async {
    final authors = await _db.getAuthors(limit: 10000);
    authors.sort(_compareAuthorsByDeathYear);
    return authors;
  }

  Future<List<Section>> loadSections() => _db.getSections(limit: 10000);

  Future<Set<String>> loadFavorites() => _db.getFavoriteBookPaths();

  Future<List<String>> loadRecentPaths() => _db.getRecentBookPaths();

  Future<Set<String>> searchFullBookPaths(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return {};
    final db = await _db.database;
    final pattern = '%$trimmed%';
    final rows = await db.rawQuery('''
      SELECT b.book_path
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      WHERE b.book_name LIKE ?
         OR a.name LIKE ?
         OR b.description LIKE ?
         OR b.publisher LIKE ?
         OR b.edition LIKE ?
         OR b.book_card_notes LIKE ?
    ''', List.filled(6, pattern));
    return rows.map((row) => row['book_path'] as String).toSet();
  }

  Future<LibraryBookItem?> loadBookDetails(LibraryBookItem item) async {
    final cached = _detailsCache[item.bookPath];
    if (cached != null) return cached;
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.*, a.description AS author_description
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      WHERE b.book_path = ?
      LIMIT 1
    ''', [item.bookPath]);
    if (rows.isEmpty) return null;
    final detailed = item.withDetails(
      book: BookCard.fromDatabaseRow(rows.first),
      authorDescription: rows.first['author_description'] as String? ?? '',
    );
    if (_detailsCache.length >= _detailsCacheLimit) {
      _detailsCache.remove(_detailsCache.keys.first);
    }
    _detailsCache[item.bookPath] = detailed;
    return detailed;
  }

  Future<void> setFavorite(String path, bool value) =>
      _db.setFavoriteBook(path, value);

  Future<void> removeRecent(String path) => _db.removeRecentBook(path);

  LibraryBookItem _itemFromRow(Map<String, Object?> row, String path) {
    return LibraryBookItem(
      bookPath: path,
      book: BookCard(
        id: row['id'] as String,
        title: row['book_name'] as String,
        authorId: row['author_id'] as String? ?? '',
        sectionId: row['section_id'] as String? ?? '',
        bookType: row['book_type'] as String? ?? '',
        matchesPrinted: row['matches_printed'] == 1,
      ),
      authorName: row['author_name'] as String? ?? '',
      authorDeathYear: row['author_death_year'] as String? ?? '',
      sectionTitle: row['section_title'] as String? ?? '',
    );
  }

  int _compareAuthorsByDeathYear(Author a, Author b) {
    final left = _deathSortValue(a.deathYear);
    final right = _deathSortValue(b.deathYear);
    if (left != right) return left.compareTo(right);
    return a.name.compareTo(b.name);
  }

  int _deathSortValue(String? deathYear) {
    final value = deathYear?.trim() ?? '';
    if (value.isEmpty || value.contains('غير')) return 999999;
    if (value.contains('معاصر')) return 999998;
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? 999999;
  }
}
