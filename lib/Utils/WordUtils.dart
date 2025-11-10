import 'package:golden_shamela/Controllers/IndexController.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/FootNote.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:xml/xml.dart';

import '../wordToHTML/ParagraphTable.dart';
import '../wordToHTML/SectPr.dart';
import 'TxtUtils.dart';
import 'XmlParagraphExtractor.dart';


class WordUtils {
  WordDocument wordDocument;
  late IndexController indexController=IndexController(wordDocument);
  WordUtils(this.wordDocument);
  XmlElement? getWordBody(XmlDocument document) {
    return document.getElement("w:document")?.getElement("w:body");
  }

  addParagraphToDocument(XmlElement? body) async {
    wordDocument.pages.clear();
    List<XmlElement> allPs = getAllXmlParagraphs(body);

    int j = 1;
    while (allPs.isNotEmpty) {
      WordPage wordPage = await getPage(allPs, pageNum: j);
      wordDocument.pages.add(wordPage);
      // print("pageNumber $j");

      j++;
    }
  }

  getPage(List<XmlElement> allPs, { required int pageNum}) async {
    List<XmlElement> pagePs = getPageXmlPs(allPs);
    WordPage wordPage = WordPage(wordDocument);
    wordPage.parent = wordDocument;
    addPsToPage(wordPage, pagePs,pageNum: pageNum);
    addFnToPage(wordPage);
    await Future.delayed(Duration(milliseconds: 200), () {});
    return wordPage;
  }

  void addFnToPage(WordPage wordPage) {
    int i = 1;
    for (Paragraph p in wordPage.ps) {
      for (runT run in p.runs) {
        if (run.footNoteId != null) {
          FootNote? footNote = wordDocument.docFootNotes[run.footNoteId];
          footNote?.updateDisplayNumber(i.toString());
          run.fnDisplayNum = i.toString();
          run.updateFnDisplayNumber();
          if (footNote != null) wordPage.fns.add(footNote);
          i++;
        }
      }
    }
  }

  addPsToPage(WordPage wordPage, List<XmlElement> pagePs,{required int pageNum}) {
    for (XmlElement element in pagePs) {
      if (isSectPr(element)) {
        wordDocument.addSectPr(element);
      }
      if (element.name.local == "p") {
        indexController.addIndexIfExisted(element, pageNum);
        wordPage.addParagraph(element);
      } else if (element.name.local == "tbl")
        addTableToPage(wordPage, element);
    }
  }

  List<XmlElement> getPageXmlPs(List<XmlElement> allPs) {
    XmlElement? element2;
    int k = 0;
    List<XmlElement> pagePs = [];
    int brs = 0;
    for (int i = 0; i < allPs.length; i++) {
      XmlElement element = allPs[i];
      XmlElement? nextElement = i + 1 < allPs.length ? allPs[i + 1] : null;

      if (hasLastRender(element, nextElement: nextElement) && i > 0) break;
      pagePs.add(element);
      k++;
      if (hasBrPage(element, nextElement: nextElement)) break;
    }
    // for (XmlElement element in allPs) {
    //   // print(hasBr(element));
    //   // print("addElement $k");
    //   if (hasBr(element,)) brs++;
    //   if (brs > 1) break;
    //   pagePs.add(element);
    //   k++;
    // }
    updateAllPs(allPs, k, element2);

    return pagePs;
  }

  void updateAllPs(List<XmlElement> allPs, int i, XmlElement? element2) {
    allPs.removeRange(0, i);
    if (element2 != null) {
      allPs.insert(0, element2);
    }
  }

  bool isLastPageLine(XmlElement element) {
    return element.getAttribute("isLastPageLine") == "true";
  }

  void addTableToPage(WordPage wordPage, XmlElement element) {
    //print("table body: \n${element.toXmlString(pretty: true)}");
    ParagraphTable paragraph = ParagraphTable(wordPage);
    paragraph.fromXml(element);
    wordPage.ps.add(paragraph);
    element.text.split("\n").forEach((rowTxt) {
      ParagraphTable paragraph = ParagraphTable(wordPage);
      runT r = runT(paragraph,prPr: null, pPr: null);
      r.parent = paragraph;
      paragraph.text = rowTxt;
      r.text = rowTxt;

      paragraph.runs.add(r);
      //  print(paragraph.toHTML());
      wordPage.ps.add(paragraph);
    });

  }

  bool isFromPage(String pc, XmlElement element) {
    bool contains = removeDiacriticsAndSpaces(pc)
        .contains(removeDiacriticsAndSpaces(element.text));
    if (contains) return true;

    return false;
  }

  XmlElement? getFontScheme(XmlDocument document) {
    return document
        .getElement("a:theme")
        ?.getElement("a:themeElements")
        ?.getElement("a:fontScheme");
  }

  String? getAutoDarkColor(XmlDocument document) {
    return document
        .getElement("a:theme")
        ?.getElement("a:themeElements")
        ?.getElement("a:clrScheme")
        ?.getElement("a:dk1")
        ?.getElement("a:sysClr")
        ?.getAttribute("lastClr");
  }

  String? getAutoLightColor(XmlDocument document) {
    return document
        .getElement("a:theme")
        ?.getElement("a:themeElements")
        ?.getElement("a:clrScheme")
        ?.getElement("a:lt1")
        ?.getElement("a:sysClr")
        ?.getAttribute("lastClr");
  }

  String? getMajorFont(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:majorFont")
        ?.getElement("a:latin")
        ?.getAttribute("typeface");
  }

  String? getMinorFont(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:minorFont")
        ?.getElement("a:latin")
        ?.getAttribute("typeface");
  }
}

bool hasLastRender(XmlElement element, {required XmlElement? nextElement}) {
  int brL = element.findAllElements("w:lastRenderedPageBreak").length;
  if (brL > 0)
    return true;
  else
    return false;
}

bool hasBrPage(XmlElement element, {required XmlElement? nextElement}) {
  bool nextHasBrL =
      nextElement?.findAllElements("w:lastRenderedPageBreak").isNotEmpty ??
          false;
  if (nextHasBrL) return false;
  List<XmlElement> brs = element.findAllElements("w:br").toList();
  if (brs.isEmpty) return false;

  bool hasBrPage = false;
  for (XmlElement br in brs) {
    if (br.getAttribute("w:type") == "page") {
      hasBrPage = true;
      break;
    }
  }
  return hasBrPage;
}
