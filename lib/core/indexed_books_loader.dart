import 'dart:io';

import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Services/BookLibraryRepository.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/core/app_state.dart';

/// مسؤول عن تحميل الكتب المفهرسة في الخلفية
class IndexedBooksLoader {
  final AppState _appState = AppState();

  /// تحميل الكتب المفهرسة في الخلفية
  void loadInBackground() {
    final cached = _appState.cachedIndexedBooks;
    if (_appState.isLoadingIndexedBooks ||
        (cached != null && cached.isNotEmpty)) {
      return;
    }

    _appState.isLoadingIndexedBooks = true;
    Future.microtask(_loadBooks);
  }

  Future<void> _loadBooks() async {
    try {
      final books = await ShamelaSearchIndexer().getIndexedBooks();
      _appState.cachedIndexedBooks = await _filterAvailable(books);
    } catch (e) {
      _appState.cachedIndexedBooks = [];
    } finally {
      _appState.isLoadingIndexedBooks = false;
    }
  }

  /// الحصول على الكتب المفهرسة (من الكاش أو التحميل)
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    final cached = _appState.cachedIndexedBooks;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final books = await ShamelaSearchIndexer().getIndexedBooks();
      final filtered = await _filterAvailable(books);
      _appState.cachedIndexedBooks = filtered;
      return filtered;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _filterAvailable(
    List<Map<String, dynamic>> books,
  ) async {
    final repository = BookLibraryRepository();
    final filtered = <Map<String, dynamic>>[];

    for (final book in books) {
      final path = book['book_path'] as String? ?? '';
      if (path.isEmpty) continue;

      final name = path.split(RegExp(r'[\\/]')).last;
      if (name.startsWith('_temp_')) continue;

      final portablePath = await AppStoragePaths.resolvePortableStoredSourcePath(
        path,
        bookName: book['book_name'] as String?,
      );
      if (portablePath != null) {
        if (portablePath != path) {
          await repository.relocateBookPath(path, portablePath);
          book['book_path'] = portablePath;
        }
        filtered.add(book);
      } else {
        await repository.pruneMissingBookSource(path);
      }
    }

    return filtered;
  }
}
