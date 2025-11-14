import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/BookCardStorage.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:golden_shamela/database/search_database_helper.dart';
import 'package:golden_shamela/database/text_processor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

class SearchIndexer {
  final dbHelper = SearchDatabaseHelper.instance;

  /// Checks if a book is already indexed and up-to-date.
  Future<bool> _isBookUpToDate(String bookPath, int fileLastModified) async {
    final metadata = await dbHelper.getIndexedBookMetadata(bookPath);
    if (metadata != null) {
      final indexedLastModified = metadata['last_modified_date'];
      if (indexedLastModified == fileLastModified) {
        return true; // Book is already indexed and up-to-date
      }
    }
    return false;
  }

  /// Indexes a list of .docx files.
  ///
  /// For each book, it parses the content, processes the text, and inserts it
  /// into the FTS tables for searching.
  /// The [onProgress] callback is used to report the indexing status.
  Future<void> indexBooks(
      List<String> bookFilePaths,
      Function(IndexingProgress progress) onProgress,
      ValueNotifier<bool> cancellationNotifier) async {
    final db = await dbHelper.database;
    int totalBooks = bookFilePaths.length;
    int currentBookNum = 0;

    for (String bookPath in bookFilePaths) {
      // Check for cancellation at the start of each book
      if (cancellationNotifier.value) {
        onProgress(IndexingProgress(
          message: 'Indexing cancelled by user.',
          totalBooks: totalBooks,
          currentBookNum: currentBookNum,
        ));
        return;
      }

      currentBookNum++;
      String bookName = p.basenameWithoutExtension(bookPath); // Use basenameWithoutExtension
      onProgress(IndexingProgress(
        message: 'Processing book: $bookName',
        totalBooks: totalBooks,
        currentBookNum: currentBookNum,
      ));

      try {
        final file = File(bookPath);
        final fileLastModified = file.lastModifiedSync().millisecondsSinceEpoch;

        if (await _isBookUpToDate(bookPath, fileLastModified)) {
          onProgress(IndexingProgress(
            message: 'Skipping up-to-date book: $bookName',
            totalBooks: totalBooks,
            currentBookNum: currentBookNum,
          ));
          continue;
        }

        List<WordPage> pages = await DocxParser.parse(bookPath);
        if (pages.isEmpty) {
          onProgress(IndexingProgress(
            message: 'Skipping empty book: $bookName',
            totalBooks: totalBooks,
            currentBookNum: currentBookNum,
          ));
          continue;
        }

        // Use batches for efficient bulk insertion
        var rawBatch = db.batch();
        var normalizedBatch = db.batch();
        var stemmedBatch = db.batch();
        int batchCounter = 0;

        for (int i = 0; i < pages.length; i++) {
          // We can also check for cancellation inside the page loop for faster response,
          // but that might leave a book partially indexed.
          // For simplicity, we only check between books.

          WordPage page = pages[i];
          String rawText = page.text();

          if (rawText.trim().isEmpty) {
            continue;
          }
          
          onProgress(IndexingProgress(
            message: 'Indexing: $bookName',
            totalBooks: totalBooks,
            currentBookNum: currentBookNum,
            totalPagesInBook: pages.length,
            currentPageNum: i + 1,
          ));

          String normalizedText = TextProcessor.normalize(rawText);
          String stemmedText = TextProcessor.stem(rawText);

          rawBatch.insert(SearchDatabaseHelper.ftsPagesRaw, {
            'book_path': bookPath,
            'page_number': i,
            'content': rawText,
          });

          normalizedBatch.insert(SearchDatabaseHelper.ftsPagesNormalized, {
            'book_path': bookPath,
            'page_number': i,
            'content': normalizedText,
          });

          stemmedBatch.insert(SearchDatabaseHelper.ftsPagesStemmed, {
            'book_path': bookPath,
            'page_number': i,
            'content': stemmedText,
          });

          batchCounter++;

          // Commit the batch periodically to avoid memory issues
          if (batchCounter >= 100) {
            await rawBatch.commit(noResult: true);
            await normalizedBatch.commit(noResult: true);
            await stemmedBatch.commit(noResult: true);
            // Re-initialize batches
            rawBatch = db.batch();
            normalizedBatch = db.batch();
            stemmedBatch = db.batch();
            batchCounter = 0;
          }
        }

        // Commit any remaining items in the batches
        if (batchCounter > 0) {
          await rawBatch.commit(noResult: true);
          await normalizedBatch.commit(noResult: true);
          await stemmedBatch.commit(noResult: true);
        }

        // Update metadata after successful indexing
        await dbHelper.insertOrUpdateIndexedBookMetadata(
            bookPath, fileLastModified, pages.length);

        // Save book metadata (author, section)
        BookCard bookCard = BookCardStorage().getBookCardByTitle(bookName);
        await dbHelper.insertOrUpdateBookMetadata(
          bookPath: bookPath,
          title: bookName,
          authorId: bookCard.authorId,
          sectionId: bookCard.sectionId,
        );

        onProgress(IndexingProgress(
          message: 'Finished indexing $bookName.',
          totalBooks: totalBooks,
          currentBookNum: currentBookNum,
          totalPagesInBook: pages.length,
          currentPageNum: pages.length,
        ));

      } catch (e) {
        onProgress(IndexingProgress(
          message: 'Error indexing $bookName: $e',
          totalBooks: totalBooks,
          currentBookNum: currentBookNum,
        ));
        // Continue to the next book
      }
    }
    onProgress(IndexingProgress(
      message: 'Indexing complete for all books.',
      totalBooks: totalBooks,
      currentBookNum: totalBooks,
    ));
  }
}
