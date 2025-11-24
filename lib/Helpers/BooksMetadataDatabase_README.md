# BooksMetadataDatabase - دليل الاستخدام

## تحذير مهم: استخدام book_path بدلاً من book_name

### المشكلة
عند وجود عشرات آلاف الكتب، قد يكون هناك **تكرار في أسماء الكتب**. على سبيل المثال:
- "صحيح البخاري" قد يكون موجوداً في نسخ متعددة
- "تفسير القرآن" قد يكون لعدة مفسرين
- "كتاب الفقه" قد يكون لعدة مؤلفين

### الحل
**استخدم دائماً `book_path` للربط الفريد** بدلاً من `book_name`:

```dart
// ✅ صحيح - استخدام book_path (فريد)
final bookCard = await metadataDb.getBookByPath(bookPath);

// ❌ خطأ - استخدام book_name (قد يكون مكرر)
final bookCard = await metadataDb.getBookByName(bookName);
```

### الدوال المتاحة

#### 1. `getBookByPath(String bookPath)` - **مُوصى به**
- يعيد `BookCard?` واحد فقط
- `book_path` فريد لكل كتاب
- استخدام آمن مع آلاف الكتب

#### 2. `getBookByName(String bookName)` - **استخدم بحذر**
- يعيد أول كتاب فقط بنفس الاسم
- قد يكون هناك كتب أخرى بنفس الاسم
- استخدم فقط إذا كنت متأكداً من عدم وجود تكرار

#### 3. `getBooksByName(String bookName)` - **للتعامل مع التكرار**
- يعيد قائمة بجميع الكتب بنفس الاسم
- مفيد للتحقق من وجود تكرار
- استخدم عند الحاجة لعرض جميع النسخ

### مثال من نتائج البحث

```dart
// نتائج البحث تحتوي على bookPath و bookName
final result = ArabicSearchHit(
  bookPath: 'C:/books/sahih_bukhari_v1.docx',  // فريد
  bookName: 'صحيح البخاري',                      // قد يتكرر
);

// ✅ استخدم bookPath للربط
final bookCard = await metadataDb.getBookByPath(result.bookPath);

// ❌ لا تستخدم bookName
// final bookCard = await metadataDb.getBookByName(result.bookName);
```

### في arabic_search_dialog

الفلترة تتم على مستوى قاعدة البيانات باستخدام `book_path` من نتائج البحث، لذا لا توجد مشكلة في التكرار.

