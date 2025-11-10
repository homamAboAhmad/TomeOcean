import 'package:archive/archive.dart';
import 'package:golden_shamela/Utils/ArchiveToXml.dart';
import 'package:golden_shamela/Models/WordDocument.dart';

import 'DocFonts.dart';
import 'DocFootNotes.dart';
import 'DocNumbering.dart';
import 'DocPages.dart';
import 'DocRelations.dart';
import 'DocTheme.dart';
import 'DocumentDefaults.dart';
import 'DocumentStyles.dart';
import 'ExtractWordImages.dart';

AddDocData( Archive archive,WordDocument wordDocument) async {
  Map<String, ArchiveFile> archiveMap = archive.toMap();
  wordDocument.docImages=  await extractImagesFromDocx(archiveMap);
  wordDocument.relIdList = addDocRelations(archiveMap);
  wordDocument.fontsList = addDocFonts(archiveMap[WORD_FONTS_TABLE]);
  addDefaults(archiveMap[WORD_STYLES],wordDocument);
  addTheme1(archiveMap[WORD_THEME1],wordDocument);
  List<Map?> numberingMap = addNumbering(archiveMap[WORD_NUMBERING]);
  wordDocument.abstractNumMap = numberingMap[0]!.cast();
  wordDocument.numsMap = numberingMap[1]!.cast();
  wordDocument.documentStyles = addStyles(archiveMap[WORD_STYLES]);
  wordDocument.docFootNotes = addFootNotes(archiveMap[WORD_FOOTNOTES],wordDocument);
  await addWordPages(archiveMap[WORD_DOCUMENT]!,wordDocument);
}
