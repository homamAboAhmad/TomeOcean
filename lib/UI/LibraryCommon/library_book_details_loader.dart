import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Helpers/BookBriefsStore.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'library_book_item.dart';

class LibraryBookDetailsLoader {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();
  final BookBriefsStore _briefsStore = BookBriefsStore();
  final Map<String, LibraryBookItem> _cache = {};
  static const _cacheLimit = 24;

  Future<LibraryBookItem?> load(LibraryBookItem item) async {
    final cached = _cache[item.bookPath];
    if (cached != null) return cached;
    await _db.initialize();
    await _briefsStore.ensureTable();
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.*,
             a.name AS author_name,
             a.death_year AS author_death_year,
             a.description AS author_description,
             s.title AS section_title,
             br.brief AS book_brief
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      LEFT JOIN book_briefs br ON br.book_path = b.book_path
      WHERE b.book_path = ?
      LIMIT 1
    ''', [item.bookPath]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final detailed = LibraryBookItem(
      bookPath: item.bookPath,
      book: BookCard.fromDatabaseRow(row).copyWith(title: item.title),
      authorName: row['author_name'] as String? ?? item.authorName,
      authorDeathYear:
          row['author_death_year'] as String? ?? item.authorDeathYear,
      authorDescription: row['author_description'] as String? ?? '',
      sectionTitle: row['section_title'] as String? ?? item.sectionTitle,
      bookBrief: row['book_brief'] as String? ?? item.bookBrief,
    );
    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[item.bookPath] = detailed;
    return detailed;
  }

  void clear() => _cache.clear();
}
