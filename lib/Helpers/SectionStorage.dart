// lib/storage/section_storage.dart
import 'package:golden_shamela/wordToHTML/DocumentDefaults.dart';

import '../Models/Section.dart';
import 'StorageHelper.dart';

const SECTIONS_KEY = "sections_key";

class SectionStorage {
  // دالة للحصول على جميع الأقسام
  List<Section> getSections() {
    List<Map<String, dynamic>>? maps =
        StorageHelper.getListOfMaps(SECTIONS_KEY);
    if (maps == null) {
      return addDefaultSections();
    }
    return maps.map((e) => Section.fromJson(e)).toList();
  }

  // دالة لحفظ قائمة الأقسام
  Future<void> _saveSections(List<Section> sections) async {
    List<Map<String, dynamic>> maps = sections.map((e) => e.toJson()).toList();
    await StorageHelper.saveListOfMaps(SECTIONS_KEY, maps);
  }

  // دالة لإضافة قسم جديد
  Future<void> addSection(Section section) async {
    List<Section> list = getSections();
    list.add(section);
    await _saveSections(list);
  }

  // دالة لحذف قسم بناءً على الـ ID
  Future<void> removeSection(String sectionId) async {
    List<Section> list = getSections();
    list.removeWhere((section) => section.id == sectionId);
    await _saveSections(list);
  }

  // دالة للحصول على قسم واحد بناءً على العنوان
  Section? getSectionById(String id) {
    List<Section> list = getSections();
    return list.firstWhere((section) => section.id == id);
  }

  // دالة لحذف جميع الأقسام
  Future<void> clearAll() async {
    await StorageHelper.removeKey(SECTIONS_KEY);
  }

  List<Section> addDefaultSections() {
    print("addDefaultSections");
    List<Section> sections = [
      Section(title: "تفسير القرآن الكريم"),
      Section(title: "كتب السنة"),
      Section(title: "علوم الحديث"),
      Section(title: "كتب اللغة"),
      Section(title: "الأدب"),
      Section(title: "كتب عامة"),
    ];
    _saveSections(sections);
    return sections;
  }
}
