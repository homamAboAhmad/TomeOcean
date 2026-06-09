import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:path/path.dart' as p;
import 'ShamelaSearchEngine.dart';

/// Indexer for Shamela-style Arabic search engine
class ShamelaSearchIndexer {
  final ShamelaSearchEngine _engine = ShamelaSearchEngine();

  Future<void> indexBooks(
    List<String> bookFilePaths,
    Function(IndexingProgress progress) onProgress,
    ValueNotifier<bool> cancellationNotifier,
  ) async {
    await _engine.initialize();

    // First, filter books that need indexing
    onProgress(IndexingProgress(message: 'جارٍ فحص الكتب...'));
    List<String> booksToIndex = [];
    int totalBooks = bookFilePaths.length;
    int checkedBooks = 0;

    for (String bookPath in bookFilePaths) {
      if (cancellationNotifier.value) {
        onProgress(IndexingProgress(message: 'تم إلغاء الفهرسة.'));
        return;
      }

      // Ignore temporary files or hidden files
      String fileName = p.basename(bookPath);
      if (fileName.startsWith('~\$') || fileName.startsWith('.')) {
        continue;
      }

      checkedBooks++;
      String bookName = AppStoragePaths.displayTitleFromPath(bookPath);

      onProgress(
        IndexingProgress(
          message: 'جارٍ فحص: $bookName ($checkedBooks/$totalBooks)',
          totalBooks: totalBooks,
          currentBookNum: checkedBooks,
        ),
      );

      try {
        bool needsIndexing = await _engine.needsIndexing(bookPath);
        if (needsIndexing) {
          booksToIndex.add(bookPath);
          // print("ShamelaSearchIndexer: Book needs indexing: $bookName");
        }
        // else: Book is up to date, skip silently
      } catch (e, stackTrace) {
        // On error, add to list to be safe
        print("Error checking if $bookName needs indexing: $e");
        print("Stack trace: $stackTrace");
        booksToIndex.add(bookPath);
      }
    }

    if (booksToIndex.isEmpty) {
      onProgress(
        IndexingProgress(
          message: 'جميع الكتب محدثة. لا حاجة للفهرسة.',
          totalBooks: totalBooks,
          currentBookNum: totalBooks,
        ),
      );
      return;
    }

    onProgress(
      IndexingProgress(
        message:
            'تم العثور على ${booksToIndex.length} كتاب يحتاج للفهرسة من أصل $totalBooks. جارٍ بدء الفهرسة...',
        totalBooks: booksToIndex.length,
        currentBookNum: 0,
      ),
    );

    int currentBookNum = 0;

    for (String bookPath in booksToIndex) {
      if (cancellationNotifier.value) {
        onProgress(IndexingProgress(message: 'تم إلغاء الفهرسة.'));
        return;
      }

      currentBookNum++;
      String bookName = AppStoragePaths.displayTitleFromPath(bookPath);
      onProgress(
        IndexingProgress(
          message:
              'جارٍ معالجة الكتاب: $bookName ($currentBookNum/${booksToIndex.length})',
          totalBooks: booksToIndex.length,
          currentBookNum: currentBookNum,
        ),
      );

      try {
        List<WordPage> pages = await DocxParser.parse(bookPath);
        if (pages.isEmpty) {
          onProgress(
            IndexingProgress(message: 'تخطي الكتاب الفارغ: $bookName'),
          );
          continue;
        }

        List<Map<String, dynamic>> documents = [];
        for (int i = 0; i < pages.length; i++) {
          WordPage page = pages[i];
          for (int j = 0; j < page.ps.length; j++) {
            var paragraph = page.ps[j];
            if (paragraph.text.trim().isNotEmpty) {
              String safeBookPath = base64Encode(
                utf8.encode(bookPath),
              ).replaceAll('+', '_').replaceAll('/', '_').replaceAll('=', '');

              documents.add({
                'id': '${safeBookPath}_${i}_$j',
                'book_path': bookPath,
                'book_name': bookName,
                'page_number': i,
                'section_type': paragraph.sectionType,
                'content': paragraph.text,
                'raw_content': paragraph.text,
              });
            }
          }
        }

        // Index with progress callback
        await _engine.indexBook(
          bookPath,
          bookName,
          documents,
          onProgress: (current, total) {
            onProgress(
              IndexingProgress(
                message: 'جارٍ الفهرسة: $bookName',
                totalBooks: booksToIndex.length,
                currentBookNum: currentBookNum,
                totalPagesInBook: total,
                currentPageNum: current,
              ),
            );
          },
        );
      } catch (e) {
        onProgress(IndexingProgress(message: 'خطأ في فهرسة $bookName: $e'));
      }
    }

    onProgress(
      IndexingProgress(
        message:
            'اكتملت الفهرسة لجميع الكتب. تم فهرسة ${booksToIndex.length} من أصل $totalBooks كتاب.',
        totalBooks: booksToIndex.length,
        currentBookNum: booksToIndex.length,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    await _engine.initialize();
    return await _engine.getIndexedBooks();
  }

  Future<void> deleteBook(String bookPath) async {
    await _engine.initialize();
    await _engine.deleteBook(bookPath);
  }

  /// فهرسة كتاب واحد بسرعة (للكتب الجديدة)
  Future<bool> indexSingleBook(String bookPath) async {
    await _engine.initialize();

    String bookName = AppStoragePaths.displayTitleFromPath(bookPath);
    print("[Indexing] Start indexing: $bookName");

    try {
      // تحقق إذا كان الكتاب مفهرس ولا يحتاج تحديث
      bool needsIndexing = await _engine.needsIndexing(bookPath);
      if (!needsIndexing) {
        print("[Indexing] $bookName is up to date - No need to index");
        return true;
      }

      List<WordPage> pages = await DocxParser.parse(bookPath);
      return await indexBookFromPages(bookPath, pages);
    } catch (e) {
      print("[Indexing] ✗ Error indexing $bookName: $e");
      return false;
    }
  }

  /// فهرسة كتاب من الصفحات المحملة في الذاكرة مباشرة
  Future<bool> indexBookFromPages(
    String bookPath,
    List<WordPage> pages, {
    Function(double progress, String message)? onProgress,
    bool Function()? shouldStop,
    Future<void> Function()? acquireLock,
    void Function()? releaseLock,
  }) async {
    await _engine.initialize();

    String bookName = AppStoragePaths.displayTitleFromPath(bookPath);

    try {
      if (pages.isEmpty) {
        print("[Indexing] $bookName is empty - Skipping");
        return false;
      }

      onProgress?.call(0.1, "جارٍ تجهيز المستندات...");

      List<Map<String, dynamic>> documents = [];
      for (int i = 0; i < pages.length; i++) {
        if (shouldStop?.call() ?? false) return false; // Basic check

        WordPage page = pages[i];
        for (int j = 0; j < page.ps.length; j++) {
          var paragraph = page.ps[j];
          if (paragraph.text.trim().isNotEmpty) {
            String safeBookPath = base64Encode(
              utf8.encode(bookPath),
            ).replaceAll('+', '_').replaceAll('/', '_').replaceAll('=', '');

            documents.add({
              'id': '${safeBookPath}_${i}_$j',
              'book_path': bookPath,
              'book_name': bookName,
              'page_number': i,
              'section_type': paragraph.sectionType,
              'content': paragraph.text,
              'raw_content': paragraph.text,
            });
          }
        }

        // Report progress every 5 pages
        if (i % 5 == 0 && pages.isNotEmpty) {
          double progress = 0.1 + (0.4 * i / pages.length);
          onProgress?.call(
            progress,
            "جارٍ معالجة الصفحة ${i + 1}/${pages.length}",
          );
        }
      }

      onProgress?.call(0.5, "جارٍ فهرسة ${documents.length} فقرة...");

      await _engine.indexBook(
        bookPath,
        bookName,
        documents,
        onProgress: (current, total) {
          if (total > 0) {
            // Map from 50% to 100%
            double progress = 0.5 + (0.5 * current / total);
            onProgress?.call(progress, "جارٍ الفهرسة: $current/$total فقرة");
          }
        },
        shouldStop: shouldStop,
        acquireLock: acquireLock,
        releaseLock: releaseLock,
      );

      onProgress?.call(1.0, "اكتملت الفهرسة!");
      print("[Indexing] ✓ Indexed $bookName (${documents.length} paragraphs)");
      return true;
    } catch (e) {
      print("[Indexing] ✗ Error indexing $bookName: $e");
      return false;
    }
  }
}
