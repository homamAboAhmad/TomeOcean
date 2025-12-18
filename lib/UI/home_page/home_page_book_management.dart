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
          
          // تحميل الـ Archive لتمكين قراءة ملفات التذييل/الترويسة
          // لأن هذه الملفات يتم تحميلها ديناميكياً من الأرشيف وليست مخزنة في الـ Cache
          final appState = AppState();
          appState.docArchive = await FileToArchive(filePath);
          
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
          print("DEBUG: Loaded from cache - bookMarksMap has ${wordDocument.bookMarksMap.length} entries");
          print("DEBUG: hyperlinkAnchors should be in pages if saved correctly");
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
      String fileToRead = filePath;
      File? tempFile;
      
      try {
        // إنشاء نسخة مؤقتة للعمل عليها
        // لكي لا نعدل الملف الأصلي ونفسده بالنسبة للوورد
        final tempDir = await getTemporaryDirectory();
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        String tempPath = '${tempDir.path}/temp_book_$uniqueId.docx';
        
        // نسخ الملف الأصلي
        File(filePath).copySync(tempPath);
        tempFile = File(tempPath);
        fileToRead = tempPath;
        
        // محاولة إصلاح الصور (EMF) على النسخة المؤقتة
        int sizeBefore = await tempFile.length();
        await _runImageFixer(fileToRead);
        int sizeAfter = await tempFile.length();
        print("Temp file size change: $sizeBefore -> $sizeAfter");
        
        final appState = AppState();
        // قراءة النسخة المؤقتة (التي تم إصلاح صورها)
        appState.docArchive = await FileToArchive(fileToRead);
        
        List<WordPage> parsedPages = await AddDocData(appState.docArchive, wordDocument);
        wordDocument.setLoadedPages(parsedPages);
        
        // ... (الحفظ في الكاش كما هو)
        
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
      } finally {
        // حذف النسخة المؤقتة
        if (tempFile != null && await tempFile.exists()) {
          try {
            await tempFile.delete();
            print("Temporary file deleted: ${tempFile.path}");
          } catch (e) {
            print("Error deleting temp file: $e");
          }
        }
      }
    }

    onBookAdded(wordDocument);
    await Future.delayed(Duration(milliseconds: 1500), () {});
  }

  /// تشغيل أداة إصلاح الصور الخارجية (Python EXE)
  Future<void> _runImageFixer(String filePath) async {
    try {
      // اسم ملف الـ EXE
      String exeName = "fix_word_images.exe";
      
      // محاولة العثور على المسار الصحيح
      // 1. بجانب ملف التطبيق (للنسخة النهائية)
      String exePath = "${File(Platform.resolvedExecutable).parent.path}\\$exeName";
      
      if (!await File(exePath).exists()) {
        // 2. في مجلد dist (أثناء التطوير - المسار الذي ذكرته)
        exePath = "dist\\$exeName";
        if (!await File(exePath).exists()) {
          // 3. في مجلد scripts
          exePath = "scripts\\$exeName"; 
          if (!await File(exePath).exists()) {
             // 4. في نفس المجلد الحالي
             exePath = exeName;
          }
        }
      }

      print("Attempting to run Image Fixer: $exePath on $filePath");
      
      final result = await Process.run(exePath, [filePath]);
      
      if (result.exitCode == 0) {
        print("Image Fixer Output: ${result.stdout}");
        if (result.stdout.toString().contains("Done!")) {
           ShowSnackBar(context, "تم إصلاح صور الكتاب (EMF -> PNG)");
        }
      } else {
        print("Image Fixer Error (${result.exitCode}): ${result.stderr}");
      }
    } catch (e) {
      print("Could not run Image Fixer: $e");
      // لا نقوم بإيقاف العملية، فالـ exe اختياري
    }
  }
}

