import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
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

    int totalBooks = bookFilePaths.length;
    int currentBookNum = 0;

    for (String bookPath in bookFilePaths) {
      if (cancellationNotifier.value) {
        onProgress(IndexingProgress(message: 'تم إلغاء الفهرسة.'));
        return;
      }

      currentBookNum++;
      String bookName = p.basenameWithoutExtension(bookPath);
      onProgress(IndexingProgress(
        message: 'جارٍ معالجة الكتاب: $bookName',
        totalBooks: totalBooks,
        currentBookNum: currentBookNum,
      ));

      try {
        List<WordPage> pages = await DocxParser.parse(bookPath);
        if (pages.isEmpty) {
          onProgress(IndexingProgress(message: 'تخطي الكتاب الفارغ: $bookName'));
          continue;
        }

        List<Map<String, dynamic>> documents = [];
        for (int i = 0; i < pages.length; i++) {
          WordPage page = pages[i];
          for (int j = 0; j < page.ps.length; j++) {
            var paragraph = page.ps[j];
            if (paragraph.text.trim().isNotEmpty) {
              String safeBookPath = base64Encode(utf8.encode(bookPath))
                  .replaceAll('+', '_')
                  .replaceAll('/', '_')
                  .replaceAll('=', '');

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
            onProgress(IndexingProgress(
              message: 'جارٍ الفهرسة: $bookName',
              totalBooks: totalBooks,
              currentBookNum: currentBookNum,
              totalPagesInBook: total,
              currentPageNum: current,
            ));
          },
        );

      } catch (e) {
        onProgress(IndexingProgress(message: 'خطأ في فهرسة $bookName: $e'));
      }
    }

    onProgress(IndexingProgress(
      message: 'اكتملت الفهرسة لجميع الكتب.',
      totalBooks: totalBooks,
      currentBookNum: totalBooks,
    ));
  }

  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    await _engine.initialize();
    return await _engine.getIndexedBooks();
  }

  Future<void> deleteBook(String bookPath) async {
    await _engine.initialize();
    // Note: ShamelaSearchEngine doesn't have deleteBook yet, but we can add it
    // For now, re-indexing will replace the book
  }
}

