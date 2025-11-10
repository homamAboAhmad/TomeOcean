// lib/storage/author_storage.dart
import '../Models/Author.dart';
import 'StorageHelper.dart';

const AUTHORS_KEY = "authors_key";

class AuthorStorage {
  // إنشاء نسخة ثابتة (Static) من الكلاس
  static final AuthorStorage _instance = AuthorStorage._internal();

  // المصنع (Factory) لإرجاع نفس النسخة دائماً
  factory AuthorStorage() {
    return _instance;
  }

  // منشئ خاص لمنع إنشاء نسخ أخرى
  AuthorStorage._internal();

  // دالة لحفظ قائمة المؤلفين
  Future<void> _saveAuthors(List<Author> authors) async {
    List<Map<String, dynamic>> maps = authors.map((e) => e.toJson()).toList();
    await StorageHelper.saveListOfMaps(AUTHORS_KEY, maps);
  }

  // دالة للحصول على جميع المؤلفين
  List<Author> getAuthors() {
    List<Map<String, dynamic>>? maps = StorageHelper.getListOfMaps(AUTHORS_KEY);
    if (maps == null) {
      return addDefaultAuthors();
    }    return maps.map((e) => Author.fromJson(e)).toList();
  }

  // دالة لإضافة مؤلف جديد
  Future<void> addAuthor(Author author) async {
    List<Author> list = getAuthors();
    list.add(author);
    await _saveAuthors(list);
  }

  // دالة لحذف مؤلف بناءً على الـ ID
  Future<void> removeAuthor(String authorId) async {
    List<Author> list = getAuthors();
    list.removeWhere((author) => author.id == authorId);
    await _saveAuthors(list);
  }

  // دالة للحصول على مؤلف واحد بناءً على الـ ID
 static Author? getAuthorById(String authorId) {
    List<Author> list = _instance.getAuthors();
    try {
      return list.firstWhere((author) => author.id == authorId);
    } catch (e) {
      return null;
    }
  }

  // دالة لحذف جميع المؤلفين
  Future<void> clearAll() async {
    await StorageHelper.removeKey(AUTHORS_KEY);
  }

  List<Author> addDefaultAuthors() {
    print("addDefaultAuthors");
    List<Author> tems = [
      Author(name: "Abcd",description: "sdsafsfsdfsfd"),
      Author(name: "aaaa",description: "sdsafsfsdfsfd"),
      Author(name: "test",description: "sdsafsfsdfsfd"),

    ];
    _saveAuthors(tems);
    return tems;
  }
}