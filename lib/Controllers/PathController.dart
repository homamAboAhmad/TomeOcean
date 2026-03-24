import 'package:golden_shamela/Constants.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

String DOCUMENTS_PATH = getAssetsPath();
String BOOKS_FOLDER_PATH = getBooksFolderPath();
String PROCESSING_TEMP_PATH = getProcessingTempPath();
const BOOKS_FOLDER_NAME = 'المكتبة';
const TEMP_FOLDER_NAME = '.temp_processing';

String getBooksFolderPath() {
  print("dp: $DOCUMENTS_PATH");
  return '${DOCUMENTS_PATH}\\${BOOKS_FOLDER_NAME}';
}

String getProcessingTempPath() {
  return '${DOCUMENTS_PATH}\\${TEMP_FOLDER_NAME}';
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
  await checkBooksFolderPath();
  await checkProcessingTempPath();
}

Future<String> getDocumentsPath() async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  return documentsDirectory.path;
}

checkBooksFolderPath() async {
  final booksDir = Directory(BOOKS_FOLDER_PATH);
  if (!await booksDir.exists()) {
    await booksDir.create(recursive: true);
  }
}

checkProcessingTempPath() async {
  final tempDir = Directory(PROCESSING_TEMP_PATH);
  if (!await tempDir.exists()) {
    await tempDir.create(recursive: true);
  }
}
