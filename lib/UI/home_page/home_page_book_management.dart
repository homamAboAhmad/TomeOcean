import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:golden_shamela/core/app_state.dart';

/// Book management operations for HomePage
class HomePageBookManagement {
  final BuildContext context;
  final Function(WordDocument) onBookAdded;

  HomePageBookManagement({
    required this.context,
    required this.onBookAdded,
  });

  /// Read and process docx file
  Future<void> readDocxFile(String? filePath) async {
    if (filePath == null) return;

    WordDocument wordDocument = WordDocument();
    wordDocument.title = getFileName(filePath);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final tomeOceanDir = Directory('${appDocsDir.path}/tome_ocean');
    final bookCacheDir = Directory('${tomeOceanDir.path}/${wordDocument.title}');
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
          wordDocument = WordDocument.fromCacheJson(jsonMap);
          wordDocument.pagesDirectory = pagesDir.path;

          final pageFiles = await pagesDir.list().toList();
          pageFiles.sort((a, b) {
            final aNum = int.parse(p.basenameWithoutExtension(a.path));
            final bNum = int.parse(p.basenameWithoutExtension(b.path));
            return aNum.compareTo(bNum);
          });
          wordDocument.pageFilePaths =
              pageFiles.map((file) => p.basename(file.path)).toList();
          wordDocument.initLoadedPages();

          ShowSnackBar(context, "Loaded from cache: ${wordDocument.title}");
          loadedFromCache = true;
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
      try {
        final appState = AppState();
        appState.docArchive = await FileToArchive(filePath);
        List<WordPage> parsedPages = await AddDocData(appState.docArchive, wordDocument);
        wordDocument.setLoadedPages(parsedPages);

        await bookCacheDir.create(recursive: true);
        await pagesDir.create(recursive: true);

        final metadataJsonMap = wordDocument.toMetadataJson();
        final metadataJsonString = jsonEncode(metadataJsonMap);
        await metadataFile.writeAsString(metadataJsonString);

        wordDocument.pagesDirectory = pagesDir.path;
        for (int i = 0; i < parsedPages.length; i++) {
          final pageFile = File('${pagesDir.path}/$i.json');
          await pageFile.writeAsString(jsonEncode(parsedPages[i].toJson()));
        }

        ShowSnackBar(context, "Parsed and saved to cache: ${wordDocument.title}");
      } catch (e) {
        ShowSnackBar(context, "Error parsing docx: $e");
        return;
      }
    }

    onBookAdded(wordDocument);
    await Future.delayed(Duration(milliseconds: 1500), () {});
  }
}

