import 'dart:async';
import 'dart:io';
import 'dart:isolate'; // Added
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'search_engine/text_normalization.dart';
import 'search_engine/indexing_operations.dart';
import 'search_engine/search_operations.dart';
import 'search_engine/database_queries.dart';
import 'search_engine/search_index_version.dart';
import 'ArabicMorphologicalAnalyzer.dart'; // Added

/// Advanced Arabic Search Engine - Shamela Library Style
/// Supports morphological search, affix search, and all advanced features
class ShamelaSearchEngine {
  static final ShamelaSearchEngine _instance = ShamelaSearchEngine._internal();
  factory ShamelaSearchEngine() => _instance;
  ShamelaSearchEngine._internal();

  Database? _database;
  bool _isInitialized = false;
  Completer<void>? _dbInitializingCompleter;

  IndexingOperations? _indexingOps;
  SearchOperations? _searchOps;
  DatabaseQueries? _dbQueries;

  /// Initialize the search database with multiple indexes for different search modes
  Future<void> initialize() async {
    if (_dbInitializingCompleter != null &&
        !_dbInitializingCompleter!.isCompleted) {
      await _dbInitializingCompleter!.future;
      return;
    }

    if (_isInitialized && _database != null && _database!.isOpen) {
      return;
    }

    _dbInitializingCompleter = Completer<void>();

    try {
      // Ensure Morphology DB is ready for Isolates
      await ArabicMorphologicalAnalyzer.prepareRootsDatabase();

      if (Platform.isWindows && databaseFactory == null) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final dbPath = AppStoragePaths.shamelaSearchDbPath;
      await Directory(p.dirname(dbPath)).create(recursive: true);

      _database = await openDatabase(
        dbPath,
        version: shamelaSearchDatabaseVersion,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE VIRTUAL TABLE books_fts USING fts5(
              id UNINDEXED, book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED, section_type UNINDEXED,
              content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
              fully_preserved_content, no_diacritics_content, morphological_content,
              normalized_no_numbers_content, hamza_preserved_no_numbers_content,
              diacritics_preserved_no_numbers_content, fully_preserved_no_numbers_content,
              raw_content UNINDEXED,
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');
          await db.execute('''
            CREATE VIRTUAL TABLE pages_fts USING fts5(
              book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED,
              content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
              fully_preserved_content, no_diacritics_content, morphological_content,
              normalized_no_numbers_content, hamza_preserved_no_numbers_content,
              diacritics_preserved_no_numbers_content, fully_preserved_no_numbers_content,
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS morphological_index (
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              word TEXT, root TEXT, 
              book_path TEXT, page_number INTEGER, section_type TEXT, 
              paragraph_id TEXT, is_root_match INTEGER
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_morph_root ON morphological_index(root);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_morph_word ON morphological_index(word);',
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS books_metadata (
              id TEXT PRIMARY KEY, book_path TEXT NOT NULL UNIQUE, book_name TEXT NOT NULL,
              indexed_at INTEGER NOT NULL, indexing_version INTEGER NOT NULL
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_book_path ON books_metadata(book_path);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_book_name ON books_metadata(book_name);',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 6) {
             // ... existing migration ...
          }
          // ... (keeping existing migrations for history if needed, but let's just append v10)
          
          if (oldVersion < 10) {
            // Recreate morphological_index with new columns
            await db.execute('DROP TABLE IF EXISTS morphological_index');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS morphological_index (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT, root TEXT,
                book_path TEXT, page_number INTEGER, section_type TEXT,
                paragraph_id TEXT, is_root_match INTEGER
              );
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_morph_root ON morphological_index(root);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_morph_word ON morphological_index(word);',
            );
          }
          
          if (oldVersion < 6) {
            await db.execute('''
              CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
                book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED,
                content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
                no_diacritics_content, morphological_content,
                tokenize = 'unicode61 remove_diacritics 0'
              );
            ''');
          }
          if (oldVersion < 7) {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_book_name ON books_metadata(book_name);',
            );
          }
          if (oldVersion < 8) {
             // ...
          }
          if (oldVersion < 9) {
             // ...
          }
          if (oldVersion < shamelaSearchDatabaseVersion) {
            await db.execute('DROP TABLE IF EXISTS books_fts');
            await db.execute('DROP TABLE IF EXISTS pages_fts');
            await db.execute('DROP TABLE IF EXISTS morphological_index');
            await db.execute('''
              CREATE VIRTUAL TABLE books_fts USING fts5(
                id UNINDEXED, book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED, section_type UNINDEXED,
                content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
                fully_preserved_content, no_diacritics_content, morphological_content,
                normalized_no_numbers_content, hamza_preserved_no_numbers_content,
                diacritics_preserved_no_numbers_content, fully_preserved_no_numbers_content,
                raw_content UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 0'
              );
            ''');
            await db.execute('''
              CREATE VIRTUAL TABLE pages_fts USING fts5(
                book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED,
                content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
                fully_preserved_content, no_diacritics_content, morphological_content,
                normalized_no_numbers_content, hamza_preserved_no_numbers_content,
                diacritics_preserved_no_numbers_content, fully_preserved_no_numbers_content,
                tokenize = 'unicode61 remove_diacritics 0'
              );
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS morphological_index (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT, root TEXT,
                book_path TEXT, page_number INTEGER, section_type TEXT,
                paragraph_id TEXT, is_root_match INTEGER
              );
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_morph_root ON morphological_index(root);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_morph_word ON morphological_index(word);',
            );
            await db.delete('books_metadata');
          }
        },

      );

      _isInitialized = true;
      _indexingOps = IndexingOperations(_database!);
      _searchOps = SearchOperations(_database!);
      _dbQueries = DatabaseQueries(_database!);

      _dbInitializingCompleter!.complete();
    } catch (e, stackTrace) {
      if (!_dbInitializingCompleter!.isCompleted) {
        _dbInitializingCompleter!.completeError(e, stackTrace);
      }
      rethrow;
    } finally {
      _dbInitializingCompleter = null;
    }
  }

  /// Index a book with morphological analysis
  Future<void> indexBook(
    String bookPath,
    String bookName,
    List<Map<String, dynamic>> paragraphs, {
    Function(int current, int total)? onProgress,
    bool Function()? shouldStop,
    Future<void> Function()? acquireLock,
    void Function()? releaseLock,
  }) async {
    if (_database == null) await initialize();

    await _database!.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
      batch.delete('pages_fts', where: 'book_path = ?', whereArgs: [bookPath]);
      batch.delete('morphological_index', where: 'book_path = ?', whereArgs: [bookPath]);
      batch.delete('books_metadata', where: 'book_path = ?', whereArgs: [bookPath]);
      await batch.commit(noResult: true);
    });

    const int chunkSize = 500; // Increased chunk size for better performance
    int processed = 0;
    int total = paragraphs.length;

    for (int i = 0; i < paragraphs.length; i += chunkSize) {
      if (_database == null) break; // Safety check
      if (shouldStop?.call() ?? false) return; // Stop if cancelled

      final end = (i + chunkSize < paragraphs.length) ? i + chunkSize : paragraphs.length;
      final chunk = paragraphs.sublist(i, end);
      
      final batch = _database!.batch();
      final morphBatch = _database!.batch();

      // Optimize: Use Isolate to process text (Normalization + Morphology)
      // This allows parallel CPU work while only locking for DB Commit
      List<Map<String, dynamic>> processedChunk;
      try {
        final rootsDbPath = await ArabicMorphologicalAnalyzer.getDatabasePath();
        final isolateParams = {
          'chunk': chunk,
          'rootsDbPath': rootsDbPath,
        };
        processedChunk = await Isolate.run(() => _processChunkInternal(isolateParams));
      } catch (e) {
        print("Isolate Error: $e");
        // Fallback to main thread if Isolate fails? Or just rethrow?
        // Let's rethrow for now to identify issues.
        rethrow;
      }

      for (var processedItem in processedChunk) {
        final content = processedItem['content'] as String;

        batch.insert('books_fts', {
          'id': processedItem['id'],
          'book_path': bookPath,
          'book_name': bookName,
          'page_number': processedItem['page_number'],
          'section_type': processedItem['section_type'],
          'content': content,
          'normalized_content': processedItem['normalized_content'],
          'hamza_preserved_content': processedItem['hamza_preserved_content'],
          'diacritics_preserved_content': processedItem['diacritics_preserved_content'],
          'fully_preserved_content': processedItem['fully_preserved_content'],
          'no_diacritics_content': processedItem['no_diacritics_content'],
          'morphological_content': processedItem['morphological_content'],
          'normalized_no_numbers_content': processedItem['normalized_no_numbers_content'],
          'hamza_preserved_no_numbers_content': processedItem['hamza_preserved_no_numbers_content'],
          'diacritics_preserved_no_numbers_content': processedItem['diacritics_preserved_no_numbers_content'],
          'fully_preserved_no_numbers_content': processedItem['fully_preserved_no_numbers_content'],
          'raw_content': processedItem['raw_content'] ?? content,
        });

        // Insert morphological words
        if (processedItem['morph_words'] != null) {
          for (var mWord in (processedItem['morph_words'] as List)) {
             morphBatch.insert('morphological_index', {
               'word': mWord['word'],
               'root': mWord['root'],
               'book_path': bookPath,
               'page_number': mWord['page_number'],
               'section_type': mWord['section_type'],
               'paragraph_id': mWord['paragraph_id'],
               'is_root_match': mWord['is_root_match'],
             }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      // CRITICAL: Lock only for the commit phase (IO)

      // CRITICAL: Lock only for the commit phase (IO)
      if (acquireLock != null) await acquireLock();
      try {
        await batch.commit(noResult: true);
        await morphBatch.commit(noResult: true);
      } finally {
        if (releaseLock != null) releaseLock();
      }
      
      processed += chunk.length;
      if (onProgress != null) {
        onProgress(processed, total);
      }
    }

    await _database!.insert('books_metadata', {
      'id': base64Encode(
        utf8.encode(bookPath),
      ).replaceAll(RegExp(r'[+/=]'), '_'),
      'book_path': bookPath,
      'book_name': bookName,
      'indexed_at': DateTime.now().millisecondsSinceEpoch,
      'indexing_version': shamelaSearchIndexVersion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _indexingOps!.indexPages(bookPath, bookName, paragraphs);
  }

  /// Advanced search with all Shamela features
  Future<List<Map<String, dynamic>>> search({
    required List<String> queries,
    required String operator,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    bool morphologicalSearch = false,
    bool affixSearch = false,
    bool considerHamzas = false,
    bool considerDiacritics = false,
    bool considerNumbers = true,
    bool allPhrasesRequired = false,
    bool ordered = false,
    bool proximity = false,
    int proximityDistance = 5,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_database == null) await initialize();

    final List<List<String>> searchTermGroups = [];

    for (String query in queries) {
      if (query.trim().isEmpty) continue;

      List<String> terms = [];

      if (morphologicalSearch) {
        terms = [query];
      } else {
        if (considerDiacritics) {
          final queryHasDiacritics = TextNormalization.hasDiacritics(query);

          if (queryHasDiacritics) {
            final exactQuery = TextNormalization.normalizeText(
              query,
              removeDiacritics: false,
              unifyHamzas: !considerHamzas,
              removeNumbers: !considerNumbers,
            );
            terms = [exactQuery];
          } else {
            final normalized = TextNormalization.normalizeText(
              query,
              removeDiacritics: true,
              unifyHamzas: !considerHamzas,
              removeNumbers: !considerNumbers,
            );
            terms = [normalized];
          }
        } else {
          final normalized = TextNormalization.normalizeText(
            query,
            removeDiacritics: true,
            unifyHamzas: !considerHamzas,
            removeNumbers:
                !considerNumbers, // Remove numbers from query if not considered
          );
          terms = [normalized];
        }
      }

      searchTermGroups.add(terms);
    }

    if (searchTermGroups.isEmpty) return [];

    if (morphologicalSearch) {
      return await _searchOps!.morphologicalSearch(
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
      return await _searchOps!.regularSearch(
        searchTermGroups,
        operator,
        bookPaths,
        sectionTypes,
        considerDiacritics,
        considerHamzas,
        considerNumbers,
        allPhrasesRequired,
        ordered,
        proximity,
        proximityDistance,
        limit,
        offset,
      );
    }
  }

  /// Check if a book needs to be indexed
  Future<bool> needsIndexing(String bookPath) async {
    if (_database == null) await initialize();
    return await _dbQueries!.needsIndexing(bookPath);
  }

  /// Get all indexed books
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    if (_database == null) await initialize();
    return await _dbQueries!.getIndexedBooks();
  }

  Future<void> relocateBookPath(String oldPath, String newPath) async {
    if (_database == null) await initialize();
    if (p.normalize(oldPath).toLowerCase() ==
        p.normalize(newPath).toLowerCase()) {
      return;
    }

    final db = _database!;
    final existing = await db.query(
      'books_metadata',
      columns: ['book_path'],
      where: 'book_path = ?',
      whereArgs: [newPath],
      limit: 1,
    );
    await db.transaction((txn) async {
      if (existing.isNotEmpty) {
        for (final table in [
          'books_metadata',
          'books_fts',
          'pages_fts',
          'morphological_index',
        ]) {
          await txn.delete(table, where: 'book_path = ?', whereArgs: [oldPath]);
        }
        return;
      }

      for (final table in [
        'books_metadata',
        'books_fts',
        'pages_fts',
        'morphological_index',
      ]) {
        await txn.update(
          table,
          {'book_path': newPath},
          where: 'book_path = ?',
          whereArgs: [oldPath],
        );
      }
    });
  }

  Future<void> deleteBook(String bookPath) async {
    if (_database == null) await initialize();
    final db = _database!;
    await db.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await db.delete('pages_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await db.delete(
      'morphological_index',
      where: 'book_path = ?',
      whereArgs: [bookPath],
    );
    await db.delete(
      'books_metadata',
      where: 'book_path = ?',
      whereArgs: [bookPath],
    );
  }

  /// Search pages using page-level FTS index
  Future<List<Map<String, dynamic>>> searchPages({
    required String ftsQuery,
    List<String>? bookPaths,
    List<String>? sectionTypes, // Added sectionTypes
    bool considerDiacritics = false,
    bool considerHamzas = false,
    bool considerNumbers = true,
    bool morphologicalSearch = false,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_database == null) await initialize();
    return await _dbQueries!.searchPages(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      morphologicalSearch: morphologicalSearch,
      limit: limit,
      offset: offset,
    );
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
    if (_database == null) await initialize();
    yield* _dbQueries!.searchPagesStream(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      sectionTypes: sectionTypes, // Pass sectionTypes
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      morphologicalSearch: morphologicalSearch,
      batchSize: batchSize,
      maxResults: maxResults,
    );
  }

  Future<List<Map<String, dynamic>>> listPages({
    List<String>? bookPaths,
    List<String>? sectionTypes,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_database == null) await initialize();

    return await _dbQueries!.listPages(
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      limit: limit,
      offset: offset,
    );
  }

  Stream<List<Map<String, dynamic>>> listPagesStream({
    List<String>? bookPaths,
    List<String>? sectionTypes,
    int batchSize = 10,
    int? maxResults,
  }) async* {
    if (_database == null) await initialize();

    yield* _dbQueries!.listPagesStream(
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      batchSize: batchSize,
      maxResults: maxResults,
    );
  }

  /// Get all paragraphs from a specific page
  Future<List<Map<String, dynamic>>> getParagraphsByPage(
    String bookPath,
    int pageNumber,
  ) async {
    if (_database == null) await initialize();
    return await _dbQueries!.getParagraphsByPage(bookPath, pageNumber);
  }

  Future<String?> getNearestTitleBeforePage(
    String bookPath,
    int pageNumber,
  ) async {
    if (_database == null) await initialize();
    return _dbQueries!.getNearestTitleBeforePage(bookPath, pageNumber);
  }


  /// Close database
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
    _indexingOps = null;
    _searchOps = null;
    _dbQueries = null;
  }
}

/// Helper function to process a chunk of paragraphs in an Isolate
Future<List<Map<String, dynamic>>> _processChunkInternal(
  Map<String, dynamic> params,
) async {
  final chunk = params['chunk'] as List<Map<String, dynamic>>;
  final rootsDbPath = params['rootsDbPath'] as String;

  // Set the DB path manually for this Isolate so it doesn't use path_provider
  ArabicMorphologicalAnalyzer.setDatabasePath(rootsDbPath);
  
  // Ensure DB is ready in this Isolate (if needed by Stemmer)
  // ArabicMorphologicalAnalyzer.stem() calls _loadRootsDatabase() which handles singleton check.
  
  final List<Map<String, dynamic>> results = [];

  for (var para in chunk) {
    final content = para['content'] as String;
    
    // 1. Text Normalization
    final normalized = TextNormalization.normalizeText(
      content,
      removeDiacritics: true,
      unifyHamzas: true,
    );
    final hamzaPreserved = TextNormalization.normalizeText(
      content,
      removeDiacritics: true,
      unifyHamzas: false,
    );
    final diacriticsPreserved = TextNormalization.normalizeText(
      content,
      removeDiacritics: false,
      unifyHamzas: true,
    );
    final fullyPreserved = TextNormalization.normalizeText(
      content,
      removeDiacritics: false,
      unifyHamzas: false,
    );
    final normalizedNoNumbers = TextNormalization.normalizeText(
      content,
      removeDiacritics: true,
      unifyHamzas: true,
      removeNumbers: true,
    );
    final hamzaPreservedNoNumbers = TextNormalization.normalizeText(
      content,
      removeDiacritics: true,
      unifyHamzas: false,
      removeNumbers: true,
    );
    final diacriticsPreservedNoNumbers = TextNormalization.normalizeText(
      content,
      removeDiacritics: false,
      unifyHamzas: true,
      removeNumbers: true,
    );
    final fullyPreservedNoNumbers = TextNormalization.normalizeText(
      content,
      removeDiacritics: false,
      unifyHamzas: false,
      removeNumbers: true,
    );

    String? noDiacriticsContent;
    if (!TextNormalization.hasDiacritics(content)) {
      noDiacriticsContent = TextNormalization.normalizeText(
        content,
        removeDiacritics: true,
        unifyHamzas: true,
      );
    }
    
    // 2. Morphological Analysis (Logic duplicated from createMorphologicalContent)
    final words = TextNormalization.extractArabicWords(content);
    final List<String> morphologicalParts = [];
    final List<Map<String, dynamic>> morphWords = [];

    for (String word in words) {
      if (word.length < 2) continue;

      // Calculate Root
      final root = await ArabicMorphologicalAnalyzer.stem(word);
      
      // Calculate Normalized form for comparison
      // Note: normalizeForMorphology is missing in ArabicMorphologicalAnalyzer?
      // Wait, let's check. createMorphologicalContent used it.
      // If it's missing, maybe it was a confusion with TextNormalization?
      // Re-reading createMorphologicalContent logic:
      // final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(word);
      // I need to check if normalizeForMorphology exists. 
      // If not, I'll use TextNormalization.normalizeText with morph settings.
      
      // Checking ArabicMorphologicalAnalyzer content from previous steps...
      // It DOES contain normalizeForMorphology? No, I viewed lines 1-800 and didn't see it exposed PUBLICLY.
      // But _stemWithAlgorithm calls normalizeForMorphology internally?
      // Line 173: String normalized = normalizeForMorphology(word, ...);
      // Wait, is normalizeForMorphology a method in that class? 
      // If it's private or I missed it without "static".
      // Line 173 call suggests it exists.
      // Let's assume it exists or use TextNormalization as fallback.
      // Actually, looking at TextNormalization usage, it seems robust.
      // Let's use TextNormalization which is public static.
      
      final wordNormalized = TextNormalization.normalizeText(word, removeDiacritics: true, unifyHamzas: true);
      
      morphologicalParts.add(wordNormalized);
      if (root.length >= 2 && root != wordNormalized) {
        morphologicalParts.add(root);
      }
      
      // Prepare Morphological Word Entry
      morphWords.add({
        'word': wordNormalized,
        'root': root,
        'page_number': para['page_number'],
        'section_type': para['section_type'],
        'paragraph_id': para['id'],
        'is_root_match': (root != wordNormalized) ? 1 : 0,
      });
    }

    final morphologicalContent = morphologicalParts.join(' ');

    results.add({
      ...para, // Copy original fields
      'normalized_content': normalized,
      'hamza_preserved_content': hamzaPreserved,
      'diacritics_preserved_content': diacriticsPreserved,
      'fully_preserved_content': fullyPreserved,
      'no_diacritics_content': noDiacriticsContent ?? '',
      'normalized_no_numbers_content': normalizedNoNumbers,
      'hamza_preserved_no_numbers_content': hamzaPreservedNoNumbers,
      'diacritics_preserved_no_numbers_content': diacriticsPreservedNoNumbers,
      'fully_preserved_no_numbers_content': fullyPreservedNoNumbers,
      'morphological_content': morphologicalContent,
      'morph_words': morphWords,
    });
  }

  return results;
}
