import 'package:golden_shamela/Constants.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'dart:io';

String DOCUMENTS_PATH = getAssetsPath();
String BOOKS_FOLDER_PATH = getBooksFolderPath();
String PROCESSING_TEMP_PATH = getProcessingTempPath();

String getBooksFolderPath() {
  return AppStoragePaths.booksStorePath;
}

String getProcessingTempPath() {
  return Directory.systemTemp.path;
}

// for test
// String getBooksFolderPath() {
//   print("dp: $DOCUMENTS_PATH");
//   return '${getAssetsPath()}\\books';
// }
getPaths() async {
  DOCUMENTS_PATH = await getDocumentsPath();
  BOOKS_FOLDER_PATH = getBooksFolderPath();
  PROCESSING_TEMP_PATH = getProcessingTempPath();
  await AppStoragePaths.ensureBaseDirectories();
  await checkBooksFolderPath();
}

Future<String> getDocumentsPath() async {
  return AppStoragePaths.dataRootPath;
}

checkBooksFolderPath() async {
  final booksDir = Directory(BOOKS_FOLDER_PATH);
  if (!await booksDir.exists()) {
    await booksDir.create(recursive: true);
  }
}

checkProcessingTempPath() async {
  // Processing is session-scoped via Directory.systemTemp.createTemp(...).
  // Kept for old call sites without creating a project .temp_processing folder.
}
