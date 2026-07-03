import 'package:sqflite/sqflite.dart';
import '../ArabicMorphologicalAnalyzer.dart';
import 'text_normalization.dart';

/// Search operations for the search engine
class SearchOperations {
  final Database database;

  SearchOperations(this.database);

  String _contentColumn({
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
  }) {
    if (considerDiacritics && considerHamzas) {
      return considerNumbers
          ? 'fully_preserved_content'
          : 'fully_preserved_no_numbers_content';
    }
    if (considerDiacritics) {
      return considerNumbers
          ? 'diacritics_preserved_content'
          : 'diacritics_preserved_no_numbers_content';
    }
    if (considerHamzas) {
      return considerNumbers
          ? 'hamza_preserved_content'
          : 'hamza_preserved_no_numbers_content';
    }
    return considerNumbers
        ? 'normalized_content'
        : 'normalized_no_numbers_content';
  }

  /// Regular FTS5 search
  Future<List<Map<String, dynamic>>> regularSearch(
    List<List<String>> searchTermGroups,
    String operator,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool considerDiacritics,
    bool considerHamzas,
    bool considerNumbers,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
    int proximityDistance,
    int limit,
    int offset,
  ) async {
    final contentColumn = _contentColumn(
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
    );

    final List<String> ftsQueries = [];
    for (var group in searchTermGroups) {
      if (group.isEmpty) continue;

      if (group.length == 1) {
        ftsQueries.add('${group[0]}*');
      } else {
        ftsQueries.add('(${group.map((t) => '$t*').join(' OR ')})');
      }
    }

    if (ftsQueries.isEmpty) return [];

    final String ftsQuery;
    final String columnPrefix = '$contentColumn:';

    if (allPhrasesRequired) {
      ftsQuery = ftsQueries
          .map((q) => '$columnPrefix$q')
          .join(operator == 'AND' ? ' AND ' : ' OR ');
    } else if (ordered && proximity) {
      final phrase = searchTermGroups.map((g) => g.first).join(' ');
      ftsQuery = '$columnPrefix NEAR($phrase, $proximityDistance)';
    } else if (ordered) {
      final phrase = searchTermGroups.map((g) => g.first).join(' ');
      ftsQuery = '$columnPrefix "$phrase"';
    } else {
      ftsQuery = ftsQueries
          .map((q) => '$columnPrefix$q')
          .join(operator == 'AND' ? ' AND ' : ' OR ');
    }

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    if (sectionTypes != null && sectionTypes.isNotEmpty) {
      final placeholders = List.filled(sectionTypes.length, '?').join(',');
      whereClauses.add('section_type IN ($placeholders)');
      whereArgs.addAll(sectionTypes);
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')} AND books_fts MATCH ?'
        : 'WHERE books_fts MATCH ?';

    final sql =
        '''
      SELECT 
        id,
        book_path,
        book_name,
        page_number,
        section_type,
        content,
        raw_content,
        bm25(books_fts) as rank
      FROM books_fts
      $whereClause
      ORDER BY book_name ASC, book_path ASC, page_number ASC, rank DESC
      LIMIT ? OFFSET ?
    ''';

    final results = await database.rawQuery(sql, [
      ...whereArgs,
      ftsQuery,
      limit,
      offset,
    ]);

    final countSql =
        '''
      SELECT COUNT(*) as total
      FROM books_fts
      $whereClause
    ''';
    final countResult = await database.rawQuery(countSql, [
      ...whereArgs,
      ftsQuery,
    ]);
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    return results.map((row) {
      return {...row, 'estimatedTotalHits': total};
    }).toList();
  }

  /// Morphological search using root matching
  Future<List<Map<String, dynamic>>> morphologicalSearch(
    List<List<String>> searchTermGroups,
    String operator,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
    int proximityDistance,
    int limit,
    int offset,
  ) async {
    final Set<String> searchTerms = {};
    final List<Set<String>> groupTerms = [];

    for (var group in searchTermGroups) {
      final Set<String> groupSet = {};
      for (String term in group) {
        if (term.trim().isEmpty) continue;

        final root = await ArabicMorphologicalAnalyzer.stem(term);
        if (root.length >= 2) {
          groupSet.add(root);
          searchTerms.add(root);
        }

        final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(
          term,
          unifyHamzas: false,
        );
        groupSet.add(normalized);
        searchTerms.add(normalized);
      }
      if (groupSet.isNotEmpty) {
        groupTerms.add(groupSet);
      }
    }

    if (searchTerms.isEmpty) return [];

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (operator.toUpperCase() == 'AND' || allPhrasesRequired) {
      final List<String> groupConditions = [];
      for (var groupSet in groupTerms) {
        final placeholders = List.filled(groupSet.length, '?').join(',');
        groupConditions.add(
          '(root IN ($placeholders) OR normalized_word IN ($placeholders))',
        );
        whereArgs.addAll(groupSet);
        whereArgs.addAll(groupSet);
      }
      whereClauses.add('(${groupConditions.join(' AND ')})');
    } else if (operator.toUpperCase() == 'NOT') {
      final excludePlaceholders = List.filled(
        searchTerms.length,
        '?',
      ).join(',');
      final excludeSql =
          '''
        SELECT DISTINCT id FROM morphological_index
        WHERE (root IN ($excludePlaceholders) OR normalized_word IN ($excludePlaceholders))
      ''';
      final excludeArgs = [...searchTerms, ...searchTerms];
      final excludeResults = await database.rawQuery(excludeSql, excludeArgs);
      final Set<String> excludeIds = excludeResults
          .map((r) => r['id'] as String)
          .toSet();

      if (excludeIds.isEmpty) {
        whereClauses.add('1=1');
      } else {
        final excludePlaceholders2 = List.filled(
          excludeIds.length,
          '?',
        ).join(',');
        whereClauses.add('id NOT IN ($excludePlaceholders2)');
        whereArgs.addAll(excludeIds);
      }
    } else {
      final placeholders = List.filled(searchTerms.length, '?').join(',');
      whereClauses.add(
        '(root IN ($placeholders) OR normalized_word IN ($placeholders))',
      );
      whereArgs.addAll(searchTerms);
      whereArgs.addAll(searchTerms);
    }

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    if (sectionTypes != null && sectionTypes.isNotEmpty) {
      final placeholders = List.filled(sectionTypes.length, '?').join(',');
      whereClauses.add('section_type IN ($placeholders)');
      whereArgs.addAll(sectionTypes);
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final morphSql =
        '''
      SELECT DISTINCT id, book_path, page_number, section_type
      FROM morphological_index
      $whereClause
    ''';

    final morphResults = await database.rawQuery(morphSql, whereArgs);

    if (morphResults.isEmpty) {
      return [];
    }

    final Set<String> matchingIds = morphResults
        .map((r) => r['id'] as String)
        .toSet();

    if (matchingIds.isEmpty) return [];

    final idsPlaceholders = List.filled(matchingIds.length, '?').join(',');
    final sql =
        '''
      SELECT 
        id,
        book_path,
        book_name,
        page_number,
        section_type,
        content,
        raw_content,
        1.0 as rank
      FROM books_fts
      WHERE id IN ($idsPlaceholders)
      ORDER BY book_name ASC, book_path ASC, page_number ASC
      LIMIT ? OFFSET ?
    ''';

    final results = await database.rawQuery(sql, [
      ...matchingIds,
      limit,
      offset,
    ]);

    final countSql =
        '''
      SELECT COUNT(DISTINCT id) as total
      FROM books_fts
      WHERE id IN ($idsPlaceholders)
    ''';
    final countResult = await database.rawQuery(countSql, matchingIds.toList());
    final total = Sqflite.firstIntValue(countResult) ?? matchingIds.length;

    return results.map((row) {
      return {...row, 'estimatedTotalHits': total};
    }).toList();
  }
}
