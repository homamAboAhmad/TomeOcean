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
      final currentDbVersion = 9;
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
    } catch (e) {
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

  /// Search pages using page-level FTS index or paragraph-level (books_fts) if section filtering is needed
  Future<List<Map<String, dynamic>>> searchPages({
    required String ftsQuery,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool considerDiacritics = false,
    bool considerHamzas = false,
    bool considerNumbers = true,
    bool morphologicalSearch = false,
    int limit = 100,
    int offset = 0,
  }) async {
    String contentColumn;
    if (morphologicalSearch) {
      contentColumn = 'morphological_content';
    } else if (considerDiacritics && considerHamzas) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerDiacritics) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerHamzas) {
      contentColumn = 'hamza_preserved_content';
    } else if (!considerNumbers) {
      contentColumn = 'normalized_no_numbers_content';
    } else {
      contentColumn = 'normalized_content';
    }

    // Determine target table: pages_fts (default) or books_fts (if filtered by section)
    // Note: books_fts has section_type column, pages_fts does not (it's aggregated)
    final bool useSectionFiltering =
        sectionTypes != null &&
        sectionTypes.isNotEmpty &&
        !sectionTypes.contains('all'); // Assuming 'all' check if applicable

    final String targetTable = useSectionFiltering ? 'books_fts' : 'pages_fts';

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    // Add section type filtering if using books_fts
    if (useSectionFiltering) {
      // Map UI section types to DB values if needed, otherwise use directly
      // DB uses: 'main' (Body), 'title' (Headings), 'footnote' (Footnotes), 'comment'
      final placeholders = List.filled(sectionTypes.length, '?').join(',');
      whereClauses.add('section_type IN ($placeholders)');
      whereArgs.addAll(sectionTypes);
    }

    final columnPrefix = '$contentColumn:';
    // FTS match query
    // books_fts and pages_fts share same content column names
    final fullQuery = '$columnPrefix$ftsQuery';

    String whereClause;
    if (whereClauses.isNotEmpty) {
      whereClause =
          'WHERE ${whereClauses.join(' AND ')} AND $targetTable MATCH ?';
    } else {
      whereClause = 'WHERE $targetTable MATCH ?';
    }

    // Identify ranking/ordering logic. FTS5 provides 'rank'.
    // We want unique pages. If querying books_fts (paragraphs), we need GROUP BY to distinct pages.

    final countSql = useSectionFiltering
        ? 'SELECT COUNT(*) as total FROM (SELECT DISTINCT book_path, page_number FROM $targetTable $whereClause)'
        : 'SELECT COUNT(*) as total FROM $targetTable $whereClause';

    final queryArgs = [...whereArgs, fullQuery];

    final countResult = await database.rawQuery(countSql, queryArgs);
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    if (total == 0) {
      return [];
    }

    List<Map<String, dynamic>> results;

    if (useSectionFiltering) {
      // Two-Step Query Approach for accurate pagination and full content retrieval

      // Step 1: Identify the exact pages for this pagination window
      final pagesSql =
          '''
        SELECT DISTINCT book_path, page_number
        FROM $targetTable
        $whereClause
        ORDER BY page_number ASC
        LIMIT ? OFFSET ?
      ''';

      final pageRows = await database.rawQuery(pagesSql, [
        ...queryArgs,
        limit,
        offset,
      ]);

      if (pageRows.isEmpty) {
        return [];
      }

      // Step 2: Fetch ALL matching paragraphs for these specific pages
      final pageFilters = <String>[];
      final pageArgs = <Object?>[];

      for (final row in pageRows) {
        pageFilters.add('(book_path = ? AND page_number = ?)');
        pageArgs.add(row['book_path']);
        pageArgs.add(row['page_number']);
      }

      final specificPagesCondition = '(${pageFilters.join(' OR ')})';

      final contentSql =
          '''
        SELECT 
          book_path,
          book_name,
          page_number,
          content,
          morphological_content,
          section_type
        FROM $targetTable
        $whereClause AND $specificPagesCondition
        ORDER BY page_number ASC, rowid ASC
      ''';

      final contentArgs = [...queryArgs, ...pageArgs];
      final rawResults = await database.rawQuery(contentSql, contentArgs);

      // Manual Aggregation in Dart
      final Map<String, Map<String, dynamic>> aggregatedMap = {};

      for (final row in rawResults) {
        final key = '${row['book_path']}_${row['page_number']}';

        if (!aggregatedMap.containsKey(key)) {
          aggregatedMap[key] = {
            'book_path': row['book_path'],
            'book_name': row['book_name'],
            'page_number': row['page_number'],
            'content': row['content'] ?? '',
            'morphological_content': row['morphological_content'] ?? '',
            'section_type': row['section_type'] ?? '',
          };
        } else {
          final current = aggregatedMap[key]!;
          current['content'] =
              '${current['content']} ... ${row['content'] ?? ''}';
          current['morphological_content'] =
              '${current['morphological_content']} ${row['morphological_content'] ?? ''}';
          final currentTypes = (current['section_type'] as String).split(',');
          final newType = row['section_type'] as String?;
          if (newType != null && !currentTypes.contains(newType)) {
            current['section_type'] = '${current['section_type']},$newType';
          }
        }
      }

      results = aggregatedMap.values.toList();
    } else {
      // Original page query (no grouping needed)
      final sql =
          '''
        SELECT 
          book_path,
          book_name,
          page_number,
          content,
          rank
        FROM $targetTable
        $whereClause
        ORDER BY rank, page_number ASC
        LIMIT ? OFFSET ?
      ''';
      results = await database.rawQuery(sql, [...queryArgs, limit, offset]);
    }

    return results.map((row) {
      return {...Map<String, dynamic>.from(row), 'estimatedTotalHits': total};
    }).toList();
  }

  /// Search pages with streaming support
  Stream<List<Map<String, dynamic>>> searchPagesStream({
    required String ftsQuery,
    List<String>? bookPaths,
    List<String>? sectionTypes, // Added sectionTypes
    bool considerDiacritics = false,
    bool considerHamzas = false,
    bool considerNumbers = true,
    bool morphologicalSearch = false,
    int batchSize = 10,
    int? maxResults,
  }) async* {
    String contentColumn;
    if (morphologicalSearch) {
      contentColumn = 'morphological_content';
    } else if (considerDiacritics && considerHamzas) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerDiacritics) {
      contentColumn = 'diacritics_preserved_content';
    } else if (considerHamzas) {
      contentColumn = 'hamza_preserved_content';
    } else if (!considerNumbers) {
      contentColumn = 'normalized_no_numbers_content';
    } else {
      contentColumn = 'normalized_content';
    }

    // Determine target table and clause
    final bool useSectionFiltering =
        sectionTypes != null &&
        sectionTypes.isNotEmpty &&
        !sectionTypes.contains('all');
    final String targetTable = useSectionFiltering ? 'books_fts' : 'pages_fts';

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    // Add section type filtering for books_fts
    if (useSectionFiltering) {
      final placeholders = List.filled(sectionTypes.length, '?').join(',');
      whereClauses.add('section_type IN ($placeholders)');
      whereArgs.addAll(sectionTypes);
    }

    final columnPrefix = '$contentColumn:';
    final fullQuery = '$columnPrefix$ftsQuery';

    String whereClause;
    if (whereClauses.isNotEmpty) {
      whereClause =
          'WHERE ${whereClauses.join(' AND ')} AND $targetTable MATCH ?';
    } else {
      whereClause = 'WHERE $targetTable MATCH ?';
    }

    // For streaming, we need to handle pagination manually or stream chunks
    // The previous implementation likely did custom offset/limit management or streaming
    // Let's replicate the structure.

    whereArgs.add(fullQuery);

    // Stream pages using offset-based pagination without a blocking COUNT first.
    // We stream until we get an empty batch or reach maxResults.
    // totalCount is updated as we discover more results.
    int currentOffset = 0;
    int processedCount = 0;
    int totalCount = 0;
    final int effectiveMax = maxResults ?? 999999;

    while (processedCount < effectiveMax) {
      final currentLimit = batchSize < (effectiveMax - processedCount)
          ? batchSize
          : (effectiveMax - processedCount);

      String sql;
      if (useSectionFiltering) {
        // We concatenate all matching paragraphs' content so the matched text is visible
        sql =
            '''
              SELECT 
                book_path,
                book_name,
                page_number,
                GROUP_CONCAT(content, ' ... ') as content,
                GROUP_CONCAT(morphological_content, ' ') as morphological_content,
                GROUP_CONCAT(DISTINCT section_type) as section_type
              FROM $targetTable
              $whereClause
              GROUP BY book_path, page_number
              ORDER BY page_number ASC
              LIMIT $currentLimit OFFSET $currentOffset
            ''';
      } else {
        // Original page query (no grouping needed)
        sql =
            '''
              SELECT 
                book_path,
                book_name,
                page_number,
                content,
                rank
              FROM $targetTable
              $whereClause
              ORDER BY rank, page_number ASC
              LIMIT $currentLimit OFFSET $currentOffset
            ''';
      }

      try {
        final results = await database.rawQuery(sql, whereArgs);
        if (results.isEmpty) break;

        processedCount += results.length;
        currentOffset += currentLimit;
        // Estimate total: if we got a full batch, there may be more
        totalCount = results.length < currentLimit
            ? processedCount
            : processedCount + currentLimit;

        final mappedResults = results.map((row) {
          return {
            ...Map<String, dynamic>.from(row),
            'estimatedTotalHits': totalCount,
          };
        }).toList();

        yield mappedResults;

        if (results.length < currentLimit) break;
      } catch (e) {
        print('Error streaming results: $e');
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
      ORDER BY id ASC
    ''';

    final results = await database.rawQuery(sql, [bookPath, pageNumber]);

    return results
        .map(
          (row) => Map<String, dynamic>.from({
            'id': row['id'],
            'book_path': row['book_path'],
            'book_name': row['book_name'],
            'page_number': row['page_number'],
            'section_type': row['section_type'],
            'content': row['content'],
            'raw_content': row['raw_content'],
          }),
        )
        .toList();
  }
}
