import 'dart:io';

import 'package:path/path.dart' as p;

/// Central storage layout:
/// - `LibraryData` contains durable book folders.
/// - `System` contains databases, indexes, and shared assets.
class AppStoragePaths {
  static const String dataRootName = 'TheLibraryBooks';
  static const String booksStoreName = 'LibraryData';
  static const String systemStoreName = 'System';
  static const String sourceDocxFileName = 'source.docx';
  static const String sharedFontsFolderName = 'shared_fonts';

  static String get runnerRootPath =>
      File(Platform.resolvedExecutable).parent.path;

  static String get dataRootPath => p.join(runnerRootPath, dataRootName);

  static String get booksStorePath => p.join(dataRootPath, booksStoreName);

  static String get systemStorePath => p.join(dataRootPath, systemStoreName);

  static String get sharedFontsPath =>
      p.join(systemStorePath, sharedFontsFolderName);

  static String get booksMetadataDbPath =>
      p.join(systemStorePath, 'books_metadata.db');

  static String get arabicSearchDbPath =>
      p.join(systemStorePath, 'arabic_search.db');

  static String get shamelaSearchDbPath =>
      p.join(systemStorePath, 'shamela_search.db');

  static String get meiliDataPath => p.join(systemStorePath, 'meili_data');

  static String get rootsDbPath => p.join(systemStorePath, 'roots_db');

  static Future<void> ensureBaseDirectories() async {
    await Directory(dataRootPath).create(recursive: true);
    await Directory(booksStorePath).create(recursive: true);
    await Directory(systemStorePath).create(recursive: true);
    await _relocateSystemEntriesFromBooksStore();
    await Directory(sharedFontsPath).create(recursive: true);
  }

  static Future<void> _relocateSystemEntriesFromBooksStore() async {
    const entries = [
      'books_metadata.db',
      'arabic_search.db',
      'shamela_search.db',
      'meili_data',
      'roots_db',
      '_shared_fonts',
    ];

    for (final entry in entries) {
      final oldPath = p.join(booksStorePath, entry);
      final newName = entry == '_shared_fonts' ? sharedFontsFolderName : entry;
      final newPath = p.join(systemStorePath, newName);
      await _moveIfDestinationMissing(oldPath, newPath);
    }
  }

  static Future<void> _moveIfDestinationMissing(
    String oldPath,
    String newPath,
  ) async {
    final oldType = await FileSystemEntity.type(oldPath);
    if (oldType == FileSystemEntityType.notFound) return;
    if (await FileSystemEntity.type(newPath) != FileSystemEntityType.notFound) {
      return;
    }

    await Directory(p.dirname(newPath)).create(recursive: true);
    try {
      if (oldType == FileSystemEntityType.directory) {
        await Directory(oldPath).rename(newPath);
      } else if (oldType == FileSystemEntityType.file) {
        await File(oldPath).rename(newPath);
      }
    } on FileSystemException catch (e) {
      print(
        'AppStoragePaths: system entry relocation skipped: '
        '$oldPath -> $newPath ($e)',
      );
    }
  }

  static String bookIdFromTitle(String title) {
    final trimmed = title.trim();
    final safe = trimmed
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.isEmpty ? 'book' : safe;
  }

  static String bookIdFromPath(String filePath) {
    if (p.basename(filePath).toLowerCase() == sourceDocxFileName &&
        _isInsideBooksStore(filePath)) {
      return p.basename(p.dirname(filePath));
    }
    return bookIdFromTitle(p.basenameWithoutExtension(filePath));
  }

  static bool _isInsideBooksStore(String filePath) {
    final store = p.normalize(p.absolute(booksStorePath)).toLowerCase();
    final file = p.normalize(p.absolute(filePath)).toLowerCase();
    return p.isWithin(store, file);
  }

  static String displayTitleFromPath(String filePath) {
    final bookId = bookIdFromPath(filePath);
    return bookId == 'book' ? p.basenameWithoutExtension(filePath) : bookId;
  }

  static String bookDirPath(String bookId) =>
      p.join(booksStorePath, bookIdFromTitle(bookId));

  static String bookSourcePath(String bookId) =>
      p.join(bookDirPath(bookId), sourceDocxFileName);

  static String bookMetadataPath(String bookId) =>
      p.join(bookDirPath(bookId), 'metadata.json');

  static String bookPagesDirPath(String bookId) =>
      p.join(bookDirPath(bookId), 'pages');

  static Future<void> deleteRebuildableCache(String bookId) async {
    final metadataFile = File(bookMetadataPath(bookId));
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }

    final pagesDir = Directory(bookPagesDirPath(bookId));
    if (await pagesDir.exists()) {
      await pagesDir.delete(recursive: true);
    }
  }

  static Future<Directory> createProcessingSessionDir(String bookId) {
    final safeBookId = bookIdFromTitle(bookId).replaceAll(' ', '_');
    return Directory.systemTemp.createTemp('the_library_${safeBookId}_');
  }

  static Future<List<File>> listStoredSourceFiles() async {
    await ensureBaseDirectories();
    final root = Directory(booksStorePath);
    if (!await root.exists()) return [];

    final sources = <File>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('_') || name.startsWith('.')) continue;

      final source = File(p.join(entity.path, sourceDocxFileName));
      if (await source.exists()) {
        sources.add(source);
      }
    }

    sources.sort(
      (a, b) => bookIdFromPath(a.path)
          .toLowerCase()
          .compareTo(bookIdFromPath(b.path).toLowerCase()),
    );
    return sources;
  }
}
