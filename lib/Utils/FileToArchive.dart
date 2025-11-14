

import 'dart:io';
import 'package:archive/archive.dart';

Future<Archive> FileToArchive(String? filePath) async {
  if (filePath == null) {
    print("FileToArchive Error: Received null file path.");
    return Archive();
  }

  print("FileToArchive: Processing file '$filePath'");

  try {
    final bytes = await File(filePath).readAsBytes();
    print("FileToArchive: Successfully read ${bytes.length} bytes from '$filePath'");
    return ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    print("FileToArchive CRITICAL ERROR: Failed to read or decode file '$filePath'. Exception: $e");
    // Return an empty archive to prevent crashing the whole process
    return Archive();
  }
}