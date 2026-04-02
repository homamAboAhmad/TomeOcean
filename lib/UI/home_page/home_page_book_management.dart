import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart'
    show BookProcessingService, CACHE_VERSION;
import 'package:golden_shamela/FontsLoaderController.dart';

/// Book management operations for HomePage
class HomePageBookManagement {
  final BuildContext context;

  HomePageBookManagement({required this.context});

  /// Read and process docx file
  Future<WordDocument?> readDocxFile(String? filePath, [WordDocument? tempDoc]) async {
    if (filePath == null) return null;

    WordDocument wordDocument = tempDoc ?? WordDocument();
    wordDocument.title = getFileName(filePath);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final tomeOceanDir = Directory('${appDocsDir.path}/tome_ocean');
    final bookCacheDir = Directory(
      '${tomeOceanDir.path}/${wordDocument.title}',
    );
    final metadataFile = File('${bookCacheDir.path}/metadata.json');
    final pagesDir = Directory('${bookCacheDir.path}/pages');

    bool loadedFromCache = false;

    try {
      if (await bookCacheDir.exists()) {
        final docxFile = File(filePath);
        final docxLastModified = await docxFile.lastModified();
        final cacheLastModified = await metadataFile.lastModified();

        if (cacheLastModified.isAfter(docxLastModified)) {
          final jsonString = await metadataFile.readAsString();
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

          final cachedVersion = jsonMap['_cacheVersion'] as int? ?? 0;
          if (cachedVersion < CACHE_VERSION) {
            debugPrint('Cache outdated (v$cachedVersion < v$CACHE_VERSION), re-parsing...');
            await bookCacheDir.delete(recursive: true);
            loadedFromCache = false;
          } else {
            wordDocument = WordDocument.fromCacheJson(jsonMap);

            // تحميل الـ Archive لتمكين قراءة ملفات التذييل/الترويسة
            final appState = AppState();
            appState.docArchive = await FileToArchive(filePath);
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
            
            // تحميل الخطوط المستخرجة إن وجدت
            if (wordDocument.extractedFontPaths.isNotEmpty) {
              await loadExtractedFonts(wordDocument.extractedFontPaths);
            }
            await loadKnownSystemFontsForDocument(wordDocument.fontsList);

            loadedFromCache = true;
          }
        }
      }
    } catch (e) {
      ShowSnackBar(context, "Error loading from cache, re-parsing: $e");
      if (await bookCacheDir.exists()) {
        await bookCacheDir.delete(recursive: true);
      }
      loadedFromCache = false;
    }

    if (!loadedFromCache) {
      // إذا لم يكن في الكاش، نستخدم الخدمة المركزية للمعالجة
      try {
        ShowSnackBar(context, "Cache missing or outdated, parsing...");

        await BookProcessingService().parseAndCacheForOpening(filePath);

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
    await Future.delayed(Duration(milliseconds: 1500), () {});
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
