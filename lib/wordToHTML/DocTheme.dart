import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../Utils/ArchiveToXml.dart';
import '../Utils/WordUtils.dart';
import '../Models/WordDocument.dart';

void addTheme1(ArchiveFile? archiveFile,WordDocument wordDocument) {
  if (archiveFile == null) return;
  WordUtils wordUtils = WordUtils(wordDocument);
  XmlDocument document = ArchiveToXml(archiveFile);
  // print(document.toXmlString(pretty: true));
  XmlElement? fontScheme = wordUtils.getFontScheme(document);
  wordDocument.majorFont = wordUtils.getMajorFont(fontScheme);
  wordDocument.minorFont = wordUtils.getMinorFont(fontScheme);
  wordDocument.autoDarkColor =
      wordUtils.getAutoDarkColor(document) ?? "000000";
  wordDocument.autoLightColor =
      wordUtils.getAutoLightColor(document) ?? "FFFFFF";

}