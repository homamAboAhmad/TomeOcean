import 'package:archive/archive.dart';
import 'package:golden_shamela/Utils/ArchiveToXml.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart'; // Import WordPage

import 'DocFonts.dart';
import 'DocFootNotes.dart';
import 'DocNumbering.dart';
import 'DocPages.dart';
import 'DocRelations.dart';
import 'DocTheme.dart';
import 'DocumentDefaults.dart';
import 'DocumentStyles.dart';
import 'ExtractWordImages.dart';

Future<List<WordPage>> AddDocData( Archive archive,WordDocument wordDocument) async {
  print("AddDocData: Starting...");
  Map<String, ArchiveFile> archiveMap = archive.toMap();
  print("AddDocData: Extracted archive map.");
  wordDocument.docImages=  await extractImagesFromDocx(archiveMap);
  print("AddDocData: Extracted images.");
  wordDocument.relIdList = addDocRelations(archiveMap);
  print("AddDocData: Added relations.");
  wordDocument.fontsList = addDocFonts(archiveMap[WORD_FONTS_TABLE]);
  print("AddDocData: Added fonts.");
  addDefaults(archiveMap[WORD_STYLES],wordDocument);
  print("AddDocData: Added defaults.");
  addTheme1(archiveMap[WORD_THEME1],wordDocument);
  print("AddDocData: Added theme.");
  List<Map?> numberingMap = addNumbering(archiveMap[WORD_NUMBERING]);
  print("AddDocData: Added numbering.");
  wordDocument.abstractNumMap = numberingMap[0]!.cast();
  wordDocument.numsMap = numberingMap[1]!.cast();
  print("AddDocData: Populated abstractNumMap and numsMap.");
  wordDocument.documentStyles = addStyles(archiveMap[WORD_STYLES]);
  print("AddDocData: Added styles.");
  wordDocument.docFootNotes = addFootNotes(archiveMap[WORD_FOOTNOTES],wordDocument);
  print("AddDocData: Added footnotes.");
  List<WordPage> pages = await addWordPages(archiveMap[WORD_DOCUMENT]!,wordDocument);
  print("AddDocData: Added word pages.");
  return pages;
}
