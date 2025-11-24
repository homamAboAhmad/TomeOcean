import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../Helpers/TextProcessor.dart';
import 'BooksMetadataDatabase.dart';

/// High-performance Arabic search engine using SQLite FTS5
/// Optimized for Arabic books with proper normalization and stemming
class ArabicSearchEngine {
  static final ArabicSearchEngine _instance = ArabicSearchEngine._internal();
  factory ArabicSearchEngine() => _instance;
  ArabicSearchEngine._internal();

  Database? _database;
  bool _isInitialized = false;

  /// Initialize the search database
  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocDir.path, 'tome_ocean', 'arabic_search.db');
      await Directory(p.dirname(dbPath)).create(recursive: true);

      _database = await openDatabase(
        dbPath,
        version: 2, // Increment version for schema update
        onCreate: (db, version) async {
          // Create FTS5 virtual table optimized for Arabic
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(
              id UNINDEXED,
              book_path UNINDEXED,
              book_name UNINDEXED,
              page_number UNINDEXED,
              section_type UNINDEXED,
              content,
              normalized_content,
              raw_content UNINDEXED,
              tokenize = 'unicode61 remove_diacritics 0'
            );
          ''');

          // Create regular table for metadata
          await db.execute('''
            CREATE TABLE IF NOT EXISTS books_metadata (
              id TEXT PRIMARY KEY,
              book_path TEXT NOT NULL,
              book_name TEXT NOT NULL,
              author_id TEXT,
              section_id TEXT,
              indexed_at INTEGER NOT NULL,
              UNIQUE(book_path)
            );
          ''');

          // Create indexes for faster lookups
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_book_path ON books_metadata(book_path);
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_book_author ON books_metadata(author_id);
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_book_section ON books_metadata(section_id);
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_book_author_section ON books_metadata(author_id, section_id);
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Add author_id and section_id columns if they don't exist
            try {
              await db.execute('ALTER TABLE books_metadata ADD COLUMN author_id TEXT');
            } catch (e) {
              // Column might already exist
              print("ArabicSearchEngine: author_id column may already exist: $e");
            }
            
            try {
              await db.execute('ALTER TABLE books_metadata ADD COLUMN section_id TEXT');
            } catch (e) {
              // Column might already exist
              print("ArabicSearchEngine: section_id column may already exist: $e");
            }

            // Create indexes
            await db.execute('''
              CREATE INDEX IF NOT EXISTS idx_book_author ON books_metadata(author_id);
            ''');

            await db.execute('''
              CREATE INDEX IF NOT EXISTS idx_book_section ON books_metadata(section_id);
            ''');

            await db.execute('''
              CREATE INDEX IF NOT EXISTS idx_book_author_section ON books_metadata(author_id, section_id);
            ''');
          }
        },
      );

      _isInitialized = true;
      print("ArabicSearchEngine: Database initialized successfully");
    } catch (e) {
      print("ArabicSearchEngine: Error initializing database: $e");
      rethrow;
    }
  }

  /// Index a single book
  Future<void> indexBook(
    String bookPath,
    String bookName,
    List<Map<String, dynamic>> paragraphs, {
    Function(int current, int total)? onProgress,
    String? authorId,
    String? sectionId,
  }) async {
    if (_database == null) await initialize();

    // Get author_id and section_id from BooksMetadataDatabase if not provided
    if (authorId == null || sectionId == null) {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      final bookCard = await metadataDb.getBookByPath(bookPath);
      if (bookCard != null) {
        authorId ??= bookCard.authorId.isNotEmpty ? bookCard.authorId : null;
        sectionId ??= bookCard.sectionId.isNotEmpty ? bookCard.sectionId : null;
      }
    }

    final batch = _database!.batch();
    int total = paragraphs.length;
    int processed = 0;

    // Delete existing entries for this book
    await _database!.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('books_metadata', where: 'book_path = ?', whereArgs: [bookPath]);

    for (var para in paragraphs) {
      final normalized = TextProcessor.normalizeArabic(para['content'] as String);
      final stemmed = TextProcessor.lightStemArabic(normalized);

      batch.insert('books_fts', {
        'id': para['id'],
        'book_path': bookPath,
        'book_name': bookName,
        'page_number': para['page_number'],
        'section_type': para['section_type'],
        'content': para['content'],
        'normalized_content': normalized,
        'raw_content': para['raw_content'] ?? para['content'],
      });

      processed++;
      if (onProgress != null && processed % 100 == 0) {
        onProgress(processed, total);
      }
    }

    // Insert metadata with author_id and section_id
    batch.insert('books_metadata', {
      'id': base64Encode(utf8.encode(bookPath)).replaceAll(RegExp(r'[+/=]'), '_'),
      'book_path': bookPath,
      'book_name': bookName,
      'author_id': authorId,
      'section_id': sectionId,
      'indexed_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
    print("ArabicSearchEngine: Indexed $processed paragraphs for $bookName");
  }

  /// Search with Arabic normalization
  Future<List<Map<String, dynamic>>> search({
    required String query,
    List<String>? bookPaths,
    List<String>? sectionTypes,
    String? authorId,
    String? sectionId,
    bool exactMatch = false,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_database == null) await initialize();

    // Normalize the search query
    final normalizedQuery = TextProcessor.normalizeArabic(query);
    final stemmedQuery = TextProcessor.lightStemArabic(normalizedQuery);

    // Build FTS5 query
    String ftsQuery;
    if (exactMatch) {
      // Exact match: search in raw_content
      ftsQuery = '"$query"';
    } else {
      // Fuzzy match: search in normalized content
      // FTS5 supports phrase search and prefix matching
      final terms = stemmedQuery.split(' ').where((t) => t.length > 1).toList();
      if (terms.isEmpty) return [];
      
      // Use OR for multiple terms, AND for phrase matching
      ftsQuery = terms.map((t) => '$t*').join(' OR ');
    }

    // Build WHERE clause with JOIN to books_metadata for author/section filtering
    // IMPORTANT: We use book_path for JOIN (unique identifier) not book_name (may have duplicates)
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Book filter
    if (bookPaths != null && bookPaths.isNotEmpty) {
      final placeholders = List.filled(bookPaths.length, '?').join(',');
      whereClauses.add('books_fts.book_path IN ($placeholders)');
      whereArgs.addAll(bookPaths);
    }

    // Section type filter (for text sections like main, footnote, etc.)
    if (sectionTypes != null && sectionTypes.isNotEmpty) {
      final placeholders = List.filled(sectionTypes.length, '?').join(',');
      whereClauses.add('books_fts.section_type IN ($placeholders)');
      whereArgs.addAll(sectionTypes);
    }

    // Author and Section filters require JOIN with books_metadata
    // JOIN uses book_path (unique) to avoid issues with duplicate book names
    bool needsJoin = (authorId != null && authorId.isNotEmpty) || 
                     (sectionId != null && sectionId.isNotEmpty);

    if (needsJoin) {
      if (authorId != null && authorId.isNotEmpty) {
        whereClauses.add('books_metadata.author_id = ?');
        whereArgs.add(authorId);
      }

      if (sectionId != null && sectionId.isNotEmpty) {
        whereClauses.add('books_metadata.section_id = ?');
        whereArgs.add(sectionId);
      }
    }

    final whereClause = whereClauses.isNotEmpty 
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Build JOIN clause if needed
    // JOIN uses book_path (unique identifier) to correctly link search results with metadata
    // This ensures correct filtering even when multiple books have the same name
    final joinClause = needsJoin 
        ? 'INNER JOIN books_metadata ON books_fts.book_path = books_metadata.book_path'
        : '';

    // Execute search with ranking
    final sql = '''
      SELECT 
        books_fts.id,
        books_fts.book_path,
        books_fts.book_name,
        books_fts.page_number,
        books_fts.section_type,
        books_fts.content,
        books_fts.raw_content,
        bm25(books_fts) as rank
      FROM books_fts
      $joinClause
      $whereClause
      AND books_fts MATCH ?
      ORDER BY rank DESC, books_fts.page_number ASC
      LIMIT ? OFFSET ?
    ''';

    final results = await _database!.rawQuery(
      sql,
      [...whereArgs, ftsQuery, limit, offset],
    );

    // Get total count
    final countSql = '''
      SELECT COUNT(*) as total
      FROM books_fts
      $joinClause
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

  /// Delete a book from the index
  Future<void> deleteBook(String bookPath) async {
    if (_database == null) await initialize();

    await _database!.delete('books_fts', where: 'book_path = ?', whereArgs: [bookPath]);
    await _database!.delete('books_metadata', where: 'book_path = ?', whereArgs: [bookPath]);
  }

  /// Get search statistics
  Future<Map<String, dynamic>> getStats() async {
    if (_database == null) await initialize();

    final bookCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(DISTINCT book_path) FROM books_fts')
    ) ?? 0;

    final paragraphCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM books_fts')
    ) ?? 0;

    return {
      'total_books': bookCount,
      'total_paragraphs': paragraphCount,
    };
  }

  /// Close the database
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}

