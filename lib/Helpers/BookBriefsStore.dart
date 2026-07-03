import 'package:sqflite/sqflite.dart';

import 'BooksMetadataDatabase.dart';

class BookBriefsStore {
  static final BookBriefsStore _instance = BookBriefsStore._internal();

  factory BookBriefsStore() => _instance;

  BookBriefsStore._internal();

  final BooksMetadataDatabase _db = BooksMetadataDatabase();
  bool _tableReady = false;

  Future<void> ensureTable() async {
    if (_tableReady) return;
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_briefs (
        book_path TEXT PRIMARY KEY,
        book_id TEXT,
        brief TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_book_briefs_book_id
      ON book_briefs(book_id)
    ''');
    _tableReady = true;
  }

  Future<void> saveBrief({
    required String bookPath,
    required String? bookId,
    required String brief,
  }) async {
    await ensureTable();
    final trimmed = brief.trim();
    if (trimmed.isEmpty) {
      await deleteBrief(bookPath);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db.database;
    await db.insert(
      'book_briefs',
      {
        'book_path': bookPath,
        'book_id': bookId,
        'brief': trimmed,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBrief(String bookPath) async {
    await ensureTable();
    final db = await _db.database;
    await db.delete(
      'book_briefs',
      where: 'book_path = ?',
      whereArgs: [bookPath],
    );
  }

  Future<String> getBriefForBookPath(String bookPath) async {
    await ensureTable();
    final db = await _db.database;
    final rows = await db.query(
      'book_briefs',
      columns: const ['brief'],
      where: 'book_path = ?',
      whereArgs: [bookPath],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return rows.first['brief'] as String? ?? '';
  }

  Future<int> countBriefs({String? searchQuery}) async {
    await ensureTable();
    final db = await _db.database;
    final trimmed = searchQuery?.trim() ?? '';
    if (trimmed.isEmpty) {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS count
        FROM book_briefs
        WHERE TRIM(brief) <> ''
      ''');
      return Sqflite.firstIntValue(rows) ?? 0;
    }
    final pattern = '%$trimmed%';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM book_briefs br
      LEFT JOIN books b ON b.book_path = br.book_path
      LEFT JOIN authors a ON a.id = b.author_id
      WHERE TRIM(br.brief) <> ''
        AND (br.brief LIKE ? OR b.book_name LIKE ? OR a.name LIKE ?)
    ''', [pattern, pattern, pattern]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
