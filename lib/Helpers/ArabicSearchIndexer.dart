import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:path/path.dart' as p;
import 'ArabicSearchEngine.dart';
import 'BooksMetadataDatabase.dart';

/// Indexer optimized for Arabic books using SQLite FTS5
class ArabicSearchIndexer {
  final ArabicSearchEngine _engine = ArabicSearchEngine();
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();

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
        onProgress(IndexingProgress(message: 'Indexing cancelled.'));
        return;
      }

      currentBookNum++;
      String bookName = p.basenameWithoutExtension(bookPath);
      onProgress(IndexingProgress(
        message: 'Processing book: $bookName',
        totalBooks: totalBooks,
        currentBookNum: currentBookNum,
      ));

      try {
        List<WordPage> pages = await DocxParser.parse(bookPath);
        if (pages.isEmpty) {
          onProgress(IndexingProgress(message: 'Skipping empty book: $bookName'));
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

        // Get author_id and section_id from metadata database
        String? authorId;
        String? sectionId;
        try {
          await _metadataDb.initialize();
          final bookCard = await _metadataDb.getBookByPath(bookPath);
          if (bookCard != null) {
            authorId = bookCard.authorId.isNotEmpty ? bookCard.authorId : null;
            sectionId = bookCard.sectionId.isNotEmpty ? bookCard.sectionId : null;
          }
        } catch (e) {
          print("ArabicSearchIndexer: Error getting metadata for $bookName: $e");
          // Continue indexing even if metadata retrieval fails
        }

        // Index with progress callback
        await _engine.indexBook(
          bookPath,
          bookName,
          documents,
          authorId: authorId,
          sectionId: sectionId,
          onProgress: (current, total) {
            onProgress(IndexingProgress(
              message: 'Indexing: $bookName',
              totalBooks: totalBooks,
              currentBookNum: currentBookNum,
              totalPagesInBook: total,
              currentPageNum: current,
            ));
          },
        );

      } catch (e) {
        onProgress(IndexingProgress(message: 'Error indexing $bookName: $e'));
      }
    }

    onProgress(IndexingProgress(
      message: 'Indexing complete for all books.',
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
    await _engine.deleteBook(bookPath);
  }
}

