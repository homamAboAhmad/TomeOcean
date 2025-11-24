import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'ArabicMorphologicalAnalyzer.dart';
import 'page_content_aggregator.dart';

/// Advanced Arabic Search Engine - Shamela Library Style
/// Supports morphological search, affix search, and all advanced features
class ShamelaSearchEngine {
  static final ShamelaSearchEngine _instance = ShamelaSearchEngine._internal();
  factory ShamelaSearchEngine() => _instance;
  ShamelaSearchEngine._internal();

  Database? _database;
  bool _isInitialized = false;

  /// Initialize the search database with multiple indexes for different search modes
  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;

    try {
      // Database factory should already be initialized in main.dart for Windows
      // This is just a safety check
      if (Platform.isWindows && databaseFactory == null) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        print("ShamelaSearchEngine: Database factory initialized (safety check)");
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocDir.path, 'tome_ocean', 'shamela_search.db');
      await Directory(p.dirname(dbPath)).create(recursive: true);

      _database = await openDatabase(
        dbPath,
        version: 6, // Added pages_fts table for page-level search
        onCreate: (db, version) async {
          // Main FTS5 table with multiple content columns for different search modes
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(
              id UNINDEXED,
              book_path UNINDEXED,
              book_name UNINDEXED,
              page_number UNINDEXED,
              section_type UNINDEXED,
              content,                    -- Original content
              normalized_content,         -- Normalized (no diacritics, unified hamzas)
              hamza_preserved_content,    -- Content with hamzas preserved (no diacritics)
              diacritics_preserved_content, -- Content with diacritics preserved (for exact matching)
              no_diacritics_content,      -- Content that originally had NO diacritics (for diacritics-sensitive search)
              morphological_content,      -- For morphological search (with roots)
              raw_content UNINDEXED,      -- Exact content with diacritics (for display only)
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');

          // Create index for morphological search (stores roots)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS morphological_index (
              id TEXT,
              book_path TEXT,
              page_number INTEGER,
              section_type TEXT,
              word TEXT,
              root TEXT,
              normalized_word TEXT,
              PRIMARY KEY (id, word)
            );
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_morph_root ON morphological_index(root);
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_morph_word ON morphological_index(normalized_word);
          ''');

          // Metadata table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS books_metadata (
              id TEXT PRIMARY KEY,
              book_path TEXT NOT NULL,
              book_name TEXT NOT NULL,
              indexed_at INTEGER NOT NULL,
              UNIQUE(book_path)
            );
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_book_path ON books_metadata(book_path);
          ''');

          // Page-level FTS table for aggregated page content search
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
              book_path UNINDEXED,
              book_name UNINDEXED,
              page_number UNINDEXED,
              content,                    -- Aggregated page content
              normalized_content,         -- Normalized aggregated content
              hamza_preserved_content,    -- Hamza preserved aggregated content
              diacritics_preserved_content, -- Diacritics preserved aggregated content
              no_diacritics_content,      -- No diacritics aggregated content
              morphological_content,     -- Morphological aggregated content
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Drop and recreate FTS table to add new columns or fix structure
          if (oldVersion < 5) {
            await db.execute('DROP TABLE IF EXISTS books_fts');
            await db.execute('''
              CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(
                id UNINDEXED,
                book_path UNINDEXED,
                book_name UNINDEXED,
                page_number UNINDEXED,
                section_type UNINDEXED,
                content,
                normalized_content,
                hamza_preserved_content,
                diacritics_preserved_content,
                no_diacritics_content,
                morphological_content,
                raw_content UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 0'
              );
            ''');
          }
          // Add pages_fts table for page-level search
          if (oldVersion < 6) {
            await db.execute('''
              CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
                book_path UNINDEXED,
                book_name UNINDEXED,
                page_number UNINDEXED,
                content,
                normalized_content,
                hamza_preserved_content,
                diacritics_preserved_content,
                no_diacritics_content,
                morphological_content,
                tokenize = 'unicode61 remove_diacritics 0'
              );
            ''');
          }
        },
      );

      _isInitialized = true;
      print("ShamelaSearchEngine: Database initialized successfully");
    } catch (e) {
      print("ShamelaSearchEngine: Error initializing database: $e");
      rethrow;
    }
  }

  /// Index a book with morphological analysis
  Future<void> indexBook(
    String bookPath,
    String bookName,
    List<Map<String, dynamic>> paragraphs, {
    Function(int current, int total)? onProgress,
  }) async {
    if (_database == null) await initialize();

    final batch = _database!.batch();
    final morphBatch = _database!.batch();
    int total = paragraphs.length;
    int processed = 0;

    // Delete existing entries
    await _database!.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('pages_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('morphological_index', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('books_metadata', where: 'book_path = ?', whereArgs: [bookPath]);

    for (var para in paragraphs) {
      String content = para['content'] as String;
      
      // Normalize for regular search (hamzas unified)
      String normalized = _normalizeText(content, removeDiacritics: true, unifyHamzas: true);
      
      // Preserve hamzas but remove diacritics (for hamza-sensitive search)
      String hamzaPreserved = _normalizeText(content, removeDiacritics: true, unifyHamzas: false);
      
      // Preserve diacritics but unify hamzas (for diacritics-sensitive search)
      // Store ONLY the exact diacritics version (no normalized duplicate)
      String diacriticsPreserved = _normalizeText(content, removeDiacritics: false, unifyHamzas: true);
      
      // Store content that originally had NO diacritics (for diacritics-sensitive search when query has no diacritics)
      // This column only contains content that originally had no diacritics
      String? noDiacriticsContent;
      if (!_hasDiacritics(content)) {
        // Only store if the original content has no diacritics
        noDiacriticsContent = _normalizeText(content, removeDiacritics: true, unifyHamzas: true);
      }
      
      // Create morphological content (with roots)
      String morphological = await _createMorphologicalContent(content);

      batch.insert('books_fts', {
        'id': para['id'],
        'book_path': bookPath,
        'book_name': bookName,
        'page_number': para['page_number'],
        'section_type': para['section_type'],
        'content': content,
        'normalized_content': normalized,
        'hamza_preserved_content': hamzaPreserved,
        'diacritics_preserved_content': diacriticsPreserved,
        'no_diacritics_content': noDiacriticsContent ?? '', // Empty if original had diacritics
        'morphological_content': morphological,
        'raw_content': para['raw_content'] ?? content,
      });

      // Index individual words for morphological search
      await _indexWordsForMorphology(
        para['id'] as String,
        bookPath,
        para['page_number'] as int,
        para['section_type'] as String,
        content,
        morphBatch,
      );

      processed++;
      if (onProgress != null && processed % 100 == 0) {
        onProgress(processed, total);
      }
    }

    // Insert metadata
    batch.insert('books_metadata', {
      'id': base64Encode(utf8.encode(bookPath)).replaceAll(RegExp(r'[+/=]'), '_'),
      'book_path': bookPath,
      'book_name': bookName,
      'indexed_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
    await morphBatch.commit(noResult: true);
    
    // Index pages (aggregate paragraphs by page)
    await _indexPages(bookPath, bookName, paragraphs);
    
    // Verify morphological index was populated
    final morphCount = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM morphological_index WHERE book_path = ?',
      [bookPath]
    );
    print("ShamelaSearchEngine: Indexed $processed paragraphs for $bookName");
    print("ShamelaSearchEngine: Morphological index contains ${morphCount.first['count']} entries for this book");
  }

  /// Index pages by aggregating paragraph content
  Future<void> _indexPages(
    String bookPath,
    String bookName,
    List<Map<String, dynamic>> paragraphs,
  ) async {
    if (_database == null) return;

    // Group paragraphs by page
    final pageGroups = PageContentAggregator.groupByPage(paragraphs);
    final pageBatch = _database!.batch();

    for (var entry in pageGroups.entries) {
      final pageParagraphs = entry.value;
      if (pageParagraphs.isEmpty) continue;

      // Get page number from first paragraph
      final pageNumber = pageParagraphs.first['page_number'] as int? ?? 0;
      
      // Aggregate content
      final aggregatedContent = PageContentAggregator.aggregatePageContent(pageParagraphs);
      if (aggregatedContent.trim().isEmpty) continue;

      // Normalize content variants
      final normalized = _normalizeText(aggregatedContent, removeDiacritics: true, unifyHamzas: true);
      final hamzaPreserved = _normalizeText(aggregatedContent, removeDiacritics: true, unifyHamzas: false);
      final diacriticsPreserved = _normalizeText(aggregatedContent, removeDiacritics: false, unifyHamzas: true);
      
      String? noDiacriticsContent;
      if (!_hasDiacritics(aggregatedContent)) {
        noDiacriticsContent = _normalizeText(aggregatedContent, removeDiacritics: true, unifyHamzas: true);
      }
      
      final morphological = await _createMorphologicalContent(aggregatedContent);

      pageBatch.insert('pages_fts', {
        'book_path': bookPath,
        'book_name': bookName,
        'page_number': pageNumber,
        'content': aggregatedContent,
        'normalized_content': normalized,
        'hamza_preserved_content': hamzaPreserved,
        'diacritics_preserved_content': diacriticsPreserved,
        'no_diacritics_content': noDiacriticsContent ?? '',
        'morphological_content': morphological,
      });
    }

    await pageBatch.commit(noResult: true);
    print("ShamelaSearchEngine: Indexed ${pageGroups.length} pages for $bookName");
  }

  /// Index words for morphological search using ISRI stemmer
  Future<void> _indexWordsForMorphology(
    String id,
    String bookPath,
    int pageNumber,
    String sectionType,
    String content,
    Batch batch,
  ) async {
    // Extract Arabic words
    List<String> words = _extractArabicWords(content);
    
    if (words.isEmpty) {
      // Debug: check if content has any text at all
      if (content.trim().isNotEmpty) {
        print("Warning: No Arabic words extracted from content: '${content.substring(0, content.length > 50 ? 50 : content.length)}...'");
      }
      return;
    }
    
    int wordsIndexed = 0;
    for (String word in words) {
      if (word.length < 2) continue;
      
      // Use ISRI stemmer directly - it handles normalization internally
      // This ensures consistency: stem() normalizes with unifyHamzas: false to preserve hamzas
      String root = await ArabicMorphologicalAnalyzer.stem(word);
      
      // Also normalize for exact word matching (with hamzas preserved for consistency)
      String normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(word, unifyHamzas: false);
      
      try {
        batch.insert('morphological_index', {
          'id': id,
          'book_path': bookPath,
          'page_number': pageNumber,
          'section_type': sectionType,
          'word': word,
          'root': root,
          'normalized_word': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        wordsIndexed++;
      } catch (e) {
        // Ignore duplicate key errors (same word in same paragraph)
        print("Warning: Could not insert word '$word' for id '$id': $e");
      }
    }
    
    // Debug: print first few words indexed
    if (wordsIndexed > 0 && wordsIndexed <= 3) {
      print("Indexed $wordsIndexed words for paragraph $id (first word: '${words.first}')");
    }
  }

  /// Extract Arabic words from text
  List<String> _extractArabicWords(String text) {
    // Match Arabic words (including numbers if needed)
    RegExp arabicWordRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+');
    return arabicWordRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Check if a string contains Arabic diacritics
  bool _hasDiacritics(String text) {
    return RegExp(r'[\u064B-\u0652]').hasMatch(text);
  }

  /// Normalize text based on options
  String _normalizeText(String text, {
    bool removeDiacritics = true,
    bool unifyHamzas = true,
  }) {
    String normalized = text;

    if (removeDiacritics) {
      normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    }

    if (unifyHamzas) {
      normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
      normalized = normalized.replaceAll('ؤ', 'و');
      normalized = normalized.replaceAll('ئ', 'ي');
    }

    return normalized;
  }

  /// Create morphological content using ISRI stemmer (includes roots for better matching)
  Future<String> _createMorphologicalContent(String text) async {
    List<String> words = _extractArabicWords(text);
    List<String> morphological = [];

    for (String word in words) {
      if (word.length < 2) continue;
      
      // Normalize word
      String normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(word);
      morphological.add(normalized);
      
      // Use ISRI stemmer to extract root
      String root = await ArabicMorphologicalAnalyzer.stem(normalized);
      if (root.length >= 2 && root != normalized) {
        morphological.add(root);
      }
    }

    return morphological.join(' ');
  }

  /// Advanced search with all Shamela features
  Future<List<Map<String, dynamic>>> search({
    required List<String> queries, // Multiple search terms
    required String operator, // 'AND', 'OR', 'NOT'
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool morphologicalSearch = false, // بحث صرفي
    bool affixSearch = false, // بحث باللواصق
    bool considerHamzas = false, // مراعاة الهمزات
    bool considerDiacritics = false, // مراعاة التشكيل
    bool considerNumbers = true, // مراعاة الأرقام
    bool allPhrasesRequired = false, // يلزم وجود كل العبارات
    bool ordered = false, // مرتبة
    bool proximity = false, // متقاربة
    int proximityDistance = 5, // Distance for proximity search
    int limit = 100,
    int offset = 0,
  }) async {
    if (_database == null) await initialize();

    // Build search terms based on options
    List<List<String>> searchTermGroups = [];
    
    for (String query in queries) {
      if (query.trim().isEmpty) continue;
      
      List<String> terms = [];
      
      if (morphologicalSearch) {
        // Morphological search: use the query as-is, we'll process it in _morphologicalSearch
        // Don't use getMorphologicalSearchTerms here because it already normalizes and extracts roots
        // We want to do that in _morphologicalSearch to match the indexing process
        terms = [query]; // Just use the original query
      } else {
        // Regular search - normalize query based on options
        if (considerDiacritics) {
          // When considerDiacritics is enabled:
          // - If query has NO diacritics: find BOTH versions (with and without diacritics)
          // - If query HAS diacritics: find EXACT match only
          bool queryHasDiacritics = _hasDiacritics(query);
          
          if (queryHasDiacritics) {
            // Query has diacritics: search for exact match only
            // Only normalize hamzas if needed, but preserve diacritics
            String exactQuery = _normalizeText(query, removeDiacritics: false, unifyHamzas: !considerHamzas);
            terms = [exactQuery]; // Exact match with diacritics
          } else {
            // Query has NO diacritics: find ONLY words without diacritics (exact match)
            // Search in diacritics_preserved_content but we need to filter to only match words without diacritics
            // Since FTS5 can't do this directly, we'll search and filter results
            String normalized = _normalizeText(query, removeDiacritics: true, unifyHamzas: !considerHamzas);
            terms = [normalized]; // Search for normalized version
          }
        } else {
          // Normal case: always normalize the query (ignore diacritics)
          String normalized = _normalizeText(
            query,
            removeDiacritics: true,
            unifyHamzas: !considerHamzas,
          );
          terms = [normalized];
        }
      }
      
      searchTermGroups.add(terms);
    }

    if (searchTermGroups.isEmpty) return [];

    // Build SQL query based on search type
    if (morphologicalSearch) {
      return await _morphologicalSearch(
        searchTermGroups,
        operator,
        bookPaths,
        sectionTypes,
        allPhrasesRequired,
        ordered,
        proximity,
        proximityDistance,
        limit,
        offset,
      );
    } else {
      return await _regularSearch(
        searchTermGroups,
        operator,
        bookPaths,
        sectionTypes,
        considerDiacritics,
        considerHamzas,
        allPhrasesRequired,
        ordered,
        proximity,
        proximityDistance,
        limit,
        offset,
      );
    }
  }

  /// Regular FTS5 search
  Future<List<Map<String, dynamic>>> _regularSearch(
    List<List<String>> searchTermGroups,
    String operator,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool considerDiacritics,
    bool considerHamzas,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
    int proximityDistance,
    int limit,
    int offset,
  ) async {
    // Choose the right content column based on search options
    String contentColumn;
    
    // Check if any query has diacritics (for considerDiacritics logic)
    bool anyQueryHasDiacritics = searchTermGroups.any((group) => 
      group.any((term) => _hasDiacritics(term))
    );
    
    if (considerDiacritics && considerHamzas) {
      // Both diacritics and hamzas matter
      contentColumn = 'diacritics_preserved_content';
    } else if (considerDiacritics) {
      // If diacritics matter:
      // - If query has diacritics: use diacritics_preserved_content for exact match
      // - If query has NO diacritics: use no_diacritics_content (only content that originally had no diacritics)
      if (anyQueryHasDiacritics) {
        contentColumn = 'diacritics_preserved_content'; // Exact match with diacritics
      } else {
        contentColumn = 'no_diacritics_content'; // Only content that originally had no diacritics
      }
    } else if (considerHamzas) {
      // If hamzas matter but diacritics don't, use hamza_preserved_content
      contentColumn = 'hamza_preserved_content';
    } else {
      // Default: use normalized_content (hamzas unified, no diacritics)
      contentColumn = 'normalized_content';
    }

    List<String> ftsQueries = [];
    for (var group in searchTermGroups) {
      if (group.isEmpty) continue;
      
      if (group.length == 1) {
        ftsQueries.add('${group[0]}*');
      } else {
        // Multiple terms in group - use OR within group
        ftsQueries.add('(${group.map((t) => '$t*').join(' OR ')})');
      }
    }

    if (ftsQueries.isEmpty) return [];

    // Build FTS5 query with column prefix
    String ftsQuery;
    String columnPrefix = '$contentColumn:';
    
    if (allPhrasesRequired) {
      // All phrases must exist
      ftsQuery = ftsQueries.map((q) => '$columnPrefix$q').join(operator == 'AND' ? ' AND ' : ' OR ');
    } else if (ordered && proximity) {
      // Ordered and proximity
      String phrase = searchTermGroups.map((g) => g.first).join(' ');
      ftsQuery = '$columnPrefix NEAR($phrase, $proximityDistance)';
    } else if (ordered) {
      // Ordered phrase
      String phrase = searchTermGroups.map((g) => g.first).join(' ');
      ftsQuery = '$columnPrefix "$phrase"';
    } else {
      // Regular search
      ftsQuery = ftsQueries.map((q) => '$columnPrefix$q').join(operator == 'AND' ? ' AND ' : ' OR ');
    }

    // Build WHERE clause
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

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

    final sql = '''
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
      AND books_fts MATCH ?
      ORDER BY rank DESC, page_number ASC
      LIMIT ? OFFSET ?
    ''';

    final results = await _database!.rawQuery(
      sql,
      [...whereArgs, ftsQuery, limit, offset],
    );

    final countSql = '''
      SELECT COUNT(*) as total
      FROM books_fts
      $whereClause
      AND books_fts MATCH ?
    ''';
    final countResult = await _database!.rawQuery(
      countSql,
      [...whereArgs, ftsQuery],
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    return results.map((row) => {
      ...row,
      'estimatedTotalHits': total,
    }).toList();
  }

  /// Morphological search using root matching
  Future<List<Map<String, dynamic>>> _morphologicalSearch(
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
    // For morphological search, we search by roots and normalized words
    // Collect all search terms (roots and normalized words) from all groups
    Set<String> searchTerms = {};
    List<Set<String>> groupTerms = [];
    
    for (var group in searchTermGroups) {
      Set<String> groupSet = {};
      for (String term in group) {
        if (term.trim().isEmpty) continue;
        
        // Use ISRI stemmer directly - it handles normalization internally
        // This ensures consistency with indexing (which also uses stem())
        String root = await ArabicMorphologicalAnalyzer.stem(term);
        if (root.length >= 2) {
          groupSet.add(root);
          searchTerms.add(root);
        }
        
        // Also add normalized version for exact word matching
        // Use unifyHamzas: false to preserve hamzas for root extraction
        String normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(term, unifyHamzas: false);
        groupSet.add(normalized);
        searchTerms.add(normalized);
        
        // Debug: print what we're searching for
        print("Morphological search - term: '$term', normalized: '$normalized', root: '$root'");
      }
      if (groupSet.isNotEmpty) {
        groupTerms.add(groupSet);
      }
    }

    if (searchTerms.isEmpty) return [];

    // Build WHERE clause based on operator
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Handle AND/OR/NOT operators
    if (operator.toUpperCase() == 'AND' || allPhrasesRequired) {
      // All groups must match (AND)
      // Each group must have at least one term matching
      List<String> groupConditions = [];
      for (var groupSet in groupTerms) {
        final placeholders = List.filled(groupSet.length, '?').join(',');
        groupConditions.add('(root IN ($placeholders) OR normalized_word IN ($placeholders))');
        whereArgs.addAll(groupSet);
        whereArgs.addAll(groupSet);
      }
      whereClauses.add('(${groupConditions.join(' AND ')})');
    } else if (operator.toUpperCase() == 'NOT') {
      // NOT: find all documents, then exclude those matching the terms
      // First get all document IDs that match the terms
      final excludePlaceholders = List.filled(searchTerms.length, '?').join(',');
      final excludeSql = '''
        SELECT DISTINCT id FROM morphological_index
        WHERE (root IN ($excludePlaceholders) OR normalized_word IN ($excludePlaceholders))
      ''';
      final excludeArgs = [...searchTerms, ...searchTerms];
      final excludeResults = await _database!.rawQuery(excludeSql, excludeArgs);
      Set<String> excludeIds = excludeResults.map((r) => r['id'] as String).toSet();
      
      if (excludeIds.isEmpty) {
        // No documents to exclude, return all
        whereClauses.add('1=1'); // Always true
      } else {
        // Exclude matching IDs
        final excludePlaceholders2 = List.filled(excludeIds.length, '?').join(',');
        whereClauses.add('id NOT IN ($excludePlaceholders2)');
        whereArgs.addAll(excludeIds);
      }
    } else {
      // OR: any group can match
      final placeholders = List.filled(searchTerms.length, '?').join(',');
      whereClauses.add('(root IN ($placeholders) OR normalized_word IN ($placeholders))');
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

    final whereClause = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    // Get matching document IDs
    final morphSql = '''
      SELECT DISTINCT id, book_path, page_number, section_type
      FROM morphological_index
      $whereClause
    ''';

    // Debug: print the SQL query
    print("Morphological search SQL: $morphSql");
    print("Morphological search args: $whereArgs");
    print("Search terms: $searchTerms");
    
    final morphResults = await _database!.rawQuery(morphSql, whereArgs);
    print("Morphological search found ${morphResults.length} matching rows");
    
    if (morphResults.isEmpty) {
      // Debug: check if there are any entries in morphological_index at all
      final testQuery = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM morphological_index LIMIT 1'
      );
      print("Total entries in morphological_index: ${testQuery.first['count']}");
      
      // Debug: check if any of our search terms exist
      if (searchTerms.isNotEmpty) {
        final testTerm = searchTerms.first;
        final testResults = await _database!.rawQuery(
          'SELECT COUNT(*) as count FROM morphological_index WHERE root = ? OR normalized_word = ?',
          [testTerm, testTerm]
        );
        print("Entries matching test term '$testTerm': ${testResults.first['count']}");
      }
      
      return [];
    }

    Set<String> matchingIds = morphResults.map((r) => r['id'] as String).toSet();

    if (matchingIds.isEmpty) return [];

    // Now get full content from FTS table
    final idsPlaceholders = List.filled(matchingIds.length, '?').join(',');
    final sql = '''
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
      ORDER BY page_number ASC
      LIMIT ? OFFSET ?
    ''';

    final results = await _database!.rawQuery(
      sql,
      [...matchingIds, limit, offset],
    );

    // Count total results
    final countSql = '''
      SELECT COUNT(DISTINCT id) as total
      FROM books_fts
      WHERE id IN ($idsPlaceholders)
    ''';
    final countResult = await _database!.rawQuery(countSql, matchingIds.toList());
    final total = Sqflite.firstIntValue(countResult) ?? matchingIds.length;

    return results.map((row) => {
      ...row,
      'estimatedTotalHits': total,
    }).toList();
  }

  /// Get all indexed books
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    if (_database == null) await initialize();

    final results = await _database!.query(
      'books_metadata',
      columns: ['book_path', 'book_name'],
      orderBy: 'book_name ASC',
    );

    return results;
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
    if (_database == null) await initialize();

    // Choose content column
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

    // Build WHERE clause
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    final columnPrefix = '$contentColumn:';
    final fullQuery = '$columnPrefix$ftsQuery';

    // Build WHERE clause with MATCH condition
    String whereClause;
    if (whereClauses.isNotEmpty) {
      whereClause = 'WHERE ${whereClauses.join(' AND ')} AND pages_fts MATCH ?';
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

    final results = await _database!.rawQuery(
      sql,
      [...whereArgs, fullQuery, limit, offset],
    );

    final countSql = '''
      SELECT COUNT(*) as total
      FROM pages_fts
      $whereClause
    ''';
    final countResult = await _database!.rawQuery(
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

  /// Get all paragraphs from a specific page
  /// Uses FTS5 MATCH with a common Arabic word to get all paragraphs from the page
  Future<List<Map<String, dynamic>>> getParagraphsByPage(
    String bookPath,
    int pageNumber,
  ) async {
    if (_database == null) await initialize();

    // Use FTS5 MATCH with a very common Arabic word (ال) that exists in almost all Arabic texts
    // This allows us to query the FTS table while filtering by book_path and page_number
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

    final results = await _database!.rawQuery(sql, [bookPath, pageNumber]);

    return results.map((row) => {
      'id': row['id'],
      'book_path': row['book_path'],
      'book_name': row['book_name'],
      'page_number': row['page_number'],
      'section_type': row['section_type'],
      'content': row['content'],
      'raw_content': row['raw_content'],
    }).toList();
  }

  /// Close database
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}

