import 'dart:io';

import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';

class LibraryBooksExporter {
  Future<int> exportBooks(
    Iterable<LibraryBookItem> books,
    String directory, {
    void Function(int done, int total)? onProgress,
  }) async {
    final items = books.toList();
    var copied = 0;
    var done = 0;
    for (final item in items) {
      final source = File(item.bookPath);
      if (await source.exists()) {
        final name = '${AppStoragePaths.bookIdFromTitle(item.title)}.docx';
        await source.copy(_uniquePath(directory, name));
        copied++;
      }
      done++;
      onProgress?.call(done, items.length);
    }
    return copied;
  }

  String _uniquePath(String directory, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    final ext = dot == -1 ? '' : fileName.substring(dot);
    var candidate = '$directory${Platform.pathSeparator}$fileName';
    var i = 2;
    while (File(candidate).existsSync()) {
      candidate = '$directory${Platform.pathSeparator}$base ($i)$ext';
      i++;
    }
    return candidate;
  }
}
