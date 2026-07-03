import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';

class LibraryFullBookSearch {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();

  Future<Set<String>> findPaths(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return {};
    await _db.initialize();
    final db = await _db.database;
    final pattern = '%$trimmed%';
    final rows = await db.rawQuery('''
      SELECT b.book_path
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      WHERE b.book_name LIKE ?
         OR a.name LIKE ?
         OR a.death_year LIKE ?
         OR s.title LIKE ?
         OR b.book_type LIKE ?
         OR CASE b.book_type
              WHEN 'book' THEN 'كتاب'
              WHEN 'magazine' THEN 'مجلة'
              WHEN 'manuscript' THEN 'مخطوط'
              WHEN 'thesis' THEN 'رسالة جامعية'
              WHEN 'electronic' THEN 'إلكترونية'
              WHEN 'transcription' THEN 'تفريغات'
              ELSE 'غير محدد'
            END LIKE ?
         OR CASE
              WHEN b.matches_printed = 1 THEN 'موافق للمطبوع'
              ELSE 'غير موافق للمطبوع'
            END LIKE ?
         OR b.description LIKE ?
         OR b.publisher LIKE ?
         OR b.edition LIKE ?
         OR b.page_count LIKE ?
    ''', List.filled(11, pattern));
    return rows.map((row) => row['book_path'] as String).toSet();
  }
}
