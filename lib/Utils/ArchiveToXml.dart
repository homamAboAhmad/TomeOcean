
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const WORD_DOCUMENT = "word/document.xml";
const WORD_THEME1 = "word/theme/theme1.xml";
const WORD_NUMBERING = "word/numbering.xml";

XmlDocument ArchiveToXml(ArchiveFile archiveFile) {
  String xmlContent = utf8.decode(archiveFile.content);
  return XmlDocument.parse(xmlContent);
}


extension ArchiveExts on Archive {
  Map<String, ArchiveFile> toMap() {
    Map<String, ArchiveFile> map = {};
    this.forEach((archiveFile) {
      map[archiveFile.name] = archiveFile;
    });
    return map;
  }
}