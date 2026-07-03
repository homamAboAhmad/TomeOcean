import 'dart:io';

import 'package:golden_shamela/Helpers/ArabicSearchIndexer.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Helpers/MeiliSearchIndexer.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';
import 'package:path/path.dart' as p;

class LibraryControlRepository {
  static const pageSize = 200;

  final BooksMetadataDatabase _db = BooksMetadataDatabase();

  Future<List<LibraryBookItem>> loadBooks({
    String query = '',
    String? authorId,
    String? sectionId,
    int? limit = pageSize,
  }) async {
    await _db.initialize();
    final db = await _db.database;
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(b.book_name LIKE ? OR a.name LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    if (authorId?.isNotEmpty == true) {
      where.add('b.author_id = ?');
      args.add(authorId);
    }
    if (sectionId?.isNotEmpty == true) {
      where.add('b.section_id = ?');
      args.add(sectionId);
    }
    final rows = await db.rawQuery('''
      SELECT b.id, b.book_name, b.book_path, b.author_id, b.section_id,
             b.book_type, b.matches_printed, b.description,
             b.publisher, b.edition, b.page_count,
             a.name AS author_name, a.death_year AS author_death_year,
             s.title AS section_title
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      WHERE ${where.join(' AND ')}
      ORDER BY b.book_name ASC
    ''', args);
    final books = rows
        .map(_bookItemFromRow)
        .whereType<LibraryBookItem>()
        .toList();
    books.sort(LibraryBookItem.compareByAuthorDeathThenTitle);
    return limit == null ? books : books.take(limit).toList();
  }

  Future<List<LibraryEntityRow>> loadAuthors(String query) async {
    final authors = await _db.getAuthors(
      searchQuery: query.trim().isEmpty ? null : query.trim(),
    );
    authors.sort(_compareAuthorsByDeathYear);
    final counts = await _bookCounts('author_id');
    final rows = <LibraryEntityRow>[];
    for (final author in authors.take(pageSize)) {
      rows.add(LibraryEntityRow(
        id: author.id,
        title: author.name,
        secondary: author.deathYear ?? '',
        count: counts[author.id] ?? 0,
      ));
    }
    return rows;
  }

  int _compareAuthorsByDeathYear(Author a, Author b) {
    final death = AuthorDeathDateParser.compare(a.deathYear, b.deathYear);
    if (death != 0) return death;
    return a.name.compareTo(b.name);
  }

  Future<List<LibraryEntityRow>> loadSections(
    String query, {
    int? limit = pageSize,
  }) async {
    final sections = await _db.getSections(
      limit: limit,
      searchQuery: query.trim().isEmpty ? null : query.trim(),
    );
    final counts = await _bookCounts('section_id');
    final rows = <LibraryEntityRow>[];
    for (final section in sections) {
      rows.add(LibraryEntityRow(
        id: section.id,
        title: section.title,
        count: counts[section.id] ?? 0,
      ));
    }
    return rows;
  }

  Future<Author?> getAuthor(String id) => _db.getAuthorById(id);
  Future<Section?> getSection(String id) => _db.getSectionById(id);

  Future<void> saveBook(BookCard book, String path) => _db.saveBook(book, path);
  Future<void> deleteBook(String path) async {
    final result = await deleteBooks([path]);
    if (result.hasFailures) throw result.failures.first.error;
  }

  Future<LibraryDeleteResult> deleteBooks(
    Iterable<String> paths, {
    void Function(int done, int total, String path, String message)? onProgress,
  }) async {
    final uniquePaths = paths.toSet().toList();
    final failures = <LibraryDeleteFailure>[];
    var deleted = 0;
    final meili = MeiliSearchIndexer();

    try {
      for (final path in uniquePaths) {
        final done = deleted + failures.length;
        try {
          await _deleteBookCompletely(
            path,
            meili,
            (message) => onProgress?.call(
              done,
              uniquePaths.length,
              path,
              message,
            ),
          );
          deleted++;
        } catch (e) {
          failures.add(LibraryDeleteFailure(path, e));
        }
        onProgress?.call(
          deleted + failures.length,
          uniquePaths.length,
          path,
          'تحديث القائمة',
        );
      }
    } finally {
      meili.dispose();
    }

    return LibraryDeleteResult(
      total: uniquePaths.length,
      deleted: deleted,
      failures: failures,
    );
  }

  Future<void> saveSection(Section section) => _db.saveSection(section);

  Future<void> deleteAuthor(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('books', {'author_id': null},
          where: 'author_id = ?', whereArgs: [id]);
      await txn.delete('authors', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteSection(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('books', {'section_id': null},
          where: 'section_id = ?', whereArgs: [id]);
      await txn.delete('sections', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<LibraryDeleteResult> deleteAuthorWithBooks(
    String id, {
    void Function(int done, int total, String path, String message)? onProgress,
  }) =>
      _deleteEntityAndLinkedBooks('authors', 'author_id', id, onProgress);

  Future<LibraryDeleteResult> deleteSectionWithBooks(
    String id, {
    void Function(int done, int total, String path, String message)? onProgress,
  }) =>
      _deleteEntityAndLinkedBooks('sections', 'section_id', id, onProgress);

  Future<void> assignAuthor(String authorId, Iterable<String> paths) =>
      _updateBooks(paths, authorId: authorId);

  Future<void> assignSection(String sectionId, Iterable<String> paths) =>
      _updateBooks(paths, sectionId: sectionId);

  Future<Set<String>> linkedBookPaths({
    String? authorId,
    String? sectionId,
  }) async {
    final db = await _db.database;
    final column = authorId != null ? 'author_id' : 'section_id';
    final value = authorId ?? sectionId;
    final rows = await db.query(
      'books',
      columns: ['book_path'],
      where: '$column = ?',
      whereArgs: [value],
    );
    return rows.map((row) => row['book_path'] as String).toSet();
  }

  Future<void> replaceAuthorBooks(String authorId, Set<String> paths) =>
      _replaceLinkedBooks('author_id', authorId, paths);

  Future<void> replaceSectionBooks(String sectionId, Set<String> paths) =>
      _replaceLinkedBooks('section_id', sectionId, paths);

  Future<void> _updateBooks(
    Iterable<String> paths, {
    String? authorId,
    String? sectionId,
  }) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final path in paths) {
      final values = <String, Object?>{};
      if (authorId != null) values['author_id'] = authorId;
      if (sectionId != null) values['section_id'] = sectionId;
      batch.update('books', values, where: 'book_path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _replaceLinkedBooks(
    String column,
    String value,
    Set<String> paths,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('books', {column: null},
          where: '$column = ?', whereArgs: [value]);
      final batch = txn.batch();
      for (final path in paths) {
        batch.update('books', {column: value},
            where: 'book_path = ?', whereArgs: [path]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> _bookCounts(String column) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT $column AS id, COUNT(*) AS count
      FROM books
      WHERE $column IS NOT NULL AND $column != ''
      GROUP BY $column
    ''');
    return {
      for (final row in rows)
        row['id'] as String: (row['count'] as int?) ?? 0,
    };
  }

  Future<LibraryDeleteResult> _deleteEntityAndLinkedBooks(
    String table,
    String column,
    String id,
    void Function(int done, int total, String path, String message)? onProgress,
  ) async {
    final paths = await _linkedPathsForColumn(column, id);
    final result = await deleteBooks(paths, onProgress: onProgress);
    if (result.hasFailures) return result;

    final db = await _db.database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    return result;
  }

  Future<List<String>> _linkedPathsForColumn(String column, String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['book_path'],
      where: '$column = ?',
      whereArgs: [id],
    );
    return rows
        .map((row) => row['book_path']?.toString())
        .whereType<String>()
        .toList();
  }

  Future<void> _deleteBookCompletely(
    String path,
    MeiliSearchIndexer meili,
    void Function(String message) onStatus,
  ) async {
    onStatus('إزالة ملف الكتاب');
    await _deleteStoredBookFiles(path);
    onStatus('تحديث نتائج البحث');
    await _deleteSearchIndexes(path, meili);
    onStatus('تحديث قائمة الكتب');
    await _db.deleteBookByPath(path);
  }

  Future<void> _deleteSearchIndexes(
    String path,
    MeiliSearchIndexer meili,
  ) async {
    await ShamelaSearchIndexer().deleteBook(path);
    await ArabicSearchIndexer().deleteBook(path);

    try {
      await meili.deleteBook(path);
    } catch (e) {
      print('LibraryControlRepository: Meili index delete failed: $e');
    }
  }

  Future<void> _deleteStoredBookFiles(String path) async {
    final bookId = AppStoragePaths.bookIdFromPath(path);
    if (_isInsideBooksStore(path)) {
      final bookDir = Directory(AppStoragePaths.bookDirPath(bookId));
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      return;
    }

    final source = File(path);
    if (await source.exists()) {
      await source.delete();
    }
    await AppStoragePaths.deleteRebuildableCache(bookId);

    final partsDir = Directory(AppStoragePaths.bookPartsDirPath(bookId));
    if (await partsDir.exists()) {
      await partsDir.delete(recursive: true);
    }
  }

  bool _isInsideBooksStore(String path) {
    final store = p.normalize(p.absolute(AppStoragePaths.booksStorePath))
        .toLowerCase();
    final file = p.normalize(p.absolute(path)).toLowerCase();
    return p.equals(store, file) || p.isWithin(store, file);
  }

  LibraryBookItem? _bookItemFromRow(Map<String, Object?> row) {
    final path = row['book_path'] as String? ?? '';
    if (path.isEmpty) return null;
    return LibraryBookItem(
      bookPath: path,
      book: BookCard.fromDatabaseRow(row),
      authorName: row['author_name'] as String? ?? '',
      authorDeathYear: row['author_death_year'] as String? ?? '',
      sectionTitle: row['section_title'] as String? ?? '',
    );
  }

}

class LibraryDeleteResult {
  const LibraryDeleteResult({
    required this.total,
    required this.deleted,
    required this.failures,
  });

  final int total;
  final int deleted;
  final List<LibraryDeleteFailure> failures;

  bool get hasFailures => failures.isNotEmpty;
}

class LibraryDeleteFailure {
  const LibraryDeleteFailure(this.path, this.error);

  final String path;
  final Object error;
}
