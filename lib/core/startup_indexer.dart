import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookLibraryRepository.dart';
import 'package:path/path.dart' as p;

/// فحص وفهرسة الكتب الجديدة عند بداية التطبيق
class StartupIndexer {
  static bool _isRunning = false;

  /// تشغيل فحص الفهرسة في الخلفية
  static Future<void> runBackgroundCheck() async {
    if (_isRunning) {
      debugPrint("[Startup Indexer] Already running, skipping...");
      return;
    }

    _isRunning = true;
    debugPrint("[Startup Indexer] Starting new books check...");

    try {
      await AppStoragePaths.ensureBaseDirectories();
      final files = await BookLibraryRepository().loadAvailableBookSources();

      if (files.isEmpty) {
        debugPrint("[Startup Indexer] No books found");
        _isRunning = false;
        return;
      }

      debugPrint(
        "[Startup Indexer] Found ${files.length} books total - Checking which need indexing...",
      );

      final indexer = ShamelaSearchIndexer();
      int indexed = 0;
      int skipped = 0;

      for (final file in files) {
        final bookName = AppStoragePaths.displayTitleFromPath(file.path);

        // Skip temporary files
        if (p.basename(file.path).startsWith('~\$')) {
          // debugPrint("[Startup Indexer] Skipping temp file: $bookName");
          continue;
        }

        try {
          final result = await indexer.indexSingleBook(file.path);
          if (result) {
            // قد يكون indexed أو skipped (محدث)
            indexed++;
          } else {
            skipped++;
          }
        } catch (e) {
          debugPrint("[Startup Indexer] Error in $bookName: $e");
          skipped++;
        }
      }

      debugPrint(
        "[Startup Indexer] ✓ Finished - Indexed: $indexed, Skipped (Error): $skipped",
      );
    } catch (e) {
      debugPrint("[Startup Indexer] General error: $e");
    } finally {
      _isRunning = false;
    }
  }
}
