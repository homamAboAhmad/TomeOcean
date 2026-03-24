import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/core/app_state.dart';

/// مسؤول عن تحميل الكتب المفهرسة في الخلفية
class IndexedBooksLoader {
  final AppState _appState = AppState();

  /// تحميل الكتب المفهرسة في الخلفية
  void loadInBackground() {
    if (_appState.isLoadingIndexedBooks ||
        _appState.cachedIndexedBooks != null) {
      return;
    }

    _appState.isLoadingIndexedBooks = true;
    Future.microtask(_loadBooks);
  }

  Future<void> _loadBooks() async {
    try {
      final books = await ShamelaSearchIndexer().getIndexedBooks();
      _appState.cachedIndexedBooks = _filterOutTemp(books);
    } catch (e) {
      _appState.cachedIndexedBooks = [];
    } finally {
      _appState.isLoadingIndexedBooks = false;
    }
  }

  /// الحصول على الكتب المفهرسة (من الكاش أو التحميل)
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    if (_appState.cachedIndexedBooks != null) {
      return _appState.cachedIndexedBooks!;
    }

    try {
      final books = await ShamelaSearchIndexer().getIndexedBooks();
      final filtered = _filterOutTemp(books);
      _appState.cachedIndexedBooks = filtered;
      return filtered;
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _filterOutTemp(List<Map<String, dynamic>> books) {
    return books
        .where((b) {
          final path = b['book_path'] as String? ?? '';
          final name = path.split(RegExp(r'[\\/]')).last;
          return !name.startsWith('_temp_');
        })
        .toList();
  }
}
