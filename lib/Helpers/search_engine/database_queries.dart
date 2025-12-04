import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database query operations for the search engine
class DatabaseQueries {
  final Database database;

  DatabaseQueries(this.database);

  /// Check if a book needs to be indexed
  Future<bool> needsIndexing(String bookPath) async {
    try {
      final file = File(bookPath);
      if (!await file.exists()) {
        return false;
      }

      final fileModified = await file.stat();
      final fileModifiedTime = fileModified.modified.millisecondsSinceEpoch;
      final currentDbVersion = 8;
      final normalizedPath = p.normalize(bookPath);

      List<Map<String, dynamic>> result = [];
      try {
        try {
          result = await database.query(
            'books_metadata',
            where: 'book_path = ?',
            whereArgs: [bookPath],
            limit: 1,
          );
        } catch (e) {
          result = await database.query(
            'books_metadata',
            columns: ['indexed_at', 'book_path'],
            where: 'book_path = ?',
            whereArgs: [bookPath],
            limit: 1,
          );
        }

        if (result.isEmpty && normalizedPath != bookPath) {
          try {
            result = await database.query(
              'books_metadata',
              where: 'book_path = ?',
              whereArgs: [normalizedPath],
              limit: 1,
            );
          } catch (e) {
            result = await database.query(
              'books_metadata',
              columns: ['indexed_at', 'book_path'],
              where: 'book_path = ?',
              whereArgs: [normalizedPath],
              limit: 1,
            );
          }
        }

        if (result.isEmpty) {
          try {
            final allBooks = await database.query('books_metadata');
            final normalizedPathLower = normalizedPath.toLowerCase();
            for (var row in allBooks) {
              final dbPath = row['book_path'] as String?;
              if (dbPath == null) continue;

              final dbPathNormalized = p.normalize(dbPath.toLowerCase());
              if (dbPathNormalized == normalizedPathLower) {
                result = [row];
                break;
              }
            }
          } catch (e) {
            return true;
          }
        }
      } catch (e) {
        return true;
      }

      if (result.isEmpty) {
        return true;
      }

      final indexedAt = result.first['indexed_at'] as int?;
      final indexingVersion = result.first['indexing_version'] as int?;

      if (indexingVersion == null) {
        return true;
      }

      if (indexingVersion != currentDbVersion) {
        return true;
      }

      if (indexedAt == null) {
        return true;
      }

      if (fileModifiedTime > indexedAt) {
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      return true;
    }
  }

  /// Get all indexed books
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    try {
      final results = await database.rawQuery(
        'SELECT book_path, book_name FROM books_metadata ORDER BY book_name ASC',
      );
      return results;
    } catch (e) {
      if (database.isOpen) {
        try {
          await database.close();
        } catch (_) {}
        return [];
      }
      return [];
    }
  }

  /// Search pages using page-level FTS index
  Future<List<Map<String, dynamic>>> searchPages({
    required String ftsQuery,
    List<String>? bookPaths,
    bool considerDiacritics = false,
    bool considerHamzas = false,
    bool morphologicalSearch = false,
    int limit = 100,
    int offset = 0,
  }) async {
    String contentColumn;
    if (considerDiacritics && considerHamzas) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerDiacritics) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerHamzas) {
      contentColumn = 'hamza_preserved_content';
    } else if (morphologicalSearch) {
      contentColumn = 'morphological_content';
    } else {
      contentColumn = 'normalized_content';
    }

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    final columnPrefix = '$contentColumn:';
    final fullQuery = '$columnPrefix$ftsQuery';

    String whereClause;
    if (whereClauses.isNotEmpty) {
      whereClause =
          'WHERE ${whereClauses.join(' AND ')} AND pages_fts MATCH ?';
    } else {
      whereClause = 'WHERE pages_fts MATCH ?';
    }

    final sql = '''
      SELECT 
        book_path,
        book_name,
        page_number,
        content,
        bm25(pages_fts) as rank
      FROM pages_fts
      $whereClause
      ORDER BY rank DESC, page_number ASC
      LIMIT ? OFFSET ?
    ''';

    final results = await database.rawQuery(
      sql,
      [...whereArgs, fullQuery, limit, offset],
    );

    final countSql = '''
      SELECT COUNT(*) as total
      FROM pages_fts
      $whereClause
    ''';
    final countResult = await database.rawQuery(
      countSql,
      [...whereArgs, fullQuery],
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    return results.map((row) {
      return {
        ...Map<String, dynamic>.from(row),
        'estimatedTotalHits': total,
      };
    }).toList();
  }

  /// Search pages with streaming support
  Stream<List<Map<String, dynamic>>> searchPagesStream({
    required String ftsQuery,
    List<String>? bookPaths,
    bool considerDiacritics = false,
    bool considerHamzas = false,
    bool morphologicalSearch = false,
    int batchSize = 10,
    int? maxResults,
  }) async* {
    String contentColumn;
    if (considerDiacritics && considerHamzas) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerDiacritics) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerHamzas) {
      contentColumn = 'hamza_preserved_content';
    } else if (morphologicalSearch) {
      contentColumn = 'morphological_content';
    } else {
      contentColumn = 'normalized_content';
    }

    final fullQuery = '$contentColumn:$ftsQuery';

    String whereClause = 'WHERE pages_fts MATCH ?';
    List<dynamic> whereArgs = [fullQuery];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClause = 'WHERE book_path IN ($placeholders) AND pages_fts MATCH ?';
      whereArgs = [...bookPaths, fullQuery];
    }

    int total = 0;
    try {
      final countSql = 'SELECT COUNT(*) as total FROM pages_fts $whereClause';
      final countResult = await database.rawQuery(countSql, whereArgs);
      total = Sqflite.firstIntValue(countResult) ?? 0;
    } catch (e, stackTrace) {
      yield [];
      return;
    }

    if (total == 0) {
      yield [];
      return;
    }

    int offset = 0;
    int totalYielded = 0;

    while (true) {
      final currentBatchSize = maxResults != null
          ? (maxResults - totalYielded).clamp(0, batchSize)
          : batchSize;

      if (currentBatchSize <= 0) break;

      try {
        final sql = '''
          SELECT 
            book_path,
            book_name,
            page_number,
            content,
            bm25(pages_fts) as rank
          FROM pages_fts
          $whereClause
          ORDER BY rank DESC, page_number ASC
          LIMIT ? OFFSET ?
        ''';

        final batchArgs = [...whereArgs, currentBatchSize, offset];
        final batchResults = await database.rawQuery(sql, batchArgs);

        if (batchResults.isEmpty) {
          break;
        }

        final batch = batchResults.map((row) {
          return {
            ...Map<String, dynamic>.from(row),
            'estimatedTotalHits': total,
          };
        }).toList();

        yield batch;

        totalYielded += batch.length;
        offset += currentBatchSize;

        if (offset >= total ||
            (maxResults != null && totalYielded >= maxResults)) {
          break;
        }
      } catch (e, stackTrace) {
        break;
      }
    }
  }

  /// Get all paragraphs from a specific page
  Future<List<Map<String, dynamic>>> getParagraphsByPage(
    String bookPath,
    int pageNumber,
  ) async {
    final sql = '''
      SELECT 
        id,
        book_path,
        book_name,
        page_number,
        section_type,
        content,
        raw_content
      FROM books_fts
      WHERE book_path = ? AND page_number = ?
      AND books_fts MATCH 'normalized_content:ال*'
      ORDER BY id ASC
    ''';

    final results = await database.rawQuery(sql, [bookPath, pageNumber]);

    return results.map((row) => Map<String, dynamic>.from({
          'id': row['id'],
          'book_path': row['book_path'],
          'book_name': row['book_name'],
          'page_number': row['page_number'],
          'section_type': row['section_type'],
          'content': row['content'],
          'raw_content': row['raw_content'],
        })).toList();
  }
}

