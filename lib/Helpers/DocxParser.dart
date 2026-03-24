import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Utils/ArchiveToXml.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:path/path.dart' as p;
import 'package:golden_shamela/core/app_state.dart';
import 'package:xml/xml.dart';

/// A helper class to encapsulate the logic for parsing a .docx file.
class DocxParser {
  /// Parses a .docx file from the given [filePath] and returns a list of [WordPage] objects.
  static Future<List<WordPage>> parse(String filePath) async {
    try {
      // Create a temporary WordDocument object to pass to the parser.
      WordDocument tempDocument = WordDocument();
      tempDocument.title = p.basename(filePath);

      // Use the existing project functions to convert file to archive and parse data.
      final appState = AppState();
      appState.docArchive = await FileToArchive(filePath);
      tempDocument.archive =
          appState.docArchive; // Store archive in document instance
      List<WordPage> parsedPages = await AddDocData(
        appState.docArchive,
        tempDocument,
      );

      if (parsedPages.isEmpty) {
        print(
          "DocxParser Warning: AddDocData returned 0 pages for file: $filePath. The file might be empty, corrupted, or in an unsupported format.",
        );
      }

      return parsedPages;
    } catch (e) {
      print("Error parsing .docx file at $filePath: $e");
      rethrow;
    }
  }

  /// Extracts metadata (title, creator) from a .docx file.
  static Future<Map<String, String>> extractMetadata(String filePath) async {
    try {
      final archive = await FileToArchive(filePath);
      final archiveMap = archive.toMap();
      final coreXmlFile = archiveMap['docProps/core.xml'];

      if (coreXmlFile == null) return {};

      final document = ArchiveToXml(coreXmlFile);

      // Look for dc:title and dc:creator (author)
      final title =
          document.findAllElements('dc:title').firstOrNull?.innerText ?? '';
      final creator =
          document.findAllElements('dc:creator').firstOrNull?.innerText ?? '';

      return {'title': title, 'creator': creator};
    } catch (e) {
      print("DocxParser: Error extracting metadata from $filePath: $e");
      return {};
    }
  }
}
