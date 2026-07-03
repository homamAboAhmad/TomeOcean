import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:path/path.dart' as p;

class IndexedBookTitleResolver {
  const IndexedBookTitleResolver._();

  static String resolve(Map<String, dynamic> book) {
    final storedTitle = _firstNonEmpty([
      book['book_name'],
      book['title'],
      book['bookName'],
    ]);
    if (storedTitle != null) return storedTitle;

    final bookPath = book['book_path'] as String;
    final pathTitle = AppStoragePaths.displayTitleFromPath(bookPath);
    if (pathTitle.toLowerCase() != 'source') return pathTitle;

    final parentTitle = p.basename(p.dirname(bookPath)).trim();
    return parentTitle.isEmpty ? pathTitle : parentTitle;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
