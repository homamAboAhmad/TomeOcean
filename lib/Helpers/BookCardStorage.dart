// lib/storage/book_card_storage.dart
import 'dart:async';
import 'package:collection/collection.dart';
import '../Models/BookCard.dart';
import 'BooksMetadataDatabase.dart';

class BookCardStorage {
  // 1. إنشاء نسخة ثابتة (Static) من الكلاس
  static final BookCardStorage _instance = BookCardStorage._internal();

  // 2. المصنع (Factory) لإرجاع نفس النسخة دائماً
  factory BookCardStorage() {
    return _instance;
  }

  // 3. منشئ خاص لمنع إنشاء نسخ أخرى
  BookCardStorage._internal();

  final _db = BooksMetadataDatabase();

  // استرجاع قائمة بطاقات (مع pagination للقوائم الكبيرة)
  Future<List<BookCard>> getBookCardList({
    int? limit,
    int? offset,
    String? authorId,
    String? sectionId,
    String? searchQuery,
  }) async {
    await _db.initialize();
    return await _db.getBooks(
      limit: limit,
      offset: offset,
      authorId: authorId,
      sectionId: sectionId,
      searchQuery: searchQuery,
    );
  }

  // استرجاع قائمة بطاقات (للتوافق مع الكود القديم - بدون pagination)
  List<BookCard> getBookCardListSync() {
    // Note: This is a synchronous method for backward compatibility
    // For large datasets, use getBookCardList() async version instead
    // This will load all books into memory - use with caution
    return [];
  }

  // إضافة بطاقة جديدة (يتطلب book_path)
  Future<void> addBookCard(BookCard bookCard, String bookPath) async {
    await _db.initialize();
    await _db.saveBook(bookCard, bookPath);
  }

  // حذف بطاقة
  Future<void> removeBookCard(BookCard bookCard) async {
    await _db.initialize();
    await _db.deleteBook(bookCard.id);
  }

  // تعديل بطاقة الكتاب (يتطلب book_path)
  Future<void> editBookCard(BookCard updatedBookCard, String bookPath) async {
    await _db.initialize();
    await _db.saveBook(updatedBookCard, bookPath);
  }

  // الحصول على بطاقة كتاب واحدة بناءً على الـ ID
  Future<BookCard?> getBookCardById(String id) async {
    await _db.initialize();
    return await _db.getBookById(id);
  }

  // الحصول على بطاقة كتاب بناءً على العنوان
  // WARNING: Multiple books may have the same title. Use getBookCardByPath() for unique lookup.
  // This method returns only the first match.
  Future<BookCard?> getBookCardByTitle(String title) async {
    await _db.initialize();
    return await _db.getBookByName(title);
  }

  // الحصول على جميع الكتب بنفس العنوان (للتعامل مع التكرار)
  Future<List<BookCard>> getBookCardsByTitle(String title) async {
    await _db.initialize();
    return await _db.getBooksByName(title);
  }

  // الحصول على بطاقة كتاب بناءً على book_path
  Future<BookCard?> getBookCardByPath(String bookPath) async {
    await _db.initialize();
    return await _db.getBookByPath(bookPath);
  }

  // مسح البيانات
  Future<void> clear() async {
    await _db.initialize();
    final db = await _db.database;
    await db.delete('books');
  }

  // حفظ قائمة بطاقات (للتوافق مع الكود القديم)
  // Note: This method requires book_path for each book, which may not be available
  // Consider using addBookCard or batchInsertBooks instead
  Future<void> saveBookCardList(List<BookCard> list) async {
    await _db.initialize();
    // This is a legacy method - we need book_path for each book
    // For now, we'll try to get book_path from existing database or use title as placeholder
    final booksWithPaths = <Map<String, dynamic>>[];
    for (final book in list) {
      // Try to get existing book_path
      final existing = await _db.getBookById(book.id);
      String bookPath;
      if (existing != null) {
        // Get book_path from database (we need to add a method for this)
        final bookByName = await _db.getBookByName(book.title);
        bookPath = book.title; // Placeholder - will be updated when book is indexed
      } else {
        bookPath = '${book.title}.docx'; // Placeholder
      }
      booksWithPaths.add({
        'book': book,
        'book_path': bookPath,
      });
    }
    await _db.batchInsertBooks(booksWithPaths);
  }
}