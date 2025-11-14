import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:path/path.dart' as p;

import '../main.dart';

/// A helper class to encapsulate the logic for parsing a .docx file.
class DocxParser {
  /// Parses a .docx file from the given [filePath] and returns a list of [WordPage] objects.
  ///
  /// This function isolates the core parsing logic from UI and caching concerns.
  static Future<List<WordPage>> parse(String filePath) async {
    try {
      // Create a temporary WordDocument object to pass to the parser.
      WordDocument tempDocument = WordDocument();
      tempDocument.title = p.basename(filePath);

      // Use the existing project functions to convert file to archive and parse data.
      docArchive = await FileToArchive(filePath);
      List<WordPage> parsedPages = await AddDocData(docArchive, tempDocument);

      if (parsedPages.isEmpty) {
        print("DocxParser Warning: AddDocData returned 0 pages for file: $filePath. The file might be empty, corrupted, or in an unsupported format.");
      }

      return parsedPages;
    } catch (e) {
      print("Error parsing .docx file at $filePath: $e");
      // Re-throw the exception to be handled by the caller.
      rethrow;
    }
  }
}
