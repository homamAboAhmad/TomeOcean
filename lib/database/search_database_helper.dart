import 'dart:io';

import 'package:golden_shamela/database/text_processor.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/utils/utils.dart' as Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Defines the type of search to perform.
enum SearchType { normalized, exact, stemmed }

// Represents a single search result.
class SearchResult {
  final String bookPath;
  final int pageNumber;
  final String snippet;

  SearchResult({
    required this.bookPath,
    required this.pageNumber,
    required this.snippet,
  });

  // A helper to get just the book's file name
  String get bookName => p.basename(bookPath);

  @override
  String toString() {
    return 'SearchResult(book: $bookName, page: $pageNumber, snippet: "$snippet")';
  }
}


// Represents a paginated list of search results.
class PaginatedSearchResults {
  final List<SearchResult> results;
  final int totalCount;

  PaginatedSearchResults({required this.results, required this.totalCount});
}

class SearchDatabaseHelper {
  static const _databaseName = "search_index.db";
  static const _databaseVersion = 2; // Incremented version

  // FTS table names
  static const ftsPagesRaw = 'fts_pages_raw';
  static const ftsPagesNormalized = 'fts_pages_normalized';
  static const ftsPagesStemmed = 'fts_pages_stemmed';
  static const indexedBooksMetadata = 'indexed_books_metadata';
  static const bookMetadata = 'book_metadata'; // New metadata table

  // Singleton class
  SearchDatabaseHelper._privateConstructor();
  static final SearchDatabaseHelper instance = SearchDatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database!;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    // Initialize FFI
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'tome_ocean', _databaseName);
    
    // Create the directory if it doesn't exist
    await Directory(dirname(path)).create(recursive: true);

    return await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade));
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  // Handle database upgrades
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // If upgrading from version 1, create the new book_metadata table
      await db.execute('''
        CREATE TABLE $bookMetadata(
          book_path TEXT PRIMARY KEY,
          title TEXT,
          author_id TEXT,
          section_id TEXT
        );
      ''');
    }
  }

  Future<void> _createTables(Database db) async {
    const ftsOptions = "tokenize = 'unicode61'";

    await db.execute('''
      CREATE VIRTUAL TABLE $ftsPagesRaw USING fts5(
        book_path,
        page_number UNINDEXED,
        content,
        $ftsOptions
      );
      ''');

    await db.execute('''
      CREATE VIRTUAL TABLE $ftsPagesNormalized USING fts5(
        book_path,
        page_number UNINDEXED,
        content,
        $ftsOptions
      );
      ''');
    
    await db.execute('''
      CREATE VIRTUAL TABLE $ftsPagesStemmed USING fts5(
        book_path,
        page_number UNINDEXED,
        content,
        $ftsOptions
      );
      ''');

    await db.execute('''
      CREATE TABLE $indexedBooksMetadata(
        book_path TEXT PRIMARY KEY,
        last_modified_date INTEGER,
        indexed_date INTEGER,
        page_count INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE $bookMetadata(
        book_path TEXT PRIMARY KEY,
        title TEXT,
        author_id TEXT,
        section_id TEXT
      );
    ''');
  }

  /// Retrieves metadata for a specific indexed book.
  Future<Map<String, dynamic>?> getIndexedBookMetadata(String bookPath) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      indexedBooksMetadata,
      where: 'book_path = ?',
      whereArgs: [bookPath],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  /// Inserts or updates metadata for an indexed book.
  Future<void> insertOrUpdateIndexedBookMetadata(
      String bookPath, int lastModified, int pageCount) async {
    final db = await database;
    await db.insert(
      indexedBooksMetadata,
      {
        'book_path': bookPath,
        'last_modified_date': lastModified,
        'indexed_date': DateTime.now().millisecondsSinceEpoch,
        'page_count': pageCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Update if exists
    );
  }

  /// Inserts or updates book metadata (author, section).
  Future<void> insertOrUpdateBookMetadata({
    required String bookPath,
    required String title,
    String? authorId,
    String? sectionId,
  }) async {
    final db = await database;
    await db.insert(
      bookMetadata,
      {
        'book_path': bookPath,
        'title': title,
        'author_id': authorId,
        'section_id': sectionId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves metadata for all indexed books.
  Future<List<Map<String, dynamic>>> getAllIndexedBooksMetadata() async {
    final db = await database;
    return await db.query(indexedBooksMetadata);
  }

  /// Performs a full-text search on the indexed books.
  Future<PaginatedSearchResults> search(String term, SearchType type,
      {int limit = 50,
      int offset = 0,
      String? authorId,
      String? sectionId}) async {
    if (term.trim().isEmpty) {
      return PaginatedSearchResults(results: [], totalCount: 0);
    }

    final db = await database;
    String tableName;
    String processedTerm;

    // Choose table and process term based on search type
    switch (type) {
      case SearchType.exact:
        tableName = ftsPagesRaw;
        processedTerm = term; // Use raw term for exact search
        break;
      case SearchType.normalized:
        tableName = ftsPagesNormalized;
        processedTerm = TextProcessor.normalize(term);
        break;
      case SearchType.stemmed:
        tableName = ftsPagesStemmed;
        processedTerm = TextProcessor.stem(term);
        break;
    }
    
    final String matchQuery = processedTerm;
    List<String> whereClauses = ['$tableName MATCH ?'];
    List<dynamic> whereArgs = [matchQuery];

    // Step 1: Filter book_paths based on metadata if filters are applied
    List<String> filteredBookPaths = [];
    if (authorId != null || sectionId != null) {
      List<String> metadataWhereClauses = [];
      List<dynamic> metadataWhereArgs = [];

      if (authorId != null) {
        metadataWhereClauses.add('author_id = ?');
        metadataWhereArgs.add(authorId);
      }
      if (sectionId != null) {
        metadataWhereClauses.add('section_id = ?');
        metadataWhereArgs.add(sectionId);
      }

      final metadataQuery = await db.query(
        bookMetadata,
        columns: ['book_path'],
        where: metadataWhereClauses.join(' AND '),
        whereArgs: metadataWhereArgs,
      );

      if (metadataQuery.isEmpty) {
        return PaginatedSearchResults(results: [], totalCount: 0); // No books match filters
      }
      filteredBookPaths = metadataQuery.map((row) => row['book_path'] as String).toList();
      
      // Add book_path filter to the main FTS query
      whereClauses.add('book_path IN (${List.filled(filteredBookPaths.length, '?').join(',')})');
      whereArgs.addAll(filteredBookPaths);
    }

    final String whereString = whereClauses.join(' AND ');

    // --- DEBUG PRINTING ---
    print("--- SEARCH DEBUG ---");
    final countSql = 'SELECT COUNT(*) as count FROM $tableName WHERE $whereString';
    print("Count SQL: $countSql");
    print("Count Args: $whereArgs");
    // --- END DEBUG PRINTING ---

    // First, get the total count of results
    final countResult = await db.rawQuery(countSql, whereArgs);
    final totalCount = Sqflite.firstIntValue(countResult) ?? 0;

    if (totalCount == 0) {
      return PaginatedSearchResults(results: [], totalCount: 0);
    }

    // Then, get the paginated results with snippets
    final String snippetColumn = "snippet($tableName, -1, '<b>', '</b>', '...', 10)";
    
    // --- DEBUG PRINTING ---
    final resultsSql = '''
      SELECT
        book_path,
        page_number,
        $snippetColumn as snippet
      FROM $tableName
      WHERE $whereString
      ORDER BY rank
      LIMIT $limit OFFSET $offset;
    ''';
    print("Results SQL: $resultsSql");
    print("Results Args: $whereArgs");
    print("--------------------");
    // --- END DEBUG PRINTING ---

    final List<Map<String, dynamic>> maps = await db.rawQuery(resultsSql, whereArgs);

    final results = List.generate(maps.length, (i) {
      return SearchResult(
        bookPath: maps[i]['book_path'],
        pageNumber: maps[i]['page_number'],
        snippet: maps[i]['snippet'],
      );
    });

    return PaginatedSearchResults(results: results, totalCount: totalCount);
  }
}