// lib/storage/book_card_storage.dart
import 'dart:async';
import 'package:collection/collection.dart';
import '../Models/BookCard.dart';
import 'StorageHelper.dart';

const BOOK_CARD_KEY = "book_card_key";

class BookCardStorage {
  // 1. إنشاء نسخة ثابتة (Static) من الكلاس
  static final BookCardStorage _instance = BookCardStorage._internal();

  // 2. المصنع (Factory) لإرجاع نفس النسخة دائماً
  factory BookCardStorage() {
    return _instance;
  }

  // 3. منشئ خاص لمنع إنشاء نسخ أخرى
  BookCardStorage._internal();

  // حفظ قائمة بطاقات
  Future<void> saveBookCardList(List<BookCard> list) async {
    List<Map<String, dynamic>> maps = list.map((e) => e.toJson()).toList();
    await StorageHelper.saveListOfMaps(BOOK_CARD_KEY, maps);
  }

  // استرجاع قائمة بطاقات
  List<BookCard> getBookCardList() {
    List<Map<String, dynamic>>? maps = StorageHelper.getListOfMaps(BOOK_CARD_KEY);
    if (maps == null) return [];
    return maps.map((e) => BookCard.fromJson(e)).toList();
  }

  // إضافة بطاقة جديدة
  Future<void> addBookCard(BookCard bookCard) async {
    List<BookCard> list = getBookCardList();
    list.add(bookCard);
    await saveBookCardList(list);
  }

  // حذف بطاقة
  Future<void> removeBookCard(BookCard bookCard) async {
    List<BookCard> list = getBookCardList();
    list.removeWhere((card) => card.id == bookCard.id);
    await saveBookCardList(list);
  }

  // تعديل بطاقة الكتاب
  Future<void> editBookCard(BookCard updatedBookCard) async {
    List<BookCard> list = getBookCardList();
    final index = list.indexWhere((card) => card.id == updatedBookCard.id);

    if (index != -1) {
      list[index] = updatedBookCard;
    } else {
      list.add(updatedBookCard);
      print("BookCard with ID ${updatedBookCard.id} not found for editing. A new card was added.");
    }
    await saveBookCardList(list);
  }

  // الحصول على بطاقة كتاب واحدة بناءً على الـ ID
  BookCard? getBookCardById(String id) {
    List<BookCard> list = getBookCardList();
    return list.firstWhereOrNull((e) => e.id == id);
  }
 BookCard getBookCardByTitle(String title) {
    List<BookCard> list = getBookCardList();
    return list.firstWhereOrNull((e) => e.title == title)??BookCard(title: title);
  }

  // مسح البيانات
  Future<void> clear() async {
    await StorageHelper.removeKey(BOOK_CARD_KEY);
  }
}