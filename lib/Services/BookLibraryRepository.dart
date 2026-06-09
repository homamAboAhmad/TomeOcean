import 'dart:io';

import 'package:path/path.dart' as p;

import '../Helpers/ArabicSearchIndexer.dart';
import '../Helpers/BooksMetadataDatabase.dart';
import '../Helpers/ShamelaSearchIndexer.dart';
import '../Models/BookCard.dart';
import 'AppStoragePaths.dart';

/// Reads the app-owned book list from metadata and reconciles stored sources.
class BookLibraryRepository {
  BookLibraryRepository({BooksMetadataDatabase? metadataDb})
      : _metadataDb = metadataDb ?? BooksMetadataDatabase();

  final BooksMetadataDatabase _metadataDb;

  Future<List<File>> loadAvailableBookSources() async {
    await AppStoragePaths.ensureBaseDirectories();
    await _metadataDb.initialize();

    final filesByPath = <String, File>{};
    final knownPaths = await _metadataDb.getBookPaths();

    for (final bookPath in knownPaths) {
      final file = File(bookPath);
      if (!await file.exists()) {
        await pruneMissingBookSource(bookPath);
        continue;
      }
      filesByPath[_pathKey(file.path)] = file;
    }

    await _registerMissingStoredSources(filesByPath);

    final files = filesByPath.values.toList();
    files.sort(
      (a, b) => AppStoragePaths.displayTitleFromPath(a.path)
          .toLowerCase()
          .compareTo(AppStoragePaths.displayTitleFromPath(b.path).toLowerCase()),
    );
    return files;
  }

  Future<void> _registerMissingStoredSources(
    Map<String, File> filesByPath,
  ) async {
    final storedSources = await AppStoragePaths.listStoredSourceFiles();

    for (final source in storedSources) {
      final key = _pathKey(source.path);
      if (filesByPath.containsKey(key)) continue;

      final title = AppStoragePaths.displayTitleFromPath(source.path);
      await _metadataDb.saveBook(BookCard(title: title), source.path);
      filesByPath[key] = source;
    }
  }

  Future<void> pruneMissingBookSource(String bookPath) async {
    await _metadataDb.deleteBookByPath(bookPath);

    try {
      await ShamelaSearchIndexer().deleteBook(bookPath);
    } catch (e) {
      print('BookLibraryRepository: could not prune Shamela index: $e');
    }

    try {
      await ArabicSearchIndexer().deleteBook(bookPath);
    } catch (e) {
      print('BookLibraryRepository: could not prune Arabic index: $e');
    }
  }

  String _pathKey(String path) => p.normalize(p.absolute(path)).toLowerCase();
}
