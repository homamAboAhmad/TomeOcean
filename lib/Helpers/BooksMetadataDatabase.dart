import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../Models/BookCard.dart';
import '../Models/Author.dart';
import '../Models/Section.dart';
import 'StorageHelper.dart';

/// High-performance SQLite database for books metadata
/// Optimized for large-scale projects with thousands of books, authors, and sections
class BooksMetadataDatabase {
  static final BooksMetadataDatabase _instance =
      BooksMetadataDatabase._internal();
  factory BooksMetadataDatabase() => _instance;
  BooksMetadataDatabase._internal();

  Database? _database;
  bool _isInitialized = false;
  static const int _version = 2;

  /// Initialize the database
  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocDir.path, 'tome_ocean', 'books_metadata.db');
      await Directory(p.dirname(dbPath)).create(recursive: true);

      _database = await openDatabase(
        dbPath,
        version: _version,
        singleInstance: false,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _migrateDatabase(db, oldVersion, newVersion);
        },
      );

      // Ensure tables exist even if database was created before
      await _ensureTablesExist(_database!);

      // Run migrations for existing databases
      await _migrateDatabase(_database!, 1, _version);

      _isInitialized = true;
      print("BooksMetadataDatabase: Database initialized successfully");
    } catch (e) {
      print("BooksMetadataDatabase: Error initializing database: $e");
      rethrow;
    }
  }

  /// Get database instance (initialize if needed)
  Future<Database> get database async {
    if (_database == null) await initialize();
    // Only check tables if not already verified
    if (!_isInitialized) {
      await _ensureTablesExist(_database!);
    }
    return _database!;
  }

  /// Create all tables
  Future<void> _createTables(Database db) async {
    // Create authors table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS authors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        death_year TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    // Create sections table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sections (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    // Create books table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        book_path TEXT NOT NULL,
        book_name TEXT NOT NULL,
        author_id TEXT,
        section_id TEXT,
        description TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE SET NULL,
        FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE SET NULL
      );
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_books_path ON books(book_path);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_books_name ON books(book_name);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_books_author ON books(author_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_books_section ON books(section_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_books_author_section ON books(author_id, section_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_authors_name ON authors(name);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sections_title ON sections(title);
    ''');

    // Unique constraint on book_path
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_books_path_unique ON books(book_path);
    ''');
  }

  /// Ensure all tables exist (check and create if missing)
  Future<void> _ensureTablesExist(Database db) async {
    try {
      // Check each table individually to avoid IN clause issues with sqflite_common_ffi
      final requiredTables = ['authors', 'sections', 'books'];
      final existingTables = <String>{};

      for (final tableName in requiredTables) {
        try {
          final result = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
            [tableName],
          );
          if (result.isNotEmpty) {
            existingTables.add(tableName);
          }
        } catch (e) {
          // If query fails, assume table doesn't exist
          print("BooksMetadataDatabase: Error checking table $tableName: $e");
        }
      }

      final missingTables = requiredTables
          .where((t) => !existingTables.contains(t))
          .toList();

      if (missingTables.isNotEmpty) {
        print(
          "BooksMetadataDatabase: Missing tables: $missingTables, creating them...",
        );
        await _createTables(db);
        print("BooksMetadataDatabase: Tables created successfully");
      } else {
        print("BooksMetadataDatabase: All required tables exist");
      }
    } catch (e, stackTrace) {
      print("BooksMetadataDatabase: Error ensuring tables exist: $e");
      print("Stack trace: $stackTrace");
      // Try to create tables anyway (CREATE TABLE IF NOT EXISTS is safe)
      try {
        await _createTables(db);
        print("BooksMetadataDatabase: Tables created after error");
      } catch (e2) {
        // If tables already exist, this is fine
        if (!e2.toString().contains('already exists') &&
            !e2.toString().contains('duplicate') &&
            !e2.toString().contains('bad parameter')) {
          print("BooksMetadataDatabase: Failed to create tables: $e2");
        } else {
          print(
            "BooksMetadataDatabase: Tables may already exist, ignoring error",
          );
        }
      }
    }
  }

  /// Migrate database schema
  Future<void> _migrateDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Migration to version 2: Add death_year column to authors table
      try {
        // Check if column already exists
        final tableInfo = await db.rawQuery("PRAGMA table_info(authors)");
        final hasDeathYear = tableInfo.any(
          (column) => column['name'] == 'death_year',
        );

        if (!hasDeathYear) {
          print(
            "BooksMetadataDatabase: Migrating to version 2 - adding death_year column",
          );
          await db.execute('ALTER TABLE authors ADD COLUMN death_year TEXT');
          print("BooksMetadataDatabase: Migration to version 2 completed");
        } else {
          print(
            "BooksMetadataDatabase: death_year column already exists, skipping migration",
          );
        }
      } catch (e) {
        print("BooksMetadataDatabase: Error during migration to version 2: $e");
        // Continue even if migration fails (column might already exist)
      }
    }
  }

  // ==================== Authors ====================

  /// Get all authors with pagination
  Future<List<Author>> getAuthors({
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM authors';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' WHERE name LIKE ?';
      args.add('%$searchQuery%');
    }

    query += ' ORDER BY name ASC';

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }

    final results = await db.rawQuery(query, args);
    return results
        .map(
          (row) => Author(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String? ?? '',
            deathYear: row['death_year'] as String?,
          ),
        )
        .toList();
  }

  /// Get author by ID
  Future<Author?> getAuthorById(String id) async {
    final db = await database;
    final results = await db.query(
      'authors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return Author(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      deathYear: row['death_year'] as String?,
    );
  }

  /// Get author by Name
  Future<Author?> getAuthorByName(String name) async {
    final db = await database;
    final results = await db.query(
      'authors',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return Author(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      deathYear: row['death_year'] as String?,
    );
  }

  /// Add or update author
  Future<void> saveAuthor(Author author) async {
    final db = await database;
    await db.insert('authors', {
      'id': author.id,
      'name': author.name,
      'description': author.description,
      'death_year': author.deathYear,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Batch insert authors
  Future<void> batchInsertAuthors(List<Author> authors) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final author in authors) {
      batch.insert('authors', {
        'id': author.id,
        'name': author.name,
        'description': author.description,
        'death_year': author.deathYear,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Delete author
  Future<void> deleteAuthor(String id) async {
    final db = await database;
    await db.delete('authors', where: 'id = ?', whereArgs: [id]);
  }

  /// Count authors
  Future<int> countAuthors({String? searchQuery}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM authors';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' WHERE name LIKE ?';
      args.add('%$searchQuery%');
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== Sections ====================

  /// Get all sections with pagination
  Future<List<Section>> getSections({
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM sections';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' WHERE title LIKE ?';
      args.add('%$searchQuery%');
    }

    query += ' ORDER BY title ASC';

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }

    final results = await db.rawQuery(query, args);
    return results
        .map(
          (row) =>
              Section(id: row['id'] as String, title: row['title'] as String),
        )
        .toList();
  }

  /// Get section by ID
  Future<Section?> getSectionById(String id) async {
    final db = await database;
    final results = await db.query(
      'sections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return Section(id: row['id'] as String, title: row['title'] as String);
  }

  /// Add or update section
  Future<void> saveSection(Section section) async {
    final db = await database;
    await db.insert('sections', {
      'id': section.id,
      'title': section.title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Batch insert sections
  Future<void> batchInsertSections(List<Section> sections) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final section in sections) {
      batch.insert('sections', {
        'id': section.id,
        'title': section.title,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Delete section
  Future<void> deleteSection(String id) async {
    final db = await database;
    await db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  /// Count sections
  Future<int> countSections({String? searchQuery}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM sections';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' WHERE title LIKE ?';
      args.add('%$searchQuery%');
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== Books ====================

  /// Get book by ID
  Future<BookCard?> getBookById(String id) async {
    final db = await database;
    final results = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return BookCard(
      id: row['id'] as String,
      title: row['book_name'] as String,
      authorId: row['author_id'] as String? ?? '',
      sectionId: row['section_id'] as String? ?? '',
      description: row['description'] as String? ?? '',
    );
  }

  /// Get book by book_path
  Future<BookCard?> getBookByPath(String bookPath) async {
    final db = await database;
    final results = await db.query(
      'books',
      where: 'book_path = ?',
      whereArgs: [bookPath],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return BookCard(
      id: row['id'] as String,
      title: row['book_name'] as String,
      authorId: row['author_id'] as String? ?? '',
      sectionId: row['section_id'] as String? ?? '',
      description: row['description'] as String? ?? '',
    );
  }

  /// Get book by book_name (title)
  /// WARNING: Multiple books may have the same name. Use getBookByPath() for unique lookup.
  /// This method returns only the first match.
  Future<BookCard?> getBookByName(String bookName) async {
    try {
      final db = await database;

      // Use rawQuery to avoid parameter binding issues
      final results = await db.rawQuery(
        'SELECT * FROM books WHERE book_name = ? LIMIT 1',
        [bookName],
      );

      if (results.isEmpty) return null;
      final row = results.first;
      return BookCard(
        id: row['id'] as String,
        title: row['book_name'] as String,
        authorId: row['author_id'] as String? ?? '',
        sectionId: row['section_id'] as String? ?? '',
        description: row['description'] as String? ?? '',
      );
    } catch (e, stackTrace) {
      print("BooksMetadataDatabase: Error in getBookByName: $e");
      print("Stack trace: $stackTrace");
      print("Book name: $bookName");
      return null;
    }
  }

  /// Get all books with the same name (for handling duplicates)
  Future<List<BookCard>> getBooksByName(String bookName) async {
    final db = await database;
    final results = await db.query(
      'books',
      where: 'book_name = ?',
      whereArgs: [bookName],
      orderBy: 'book_path ASC',
    );
    return results
        .map(
          (row) => BookCard(
            id: row['id'] as String,
            title: row['book_name'] as String,
            authorId: row['author_id'] as String? ?? '',
            sectionId: row['section_id'] as String? ?? '',
            description: row['description'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Get all books with pagination and filters
  Future<List<BookCard>> getBooks({
    int? limit,
    int? offset,
    String? authorId,
    String? sectionId,
    String? searchQuery,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM books WHERE 1=1';
    List<dynamic> args = [];

    if (authorId != null && authorId.isNotEmpty) {
      query += ' AND author_id = ?';
      args.add(authorId);
    }

    if (sectionId != null && sectionId.isNotEmpty) {
      query += ' AND section_id = ?';
      args.add(sectionId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' AND book_name LIKE ?';
      args.add('%$searchQuery%');
    }

    query += ' ORDER BY book_name ASC';

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }

    final results = await db.rawQuery(query, args);
    return results
        .map(
          (row) => BookCard(
            id: row['id'] as String,
            title: row['book_name'] as String,
            authorId: row['author_id'] as String? ?? '',
            sectionId: row['section_id'] as String? ?? '',
            description: row['description'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Get book paths filtered by author and/or section
  Future<List<String>> getBookPaths({
    String? authorId,
    String? sectionId,
  }) async {
    print("===== [BooksMetadataDatabase.getBookPaths] ===== Called");
    print("  authorId: $authorId (type: ${authorId.runtimeType})");
    print("  sectionId: $sectionId (type: ${sectionId.runtimeType})");

    final db = await database;
    String query = 'SELECT book_path FROM books WHERE 1=1';
    List<dynamic> args = [];

    if (authorId != null && authorId.toString().trim().isNotEmpty) {
      final authorIdStr = authorId.toString().trim();
      query += ' AND author_id = ?';
      args.add(authorIdStr);
      print(
        "===== [BooksMetadataDatabase.getBookPaths] ===== Added author_id filter: $authorIdStr",
      );
    }

    if (sectionId != null && sectionId.toString().trim().isNotEmpty) {
      final sectionIdStr = sectionId.toString().trim();
      query += ' AND section_id = ?';
      args.add(sectionIdStr);
      print(
        "===== [BooksMetadataDatabase.getBookPaths] ===== Added section_id filter: $sectionIdStr",
      );
    }

    print("===== [BooksMetadataDatabase.getBookPaths] ===== Query: $query");
    print("===== [BooksMetadataDatabase.getBookPaths] ===== Args: $args");

    try {
      final results = await db.rawQuery(query, args);
      print(
        "===== [BooksMetadataDatabase.getBookPaths] ===== Found ${results.length} results",
      );
      return results.map((row) => row['book_path'] as String).toList();
    } catch (e, stackTrace) {
      print("===== [BooksMetadataDatabase.getBookPaths] ===== ERROR: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  /// Add or update book
  Future<void> saveBook(BookCard book, String bookPath) async {
    final db = await database;
    await db.insert('books', {
      'id': book.id,
      'book_path': bookPath,
      'book_name': book.title,
      'author_id': book.authorId.isNotEmpty ? book.authorId : null,
      'section_id': book.sectionId.isNotEmpty ? book.sectionId : null,
      'description': book.description,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Batch insert books
  Future<void> batchInsertBooks(List<Map<String, dynamic>> books) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final bookData in books) {
      final book = bookData['book'] as BookCard;
      final bookPath = bookData['book_path'] as String;

      batch.insert('books', {
        'id': book.id,
        'book_path': bookPath,
        'book_name': book.title,
        'author_id': book.authorId.isNotEmpty ? book.authorId : null,
        'section_id': book.sectionId.isNotEmpty ? book.sectionId : null,
        'description': book.description,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Delete book
  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete book by path
  Future<void> deleteBookByPath(String bookPath) async {
    final db = await database;
    await db.delete('books', where: 'book_path = ?', whereArgs: [bookPath]);
  }

  /// Count books
  Future<int> countBooks({
    String? authorId,
    String? sectionId,
    String? searchQuery,
  }) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM books WHERE 1=1';
    List<dynamic> args = [];

    if (authorId != null && authorId.isNotEmpty) {
      query += ' AND author_id = ?';
      args.add(authorId);
    }

    if (sectionId != null && sectionId.isNotEmpty) {
      query += ' AND section_id = ?';
      args.add(sectionId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' AND book_name LIKE ?';
      args.add('%$searchQuery%');
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get author_id and section_id for a book_path (for search engine)
  Future<Map<String, String?>> getBookMetadata(String bookPath) async {
    final db = await database;
    final results = await db.query(
      'books',
      columns: ['author_id', 'section_id'],
      where: 'book_path = ?',
      whereArgs: [bookPath],
      limit: 1,
    );
    if (results.isEmpty) {
      return {'author_id': null, 'section_id': null};
    }
    final row = results.first;
    return {
      'author_id': row['author_id'] as String?,
      'section_id': row['section_id'] as String?,
    };
  }

  /// Get a map of all book paths to their author IDs
  Future<Map<String, String>> getAllBookAuthorMappings() async {
    final db = await database;
    final results = await db.query(
      'books',
      columns: ['book_path', 'author_id'],
      where: 'author_id IS NOT NULL',
    );

    final Map<String, String> mapping = {};
    for (final row in results) {
      final path = row['book_path'] as String?;
      final authorId = row['author_id'] as String?;
      if (path != null && authorId != null) {
        mapping[path] = authorId;
      }
    }
    return mapping;
  }

  /// Migrate data from SharedPreferences to SQLite
  /// This should be called once on first app launch after update
  Future<bool> migrateFromSharedPreferences() async {
    try {
      await initialize();
      final db = await database;

      // Check if migration already done
      final migrationCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_status'",
      );

      bool migrationCompleted = false;

      if (migrationCheck.isNotEmpty) {
        final status = await db.query(
          'migration_status',
          where: 'migration_key = ?',
          whereArgs: ['shared_prefs_to_sqlite'],
        );
        if (status.isNotEmpty && (status.first['completed'] as int) == 1) {
          print("BooksMetadataDatabase: Migration already completed");
          migrationCompleted = true;
        }
      } else {
        // Create migration status table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS migration_status (
            migration_key TEXT PRIMARY KEY,
            completed INTEGER NOT NULL DEFAULT 0,
            migrated_at INTEGER
          );
        ''');
      }

      if (!migrationCompleted) {
        print(
          "BooksMetadataDatabase: Starting migration from SharedPreferences...",
        );

        // Migrate Authors
        const AUTHORS_KEY = "authors_key";
        final authorsData = StorageHelper.getListOfMaps(AUTHORS_KEY);
        if (authorsData != null && authorsData.isNotEmpty) {
          final authors = authorsData
              .map((json) => Author.fromJson(json))
              .toList();
          await batchInsertAuthors(authors);
          print("BooksMetadataDatabase: Migrated ${authors.length} authors");
        }

        // Migrate Sections
        const SECTIONS_KEY = "sections_key";
        final sectionsData = StorageHelper.getListOfMaps(SECTIONS_KEY);
        if (sectionsData != null && sectionsData.isNotEmpty) {
          final sections = sectionsData
              .map((json) => Section.fromJson(json))
              .toList();
          await batchInsertSections(sections);
          print("BooksMetadataDatabase: Migrated ${sections.length} sections");
        }

        // Migrate Books
        const BOOK_CARD_KEY = "book_card_key";
        final booksData = StorageHelper.getListOfMaps(BOOK_CARD_KEY);
        if (booksData != null && booksData.isNotEmpty) {
          final books = booksData
              .map((json) => BookCard.fromJson(json))
              .toList();

          // Try to get book_path from ArabicSearchEngine metadata
          final bookPaths = await _getBookPathsFromSearchEngine(books);

          final booksWithPaths = <Map<String, dynamic>>[];
          for (int i = 0; i < books.length; i++) {
            final book = books[i];
            // Try to find book_path by matching book_name
            String? bookPath = bookPaths[book.title];
            if (bookPath == null) {
              // If not found, create a placeholder path (will be updated when book is indexed)
              bookPath = '${book.title}.docx';
            }
            booksWithPaths.add({'book': book, 'book_path': bookPath});
          }

          await batchInsertBooks(booksWithPaths);
          print("BooksMetadataDatabase: Migrated ${books.length} books");
        }

        // Mark migration as completed
        await db.insert('migration_status', {
          'migration_key': 'shared_prefs_to_sqlite',
          'completed': 1,
          'migrated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        print("BooksMetadataDatabase: Migration completed and marked");
      }

      // Always check and create default data if needed (even if migration was already done)
      print("BooksMetadataDatabase: Ensuring default data exists...");

      // Check if we have any authors, if not, create defaults
      final authorCount = await countAuthors();
      print("BooksMetadataDatabase: Author count: $authorCount");
      if (authorCount == 0) {
        print(
          "BooksMetadataDatabase: No authors found, creating default authors...",
        );
        final defaultAuthors = [
          Author(name: "مؤلف غير معروف", description: "مؤلف غير معروف"),
        ];
        await batchInsertAuthors(defaultAuthors);
        final newCount = await countAuthors();
        print(
          "BooksMetadataDatabase: Created ${defaultAuthors.length} default authors, new count: $newCount",
        );
      }

      // Check if we have any sections, if not, create defaults
      final sectionCount = await countSections();
      print("BooksMetadataDatabase: Section count: $sectionCount");
      if (sectionCount == 0) {
        print(
          "BooksMetadataDatabase: No sections found, creating default sections...",
        );
        final defaultSections = [
          Section(title: "تفسير القرآن الكريم"),
          Section(title: "كتب السنة"),
          Section(title: "علوم الحديث"),
          Section(title: "كتب اللغة"),
          Section(title: "الأدب"),
          Section(title: "كتب عامة"),
        ];
        await batchInsertSections(defaultSections);
        final newCount = await countSections();
        print(
          "BooksMetadataDatabase: Created ${defaultSections.length} default sections, new count: $newCount",
        );
      }

      // Mark migration as completed
      await db.insert('migration_status', {
        'migration_key': 'shared_prefs_to_sqlite',
        'completed': 1,
        'migrated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print("BooksMetadataDatabase: Migration completed successfully");
      return true;
    } catch (e) {
      print("BooksMetadataDatabase: Migration error: $e");
      return false;
    }
  }

  /// Get book paths from search engine metadata
  Future<Map<String, String>> _getBookPathsFromSearchEngine(
    List<BookCard> books,
  ) async {
    try {
      // Try to access ArabicSearchEngine's books_metadata table
      final appDocDir = await getApplicationDocumentsDirectory();
      final searchDbPath = p.join(
        appDocDir.path,
        'tome_ocean',
        'arabic_search.db',
      );

      if (!await File(searchDbPath).exists()) {
        return {};
      }

      final searchDb = await openDatabase(searchDbPath, readOnly: true);
      final results = await searchDb.query(
        'books_metadata',
        columns: ['book_path', 'book_name'],
      );
      await searchDb.close();

      final Map<String, String> bookPaths = {};
      for (final row in results) {
        final bookName = row['book_name'] as String;
        final bookPath = row['book_path'] as String;
        bookPaths[bookName] = bookPath;
      }

      return bookPaths;
    } catch (e) {
      print(
        "BooksMetadataDatabase: Error getting book paths from search engine: $e",
      );
      return {};
    }
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
}
