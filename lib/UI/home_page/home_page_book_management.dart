import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart'
    show BookProcessingService, CACHE_VERSION;
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/EmbeddedFontExtractor.dart';
import 'package:golden_shamela/FontsLoaderController.dart';

/// Book management operations for HomePage
class HomePageBookManagement {
  final BuildContext context;

  HomePageBookManagement({required this.context});

  /// Read and process docx file
  Future<WordDocument?> readDocxFile(String? filePath, [WordDocument? tempDoc]) async {
    if (filePath == null) return null;

    WordDocument wordDocument = tempDoc ?? WordDocument();
    final bookId = AppStoragePaths.bookIdFromPath(filePath);
    final storedBook = await BooksMetadataDatabase().getBookByPath(filePath);
    final displayTitle = storedBook?.title.isNotEmpty == true
        ? storedBook!.title
        : AppStoragePaths.displayTitleFromPath(filePath);
    final sourcePath = AppStoragePaths.bookSourcePath(bookId);
    final archivePath = await File(sourcePath).exists() ? sourcePath : filePath;
    if (!await File(archivePath).exists()) {
      ShowSnackBar(context, "مصدر الكتاب مفقود. يرجى إعادة استيراده.");
      return null;
    }
    wordDocument.title = displayTitle;

    final bookCacheDir = Directory(AppStoragePaths.bookDirPath(bookId));
    final metadataFile = File(AppStoragePaths.bookMetadataPath(bookId));
    final pagesDir = Directory(AppStoragePaths.bookPagesDirPath(bookId));

    bool loadedFromCache = false;

    try {
      if (await bookCacheDir.exists()) {
        final docxFile = File(archivePath);
        final docxLastModified = await docxFile.lastModified();
        final cacheLastModified = await metadataFile.lastModified();

        if (cacheLastModified.isAfter(docxLastModified)) {
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

            // تحميل الـ Archive لتمكين قراءة ملفات التذييل/الترويسة
            final appState = AppState();
            appState.docArchive = await FileToArchive(archivePath);
            wordDocument.archive = appState.docArchive;

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

        // بعد الانتهاء، نحاول التحميل مرة أخرى من الكاش
        // نعيد استدعاء الدالة لتنفيذ منطق التحميل (Recursion)
        return await readDocxFile(filePath, tempDoc);
      } catch (e) {
        ShowSnackBar(context, "Error processing book: $e");
        return null;
      }
    }

    // No longer calling onBookAdded here as it causes double addition in HomePage
    // onBookAdded(wordDocument);
    return wordDocument;
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
