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
      return;
    }

    _isRunning = true;

    try {
      await AppStoragePaths.ensureBaseDirectories();
      final files = await BookLibraryRepository().loadAvailableBookSources();

      if (files.isEmpty) {
        _isRunning = false;
        return;
      }

      final indexer = ShamelaSearchIndexer();

      for (final file in files) {
        final bookName = AppStoragePaths.displayTitleFromPath(file.path);

        // Skip temporary files
        if (p.basename(file.path).startsWith('~\$')) {
          continue;
        }

        try {
          await indexer.indexSingleBook(file.path);
        } catch (e) {
          print("[Startup Indexer] Error in $bookName: $e");
        }
      }
    } catch (e) {
      print("[Startup Indexer] General error: $e");
    } finally {
      _isRunning = false;
    }
  }
}
