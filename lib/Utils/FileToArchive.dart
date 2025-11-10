

import 'dart:io';

import 'package:archive/archive.dart';

Future<Archive> FileToArchive(String filePath) async{
  File file = File(filePath!);
  List<int> bytes = await file.readAsBytes();

  // Decode the DOCX file (which is a ZIP archive)
  Archive archive = ZipDecoder().decodeBytes(bytes);
  return archive;
}