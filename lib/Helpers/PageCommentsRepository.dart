import 'dart:io';
import 'dart:typed_data';

import 'package:golden_shamela/Helpers/PageCommentsBookResolver.dart';
import 'package:golden_shamela/Helpers/ShamelaCommentsExchange.dart';
import 'package:golden_shamela/Helpers/search_engine/text_normalization.dart';
import 'package:golden_shamela/Models/BookPart.dart';
import 'package:golden_shamela/Models/PageComment.dart';
import 'package:golden_shamela/Models/PageCommentsImportResult.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PageCommentsRepository {
  PageCommentsRepository._();
  static final PageCommentsRepository instance = PageCommentsRepository._();
  static const int _version = 2;

  Database? _database;

  Future<Database> get _db async {
    if (_database != null && _database!.isOpen) return _database!;
    if (Platform.isWindows && databaseFactory == null) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await Directory(p.dirname(AppStoragePaths.pageCommentsDbPath))
        .create(recursive: true);
    _database = await openDatabase(
      AppStoragePaths.pageCommentsDbPath,
      version: _version,
      onCreate: _createTables,
      onUpgrade: _migrateTables,
    );
    return _database!;
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE page_comments(
        book_path TEXT NOT NULL,
        book_name TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        content TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        source_book_id TEXT,
        source_part TEXT,
        source_anchor INTEGER,
        PRIMARY KEY(book_path, page_index)
      );
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE page_comments_fts USING fts5(
        book_path UNINDEXED,
        book_name UNINDEXED,
        page_index UNINDEXED,
        content,
        normalized_content,
        hamza_preserved_content,
        diacritics_preserved_content,
        fully_preserved_content,
        no_diacritics_content,
        normalized_no_numbers_content,
        hamza_preserved_no_numbers_content,
        diacritics_preserved_no_numbers_content,
        fully_preserved_no_numbers_content,
        tokenize = 'unicode61 remove_diacritics 0'
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_page_comments_book_page '
      'ON page_comments(book_path, page_index);',
    );
  }

  Future<void> _migrateTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'page_comments', 'source_book_id', 'TEXT');
      await _addColumnIfMissing(db, 'page_comments', 'source_part', 'TEXT');
      await _addColumnIfMissing(db, 'page_comments', 'source_anchor', 'INTEGER');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<PageComment?> load(String bookPath, int pageIndex) async {
    final db = await _db;
    final rows = await db.query(
      'page_comments',
      where: 'book_path = ? AND page_index = ?',
      whereArgs: [bookPath, pageIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PageComment.fromRow(rows.first);
  }

  Future<void> save({
    required String bookPath,
    required String bookName,
    required int pageIndex,
    required String content,
    String? sourceBookId,
    String? sourcePart,
    int? sourceAnchor,
  }) async {
    final db = await _db;
    final text = content.trimRight();
    final previous = sourceBookId == null && sourcePart == null && sourceAnchor == null
        ? await load(bookPath, pageIndex)
        : null;
    final batch = db.batch();
    batch.delete(
      'page_comments',
      where: 'book_path = ? AND page_index = ?',
      whereArgs: [bookPath, pageIndex],
    );
    batch.delete(
      'page_comments_fts',
      where: 'book_path = ? AND page_index = ?',
      whereArgs: [bookPath, pageIndex],
    );
    if (text.trim().isNotEmpty) {
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      batch.insert('page_comments', {
        'book_path': bookPath,
        'book_name': bookName,
        'page_index': pageIndex,
        'content': text,
        'updated_at': updatedAt,
        'source_book_id': sourceBookId ?? previous?.sourceBookId,
        'source_part': sourcePart ?? previous?.sourcePart,
        'source_anchor': sourceAnchor ?? previous?.sourceAnchor,
      });
      batch.insert('page_comments_fts', {
        'book_path': bookPath,
        'book_name': bookName,
        'page_index': pageIndex,
        ..._searchColumns(text),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<PageComment>> listAll() async {
    final db = await _db;
    final rows = await db.query(
      'page_comments',
      orderBy: 'book_name ASC, book_path ASC, page_index ASC',
    );
    return rows.map(PageComment.fromRow).toList();
  }

  Future<PageCommentsImportResult> importShamelaPk(Uint8List bytes) async {
    final records = ShamelaCommentsExchange.decode(bytes);
    final books = await PageCommentsBookResolver.booksBySourceId(
      records.map((r) => r.bookId).toSet(),
    );
    var added = 0;
    var merged = 0;
    var unchanged = 0;
    var skippedMissingBook = 0;
    var skippedInvalid = 0;

    for (final record in records) {
      final page = record.page;
      if (page == null || page < 1 || record.text.trim().isEmpty) {
        skippedInvalid++;
        continue;
      }

      final book = books[record.bookId];
      if (book == null) {
        skippedMissingBook++;
        continue;
      }

      final pageIndex = book.globalPageIndex(record.part, page);
      final existing = await load(book.bookPath, pageIndex);
      final nextText = _mergeCommentText(existing?.content, record.text);
      if (existing?.content.trimRight() == nextText) {
        unchanged++;
        continue;
      }

      await save(
        bookPath: book.bookPath,
        bookName: book.bookName,
        pageIndex: pageIndex,
        content: nextText,
        sourceBookId: record.bookId,
        sourcePart: record.part,
        sourceAnchor: record.anchor,
      );

      if (existing == null || existing.content.trim().isEmpty) {
        added++;
      } else {
        merged++;
      }
    }

    return PageCommentsImportResult(
      added: added,
      merged: merged,
      unchanged: unchanged,
      skippedMissingBook: skippedMissingBook,
      skippedInvalid: skippedInvalid,
    );
  }

  Future<Uint8List> exportShamelaPk() async {
    final comments = await listAll();
    final bookIdsByPath = await PageCommentsBookResolver.bookIdsByPath();
    final partsByPath = await PageCommentsBookResolver.partsByPath();
    final records = <ShamelaCommentRecord>[];
    for (final comment in comments) {
      final text = comment.content.trimRight();
      if (text.trim().isEmpty) continue;
      final part = PageCommentsBookResolver.partForGlobalPage(
        partsByPath[comment.bookPath] ?? const <BookPart>[],
        comment.pageIndex,
      );
      final bookId = _nonEmpty(comment.sourceBookId) ??
          _nonEmpty(bookIdsByPath[comment.bookPath]) ??
          AppStoragePaths.bookIdFromPath(comment.bookPath);
      records.add(
        ShamelaCommentRecord(
          bookId: bookId,
          anchor: comment.sourceAnchor ?? comment.pageIndex + 1,
          part: _nonEmpty(comment.sourcePart) ?? part?.partNumber.toString(),
          page: part == null
              ? comment.pageIndex + 1
              : comment.pageIndex - part.pageOffset + 1,
          text: text,
        ),
      );
    }
    return ShamelaCommentsExchange.encode(records);
  }

  Future<List<Map<String, dynamic>>> search({
    required String ftsQuery,
    required bool searchAllComments,
    required String contentColumn,
    List<String>? bookPaths,
    int limit = 100,
  }) async {
    final db = await _db;
    final whereParts = <String>[];
    final args = <Object?>[];
    if (bookPaths != null && bookPaths.isNotEmpty) {
      whereParts.add('book_path IN (${List.filled(bookPaths.length, '?').join(',')})');
      args.addAll(bookPaths);
    }
    if (!searchAllComments) {
      whereParts.add('page_comments_fts MATCH ?');
      args.add('$contentColumn:$ftsQuery');
    }
    final where = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT book_path, book_name, page_index, content
      FROM page_comments_fts
      $where
      ORDER BY book_name ASC, book_path ASC, page_index ASC
      LIMIT ?
    ''', [...args, limit]);
    return rows.map(_resultFromRow).toList();
  }

  Map<String, dynamic> _resultFromRow(Map<String, Object?> row) {
    final content = row['content']?.toString() ?? '';
    return {
      'book_path': row['book_path']?.toString() ?? '',
      'book_name': row['book_name']?.toString() ?? '',
      'page_number': (row['page_index'] as num?)?.toInt() ?? 0,
      'section_type': 'comment',
      'section_title': 'التعليقات',
      'content': content.length > 500 ? '${content.substring(0, 500)}...' : content,
      'raw_content': content,
    };
  }

  Map<String, String> _searchColumns(String content) {
    return {
      'content': content,
      'normalized_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: true,
        unifyHamzas: true,
      ),
      'hamza_preserved_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: true,
        unifyHamzas: false,
      ),
      'diacritics_preserved_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: false,
        unifyHamzas: true,
      ),
      'fully_preserved_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: false,
        unifyHamzas: false,
      ),
      'no_diacritics_content': TextNormalization.hasDiacritics(content)
          ? ''
          : TextNormalization.normalizeText(content),
      'normalized_no_numbers_content': TextNormalization.normalizeText(
        content,
        removeNumbers: true,
      ),
      'hamza_preserved_no_numbers_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: true,
        unifyHamzas: false,
        removeNumbers: true,
      ),
      'diacritics_preserved_no_numbers_content':
          TextNormalization.normalizeText(
        content,
        removeDiacritics: false,
        unifyHamzas: true,
        removeNumbers: true,
      ),
      'fully_preserved_no_numbers_content': TextNormalization.normalizeText(
        content,
        removeDiacritics: false,
        unifyHamzas: false,
        removeNumbers: true,
      ),
    };
  }

  String _mergeCommentText(String? current, String incoming) {
    final base = current?.trimRight() ?? '';
    final text = incoming.trimRight();
    if (base.trim().isEmpty) return text;
    final normalizedIncoming = _normalizeCommentForCompare(text);
    final alreadyExists = base
        .split('\n\n')
        .any((part) => _normalizeCommentForCompare(part) == normalizedIncoming);
    if (alreadyExists) return base;
    return '$base\n\n$text';
  }

  String _normalizeCommentForCompare(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
