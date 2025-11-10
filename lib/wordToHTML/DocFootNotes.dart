import 'package:archive/archive.dart';
import 'package:golden_shamela/Utils/XmlElementClone.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/FootNote.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:xml/xml.dart';

import '../Utils/ArchiveToXml.dart';

const WORD_FOOTNOTES = "word/footnotes.xml";

Map<String, FootNote> addFootNotes(ArchiveFile? archiveFile,WordDocument wordDocument) {

  if(archiveFile==null) return {};
  // تحويل ArchiveFile إلى XmlDocument
  Map<String, FootNote> docFootNotes = {};

  XmlDocument document = ArchiveToXml(archiveFile);

  // استعراض جميع العناصر داخل المستند
  document.getElement("w:footnotes")?.childElements.forEach((fn) {
      String id = fn.getAttribute("w:id")!;
      XmlElement xmlPar = fn.getElement("w:p")!;
      WordPage wordPage = WordPage(wordDocument);
      Paragraph paragraph = Paragraph(wordPage).fromXml(xmlPar);
      FootNote footNote = FootNote(paragraph, id);
      docFootNotes[id]= footNote;
  });
  return docFootNotes;

}
