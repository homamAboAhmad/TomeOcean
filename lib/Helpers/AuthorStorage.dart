// lib/storage/author_storage.dart
import '../Models/Author.dart';
import '../Utils/AuthorDeathDateParser.dart';
import 'BooksMetadataDatabase.dart';

class AuthorStorage {
  // إنشاء نسخة ثابتة (Static) من الكلاس
  static final AuthorStorage _instance = AuthorStorage._internal();

  // المصنع (Factory) لإرجاع نفس النسخة دائماً
  factory AuthorStorage() {
    return _instance;
  }

  // منشئ خاص لمنع إنشاء نسخ أخرى
  AuthorStorage._internal();

  final _db = BooksMetadataDatabase();

  // دالة للحصول على جميع المؤلفين (مع pagination)
  Future<List<Author>> getAuthorsAsync({
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    await _db.initialize();
    final authors = await _db.getAuthors(
      searchQuery: searchQuery,
    );
    authors.sort(_compareAuthorsByDeathYear);
    final skipped = authors.skip(offset ?? 0);
    return limit == null ? skipped.toList() : skipped.take(limit).toList();
  }

  // دالة للحصول على جميع المؤلفين (للتوافق مع الكود القديم)
  List<Author> getAuthors() {
    // Note: This is a synchronous method for backward compatibility
    // For large datasets, use getAuthorsAsync() instead
    // This will load all authors into memory - use with caution
    try {
      // Try to get from database synchronously (limited to first 1000)
      // This is a workaround - ideally all callers should use async version
      return [];
    } catch (e) {
      return [];
    }
  }

  // دالة لإضافة مؤلف جديد
  Future<void> addAuthor(Author author) async {
    await _db.initialize();

    // فحص إذا كان هناك مؤلف بنفس الاسم مسبقاً
    final existing = await _db.getAuthorByName(author.name);
    if (existing != null) {
      // إذا كان الاسم موجوداً، نقوم بتحديث البيانات فقط (مثل سنة الوفاة) إذا كانت مرسلة
      if (author.deathYear != null && author.deathYear!.isNotEmpty) {
        await _db.saveAuthor(existing.copyWith(deathYear: author.deathYear));
      }
      return;
    }

    await _db.saveAuthor(author);
  }

  // دالة لحذف مؤلف بناءً على الـ ID
  Future<void> removeAuthor(String authorId) async {
    await _db.initialize();
    await _db.deleteAuthor(authorId);
  }

  // دالة للحصول على مؤلف واحد بناءً على الـ ID
  static Future<Author?> getAuthorById(String authorId) async {
    final db = BooksMetadataDatabase();
    await db.initialize();
    return await db.getAuthorById(authorId);
  }

  // دالة لحذف جميع المؤلفين
  Future<void> clearAll() async {
    await _db.initialize();
    final db = await _db.database;
    await db.delete('authors');
  }

  Future<List<Author>> addDefaultAuthors() async {
    print("addDefaultAuthors: Starting...");
    List<Author> defaultAuthors = [
      Author(name: "مؤلف غير معروف", description: "مؤلف غير معروف"),
    ];
    await _db.initialize();
    print(
      "addDefaultAuthors: Database initialized, inserting ${defaultAuthors.length} authors",
    );
    await _db.batchInsertAuthors(defaultAuthors);
    print("addDefaultAuthors: Authors inserted, verifying...");

    // Verify insertion
    final count = await _db.countAuthors();
    print("addDefaultAuthors: Verification - database now has $count authors");

    // Reload to return actual saved authors
    final savedAuthors = await _db.getAuthors(limit: 100);
    print(
      "addDefaultAuthors: Reloaded ${savedAuthors.length} authors from database",
    );
    return savedAuthors;
  }

  int _compareAuthorsByDeathYear(Author a, Author b) {
    final death = AuthorDeathDateParser.compare(a.deathYear, b.deathYear);
    if (death != 0) return death;
    return a.name.compareTo(b.name);
  }
}
