import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'search_engine/text_normalization.dart';
import 'search_engine/indexing_operations.dart';
import 'search_engine/search_operations.dart';
import 'search_engine/database_queries.dart';

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
      if (Platform.isWindows && databaseFactory == null) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocDir.path, 'tome_ocean', 'shamela_search.db');
      await Directory(p.dirname(dbPath)).create(recursive: true);

      _database = await openDatabase(
        dbPath,
        version: 8,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE VIRTUAL TABLE books_fts USING fts5(
              id UNINDEXED, book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED, section_type UNINDEXED,
              content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
              no_diacritics_content, morphological_content, raw_content UNINDEXED,
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');
          await db.execute('''
            CREATE VIRTUAL TABLE pages_fts USING fts5(
              book_path UNINDEXED, book_name UNINDEXED, page_number UNINDEXED,
              content, normalized_content, hamza_preserved_content, diacritics_preserved_content,
              no_diacritics_content, morphological_content,
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS morphological_index (
              id TEXT, book_path TEXT, page_number INTEGER, section_type TEXT,
              word TEXT, root TEXT, normalized_word TEXT, PRIMARY KEY (id, word)
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_morph_root ON morphological_index(root);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_morph_word ON morphological_index(normalized_word);',
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
            try {
              await db.execute(
                'ALTER TABLE books_metadata ADD COLUMN indexing_version INTEGER;',
              );
              await db.rawUpdate(
                'UPDATE books_metadata SET indexing_version = ?;',
                [oldVersion],
              );
            } catch (e) {
              // Column may already exist
            }
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
  }) async {
    if (_database == null) await initialize();

    final batch = _database!.batch();
    final morphBatch = _database!.batch();
    final total = paragraphs.length;
    int processed = 0;

    await _database!.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('pages_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('morphological_index', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('books_metadata', where: 'book_path = ?', whereArgs: [bookPath]);

    for (var para in paragraphs) {
      final content = para['content'] as String;

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

      String? noDiacriticsContent;
      if (!TextNormalization.hasDiacritics(content)) {
        noDiacriticsContent = TextNormalization.normalizeText(
          content,
          removeDiacritics: true,
          unifyHamzas: true,
        );
      }

      final morphological = await _indexingOps!.createMorphologicalContent(content);

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
        'no_diacritics_content': noDiacriticsContent ?? '',
        'morphological_content': morphological,
        'raw_content': para['raw_content'] ?? content,
      });

      await _indexingOps!.indexWordsForMorphology(
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

    final currentDbVersion = 8;
    batch.insert('books_metadata', {
      'id': base64Encode(utf8.encode(bookPath)).replaceAll(RegExp(r'[+/=]'), '_'),
      'book_path': bookPath,
      'book_name': bookName,
      'indexed_at': DateTime.now().millisecondsSinceEpoch,
      'indexing_version': currentDbVersion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
    await morphBatch.commit(noResult: true);

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
            );
            terms = [exactQuery];
          } else {
            final normalized = TextNormalization.normalizeText(
              query,
              removeDiacritics: true,
              unifyHamzas: !considerHamzas,
            );
            terms = [normalized];
          }
        } else {
          final normalized = TextNormalization.normalizeText(
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
    return await _dbQueries!.searchPages(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      morphologicalSearch: morphologicalSearch,
      limit: limit,
      offset: offset,
    );
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
    if (_database == null) await initialize();
    yield* _dbQueries!.searchPagesStream(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      morphologicalSearch: morphologicalSearch,
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
