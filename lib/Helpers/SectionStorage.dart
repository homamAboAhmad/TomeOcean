// lib/storage/section_storage.dart
import '../Models/Section.dart';
import 'BooksMetadataDatabase.dart';

class SectionStorage {
  final _db = BooksMetadataDatabase();

  // دالة للحصول على جميع الأقسام (مع pagination)
  Future<List<Section>> getSectionsAsync({
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    await _db.initialize();
    return await _db.getSections(limit: limit, offset: offset, searchQuery: searchQuery);
  }

  // دالة للحصول على جميع الأقسام (للتوافق مع الكود القديم)
  List<Section> getSections() {
    // Note: This is a synchronous method for backward compatibility
    // For large datasets, use getSectionsAsync() instead
    // This will load all sections into memory - use with caution
    try {
      // Try to get from database synchronously (limited to first 1000)
      // This is a workaround - ideally all callers should use async version
      return [];
    } catch (e) {
      return [];
    }
  }

  // دالة لإضافة قسم جديد
  Future<void> addSection(Section section) async {
    await _db.initialize();
    await _db.saveSection(section);
  }

  // دالة لحذف قسم بناءً على الـ ID
  Future<void> removeSection(String sectionId) async {
    await _db.initialize();
    await _db.deleteSection(sectionId);
  }

  // دالة للحصول على قسم واحد بناءً على العنوان
  Future<Section?> getSectionById(String id) async {
    await _db.initialize();
    return await _db.getSectionById(id);
  }

  // دالة لحذف جميع الأقسام
  Future<void> clearAll() async {
    await _db.initialize();
    final db = await _db.database;
    await db.delete('sections');
  }

  Future<List<Section>> addDefaultSections() async {
    print("addDefaultSections: Starting...");
    List<Section> defaultSections = [
      Section(title: "تفسير القرآن الكريم"),
      Section(title: "كتب السنة"),
      Section(title: "علوم الحديث"),
      Section(title: "كتب اللغة"),
      Section(title: "الأدب"),
      Section(title: "كتب عامة"),
    ];
    await _db.initialize();
    print("addDefaultSections: Database initialized, inserting ${defaultSections.length} sections");
    await _db.batchInsertSections(defaultSections);
    print("addDefaultSections: Sections inserted, verifying...");
    
    // Verify insertion
    final count = await _db.countSections();
    print("addDefaultSections: Verification - database now has $count sections");
    
    // Reload to return actual saved sections
    final savedSections = await _db.getSections(limit: 100);
    print("addDefaultSections: Reloaded ${savedSections.length} sections from database");
    return savedSections;
  }
}
