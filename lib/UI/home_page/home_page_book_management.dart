import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/BookPart.dart';
import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart'
    show BookProcessingService, CACHE_VERSION;
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookSourceChangeMonitor.dart';
import 'package:golden_shamela/Services/BookSourceFingerprint.dart';
import 'package:golden_shamela/Services/EmbeddedFontExtractor.dart';
import 'package:golden_shamela/FontsLoaderController.dart';

/// Book management operations for HomePage
class HomePageBookManagement {
  final BuildContext context;

  HomePageBookManagement({required this.context});

  /// Read and process docx file
  Future<WordDocument?> readDocxFile(
    String? filePath, {
    WordDocument? tempDoc,
    bool deferArchiveLoad = false,
    void Function()? onArchiveLoaded,
    Future<void> Function()? onBackgroundUpdateComplete,
  }) async {
    if (filePath == null) return null;

    WordDocument wordDocument = tempDoc ?? WordDocument();
    final bookId = AppStoragePaths.bookIdFromPath(filePath);
    final storedBook = await BooksMetadataDatabase().getBookByPath(filePath);
    final displayTitle = storedBook?.title.isNotEmpty == true
        ? storedBook!.title
        : AppStoragePaths.displayTitleFromPath(filePath);
    final parts = await BooksMetadataDatabase().getBookParts(filePath);
    if (parts.length > 1) {
      return _readMultipartBook(
        filePath,
        displayTitle,
        parts,
        deferArchiveLoad: deferArchiveLoad,
        onArchiveLoaded: onArchiveLoaded,
      );
    }
    final sourcePath = AppStoragePaths.bookSourcePath(bookId);
    final archivePath = await File(sourcePath).exists() ? sourcePath : filePath;
    if (!await File(archivePath).exists()) {
      ShowSnackBar(context, "مصدر الكتاب مفقود. يرجى إعادة استيراده.");
      return null;
    }
    wordDocument.title = displayTitle;
    wordDocument.sourcePath = archivePath;

    final bookCacheDir = Directory(AppStoragePaths.bookDirPath(bookId));
    final metadataFile = File(AppStoragePaths.bookMetadataPath(bookId));
    final pagesDir = Directory(AppStoragePaths.bookPagesDirPath(bookId));

    bool loadedFromCache = false;
    final changedSourceFingerprint = await _changedSourceFingerprint(filePath);
    final sourceChanged = changedSourceFingerprint != null;
    if (sourceChanged) {
      BookSourceChangeMonitor.scheduleReprocess(
        filePath,
        onCompleted: onBackgroundUpdateComplete,
        fingerprint: changedSourceFingerprint,
      );
    }

    try {
      if (await bookCacheDir.exists()) {
        final docxFile = File(archivePath);
        final docxLastModified = await docxFile.lastModified();
        final cacheLastModified = await metadataFile.lastModified();

        if (sourceChanged || cacheLastModified.isAfter(docxLastModified)) {
          final jsonString = await metadataFile.readAsString();
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

          final cachedVersion = jsonMap['_cacheVersion'] as int? ?? 0;
          if (cachedVersion < CACHE_VERSION) {
            debugPrint('Cache outdated (v$cachedVersion < v$CACHE_VERSION), re-parsing...');
            await AppStoragePaths.deleteRebuildableCache(bookId);
            loadedFromCache = false;
          } else {
            wordDocument = WordDocument.fromCacheJson(jsonMap);
            wordDocument.title = displayTitle;
            wordDocument.sourcePath = archivePath;

            // تحميل الـ Archive لتمكين قراءة ملفات التذييل/الترويسة
            if (deferArchiveLoad) {
              wordDocument.archive = Archive();
              unawaited(
                _attachArchive(wordDocument, archivePath).then(
                  (_) => onArchiveLoaded?.call(),
                ),
              );
            } else {
              await _attachArchive(wordDocument, archivePath);
            }

            wordDocument.pagesDirectory = pagesDir.path;

            final pageFiles = await pagesDir.list().toList();
            pageFiles.sort((a, b) {
              final aName = p.basename(a.path).split('.').first;
              final bName = p.basename(b.path).split('.').first;
              final aNum = int.tryParse(aName) ?? 0;
              final bNum = int.tryParse(bName) ?? 0;
              return aNum.compareTo(bNum);
            });
            wordDocument.pageFilePaths = pageFiles
                .map((file) => p.basename(file.path))
                .toList();
            wordDocument.initLoadedPages();

            if (wordDocument.extractedFontPaths.isEmpty &&
                wordDocument.fontsList.isNotEmpty) {
              wordDocument.extractedFontPaths =
                  await EmbeddedFontExtractor.recoverSharedFontPaths(
                wordDocument.fontsList,
              );
              if (wordDocument.extractedFontPaths.isNotEmpty) {
                final updatedMetadata = Map<String, dynamic>.from(jsonMap);
                updatedMetadata.addAll(wordDocument.toMetadataJson());
                await metadataFile.writeAsString(jsonEncode(updatedMetadata));
              }
            }

            // تحميل الخطوط المستخرجة إن وجدت
            if (wordDocument.extractedFontPaths.isNotEmpty) {
              await loadExtractedFonts(wordDocument.extractedFontPaths);
            }
            await loadKnownSystemFontsForDocument(wordDocument.fontsList);

            loadedFromCache = true;
            debugPrint('Opened book from cache: $bookId');
          }
        }
      }
    } catch (e) {
      ShowSnackBar(context, "Error loading from cache, re-parsing: $e");
      if (await bookCacheDir.exists()) {
        await AppStoragePaths.deleteRebuildableCache(bookId);
      }
      loadedFromCache = false;
    }

    if (!loadedFromCache) {
      // إذا لم يكن في الكاش، نستخدم الخدمة المركزية للمعالجة
      try {
        ShowSnackBar(context, "Cache missing or outdated, parsing...");

        await BookProcessingService().parseAndCacheForOpening(archivePath);
        await BookSourceChangeMonitor.markCurrentFingerprint(filePath);

        // بعد الانتهاء، نحاول التحميل مرة أخرى من الكاش
        // نعيد استدعاء الدالة لتنفيذ منطق التحميل (Recursion)
        return await readDocxFile(
          filePath,
          tempDoc: tempDoc,
          deferArchiveLoad: deferArchiveLoad,
          onArchiveLoaded: onArchiveLoaded,
          onBackgroundUpdateComplete: onBackgroundUpdateComplete,
        );
      } catch (e) {
        ShowSnackBar(context, "Error processing book: $e");
        return null;
      }
    }

    // No longer calling onBookAdded here as it causes double addition in HomePage
    // onBookAdded(wordDocument);
    return wordDocument;
  }

  Future<String?> _changedSourceFingerprint(String path) async {
    final current = await BookSourceFingerprint.fromFile(path);
    if (current == null) return null;

    final db = await BooksMetadataDatabase().database;
    final rows = await db.query(
      'books',
      columns: ['source_hash'],
      where: 'book_path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final saved = rows.first['source_hash']?.toString();
    if (saved == null || saved.isEmpty) {
      await BookSourceChangeMonitor.markCurrentFingerprint(path);
      return null;
    }
    return saved == current ? null : current;
  }

  Future<WordDocument?> _readMultipartBook(
    String bookPath,
    String title,
    List<BookPart> parts, {
    required bool deferArchiveLoad,
    void Function()? onArchiveLoaded,
  }) async {
    final parent = WordDocument.empty();
    parent.title = title;
    parent.sourcePath = bookPath;
    parent.parts = parts;

    var totalPages = 0;
    for (final part in parts) {
      final document = await _readCachedPartDocument(
        part,
        deferArchiveLoad: deferArchiveLoad,
        onArchiveLoaded: onArchiveLoaded,
      );
      if (document == null) return null;
      parent.partDocuments[part.partNumber] = document;
      totalPages += part.pageCount;
      parent.index.addAll(
        document.index.map(
          (item) => IndexItem(
            title: item.title,
            page: item.page + part.pageOffset,
            type: item.type,
            id: '${part.partNumber}:${item.id}',
          ),
        ),
      );
    }

    parent.pageFilePaths =
        List.generate(totalPages, (index) => '$index.multipart');
    return parent;
  }

  Future<WordDocument?> _readCachedPartDocument(
    BookPart part, {
    required bool deferArchiveLoad,
    void Function()? onArchiveLoaded,
  }) async {
    final partDir = Directory(p.dirname(part.partPath));
    final metadataFile = File(p.join(partDir.path, 'metadata.json'));
    final pagesDir = Directory(p.join(partDir.path, 'pages'));
    if (!await metadataFile.exists() || !await pagesDir.exists()) {
      ShowSnackBar(context, 'أحد أجزاء الكتاب غير مكتمل. أعد استيراد الكتاب.');
      return null;
    }

    final jsonString = await metadataFile.readAsString();
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    final document = WordDocument.fromCacheJson(jsonMap);
    document.title = part.partTitle;
    document.sourcePath = part.partPath;
    document.pagesDirectory = pagesDir.path;

    final pageFiles = await pagesDir.list().toList();
    pageFiles.sort((a, b) {
      final aName = p.basename(a.path).split('.').first;
      final bName = p.basename(b.path).split('.').first;
      final aNum = int.tryParse(aName) ?? 0;
      final bNum = int.tryParse(bName) ?? 0;
      return aNum.compareTo(bNum);
    });
    document.pageFilePaths = pageFiles.map((file) => p.basename(file.path)).toList();
    document.initLoadedPages();

    if (deferArchiveLoad) {
      document.archive = Archive();
      unawaited(
        FileToArchive(part.partPath).then((archive) {
          document.archive = archive;
          onArchiveLoaded?.call();
        }),
      );
    } else {
      document.archive = await FileToArchive(part.partPath);
    }

    if (document.extractedFontPaths.isNotEmpty) {
      await loadExtractedFonts(document.extractedFontPaths);
    }
    await loadKnownSystemFontsForDocument(document.fontsList);
    return document;
  }

  Future<void> _attachArchive(WordDocument document, String archivePath) async {
    final appState = AppState();
    appState.docArchive = await FileToArchive(archivePath);
    document.archive = appState.docArchive;
  }

  /// Recursively collect books from a folder
  static Future<List<File>> collectBooksFromFolder(
    String folderPath, {
    bool recursive = true,
  }) async {
    final List<File> books = [];
    final dir = Directory(folderPath);

    if (await dir.exists()) {
      try {
        final List<FileSystemEntity> entities = await dir
            .list(recursive: recursive)
            .toList();
        for (var entity in entities) {
          if (entity is File) {
            final name = p.basename(entity.path);
            if (name.toLowerCase().endsWith('.docx') &&
                !name.startsWith(r'~$')) {
              books.add(entity);
            }
          }
        }
        // Sort alphabetically
        books.sort(
          (a, b) => p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase()),
        );
      } catch (e) {
        debugPrint("Error collecting books from folder: $e");
      }
    }
    return books;
  }
}
