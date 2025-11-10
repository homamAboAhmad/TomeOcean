import 'package:golden_shamela/Constants.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

String DOCUMENTS_PATH = getAssetsPath();
String BOOKS_FOLDER_PATH = getBooksFolderPath();
const BOOKS_FOLDER_NAME = 'البحر المحيط';

String getBooksFolderPath() {
  print("dp: $DOCUMENTS_PATH");
  return '${DOCUMENTS_PATH}\\${BOOKS_FOLDER_NAME}';
}
// for test
// String getBooksFolderPath() {
//   print("dp: $DOCUMENTS_PATH");
//   return '${getAssetsPath()}\\books';
// }
getPaths() async {
  DOCUMENTS_PATH = await getDocumentsPath();
  BOOKS_FOLDER_PATH = getBooksFolderPath();
  await checkBooksFolderPath();
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
