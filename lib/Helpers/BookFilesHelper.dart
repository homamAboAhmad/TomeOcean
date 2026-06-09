import 'dart:io';

import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookLibraryRepository.dart';

loadBooks() async {
  return BookLibraryRepository().loadAvailableBookSources();
}

Future<void> cleanTempBooks() async {
  // Processing temp files are now inside system session folders and are
  // removed by BookProcessingService.finally.
}

Future<File?> loadBookByName(String fileName) async {
  final String bookId = AppStoragePaths.bookIdFromTitle(fileName);
  final String filePath = AppStoragePaths.bookSourcePath(bookId);
  final file = File(filePath);

  if (await file.exists()) {
    return file;
  } else {
    print('الملف "$fileName" لم يتم العثور عليه في مخزن الكتب.');
    return null;
  }
}
