import 'dart:math';

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
  late IndexController indexController = IndexController(wordDocument);
  WordUtils(this.wordDocument);
  XmlElement? getWordBody(XmlDocument document) {
    return document.getElement("w:document")?.getElement("w:body");
  }

  Future<List<WordPage>> addParagraphToDocument(
    XmlElement? body, {
    Function(int current, int total)? onProgress,
  }) async {
    List<WordPage> pages = [];
    List<XmlElement> allPs = getAllXmlParagraphs(body);
    final totalParagraphs = allPs.length;

    if (allPs.isEmpty) {
      throw Exception("No paragraphs found in document body.");
    }

    int j = 1;
    while (allPs.isNotEmpty) {
      WordPage wordPage = await getPage(allPs, pageNum: j);
      pages.add(wordPage);

      int processed = totalParagraphs - allPs.length;
      onProgress?.call(processed, totalParagraphs);

      j++;
    }
    return pages;
  }

  getPage(List<XmlElement> allPs, {required int pageNum}) async {
    try {
      List<XmlElement> pagePs = getPageXmlPs(allPs);
      WordPage wordPage = WordPage(wordDocument);
      wordPage.parent = wordDocument;
      addPsToPage(wordPage, pagePs, pageNum: pageNum);
      addFnToPage(wordPage);
      await Future.delayed(Duration(milliseconds: 200), () {});
      return wordPage;
    } catch (e, s) {
      rethrow;
    }
  }

  void addFnToPage(WordPage wordPage) {
    int i = 1;
    for (Paragraph p in wordPage.ps) {
      for (int runIndex = 0; runIndex < p.runs.length; runIndex++) {
        runT run = p.runs[runIndex];
        if (run.footNoteId != null) {
          FootNote? footNote = wordDocument.docFootNotes[run.footNoteId];
          footNote?.updateDisplayNumber(i.toString());
          run.fnDisplayNum = i.toString();
          run.updateFnDisplayNumber();
          if (footNote != null) wordPage.fns.add(footNote);

          String openParen = "";
          String closeParen = "";

          if (runIndex > 0) {
            runT prevRun = p.runs[runIndex - 1];
            if (prevRun.text == "(" &&
                prevRun.rpr?.vertAlign == "superscript") {
              openParen = "(";
              prevRun.text = "";
            }
          }
          if (runIndex < p.runs.length - 1) {
            runT nextRun = p.runs[runIndex + 1];
            if (nextRun.text == ")" &&
                nextRun.rpr?.vertAlign == "superscript") {
              closeParen = ")";
              nextRun.text = "";
            }
          }

          if (openParen.isNotEmpty || closeParen.isNotEmpty) {
            run.text = openParen + (run.text ?? "") + closeParen;
          }

          i++;
        }
      }
    }
  }

  addPsToPage(
    WordPage wordPage,
    List<XmlElement> pagePs, {
    required int pageNum,
  }) {
    wordPage.pageIndex = pageNum;
    for (XmlElement element in pagePs) {
      if (isSectPr(element)) {
        wordDocument.addSectPr(element, currentPageNum: pageNum);
      }
      if (element.name.local == "p") {
        indexController.addIndexIfExisted(element, pageNum);
        wordPage.addParagraph(element);
      } else if (element.name.local == "tbl")
        addTableToPage(wordPage, element);
    }
  }

  List<XmlElement> getPageXmlPs(List<XmlElement> allPs) {
    XmlElement? remainingParagraph;
    int k = 0;
    List<XmlElement> pagePs = [];

    // Working in logical pixels (dp) is easier since Flutter uses dp
    double pageHeightDp = wordDocument.sectpr?.height ?? 842;
    double pageMarginDp =
        (wordDocument.sectpr?.topMargin ?? 56) +
        (wordDocument.sectpr?.bottomMargin ?? 56);
    double availableHeightDp = pageHeightDp - pageMarginDp;

    double currentContentHeight = 0;

    for (int i = 0; i < allPs.length; i++) {
      XmlElement element = allPs[i];
      XmlElement? nextElement = i + 1 < allPs.length ? allPs[i + 1] : null;

      bool isTocItem = element.getAttribute("isSdtRow") == "True";

      if (element.name.local == "tbl") {
        var tableBreakInfo = getTableBreakPosition(element);

        if (tableBreakInfo != null) {
          String? position = tableBreakInfo["position"] as String;

          if (position == "start" && i > 0) {
            break;
          } else if (position == "middle") {
            var splitResult = splitTableAtPageBreak(element);
            if (splitResult != null) {
              pagePs.add(splitResult['before']!);
              k++;
              remainingParagraph = splitResult['after'];
              break;
            }
          } else if (position == "first_row") {
            if (i > 0) {
              break;
            }
          }
        }

        // If no split determined by Word, add full table
        pagePs.add(element);
        k++;
        continue;
      }

      String breakPosition = getLastRenderBreakPosition(element);

      if (breakPosition == "start" && i > 0) {
        break;
      } else if (breakPosition == "middle") {
        var splitResult = splitParagraphAtBreak(element);
        if (splitResult != null) {
          pagePs.add(splitResult['before']!);
          k++;
          remainingParagraph = splitResult['after'];
          break;
        }
      }

      if (isTocItem) {
        double itemHeight = 30.0;
        var rPr = element.findAllElements("w:rPr").firstOrNull;
        if (rPr != null) {
          var sz = rPr.findAllElements("w:sz").firstOrNull;
          if (sz != null) {
            var val = double.tryParse(sz.getAttribute("w:val") ?? "28");
            if (val != null) {
              double fontSizePt = val / 2;
              itemHeight = fontSizePt * 2.1;
              if (fontSizePt > 24) {
                itemHeight += 40;
              }
            }
          }
        }

        currentContentHeight += itemHeight;
        double safetyMargin = 50.0;

        if (currentContentHeight > (availableHeightDp - safetyMargin) &&
            k > 0) {
          if (nextElement != null &&
              nextElement.getAttribute("isSdtRow") == "True") {
            break;
          }
        }
      }

      pagePs.add(element);
      k++;

      var brPageResult = splitParagraphAtBrPage(element);
      if (brPageResult != null) {
        pagePs.removeLast();
        pagePs.add(brPageResult['before']!);

        var afterParagraph = brPageResult['after'];
        if (afterParagraph != null) {
          bool hasContent = afterParagraph.findElements("w:r").isNotEmpty;
          if (hasContent) {
            remainingParagraph = afterParagraph;
          }
        }

        if (nextElement != null && isEmptySectPrParagraph(nextElement)) {
          pagePs.add(nextElement);
          k++;
        }

        break;
      }

      if (hasBrPage(element, nextElement: nextElement)) {
        if (nextElement != null && isEmptySectPrParagraph(nextElement)) {
          pagePs.add(nextElement);
          k++;
        }
        break;
      }

      if (isSectPr(element)) {
        break;
      }

      if (hasFullPageImage(element, wordDocument)) break;
    }

    updateAllPs(allPs, k, remainingParagraph);

    return pagePs;
  }

  void updateAllPs(
    List<XmlElement> allPs,
    int i,
    XmlElement? remainingParagraph,
  ) {
    allPs.removeRange(0, i);
    if (remainingParagraph != null) {
      allPs.insert(0, remainingParagraph);
    }
  }

  bool isLastPageLine(XmlElement element) {
    return element.getAttribute("isLastPageLine") == "true";
  }

  void addTableToPage(WordPage wordPage, XmlElement element) {
    ParagraphTable paragraph = ParagraphTable(wordPage);
    paragraph.fromXml(element);
    wordPage.ps.add(paragraph);
  }

  bool isFromPage(String pc, XmlElement element) {
    bool contains = removeDiacriticsAndSpaces(
      pc,
    ).contains(removeDiacriticsAndSpaces(element.text));
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

  String? getMajorFontCS(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:majorFont")
        ?.getElement("a:cs")
        ?.getAttribute("typeface");
  }

  String? getMinorFontCS(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:minorFont")
        ?.getElement("a:cs")
        ?.getAttribute("typeface");
  }

  bool isEmptySectPrParagraph(XmlElement element) {
    if (element.name.local != "p") return false;
    if (!isSectPr(element)) return false;

    bool hasContent = element.descendants.any((node) {
      if (node is XmlElement) {
        if (node.name.local == "t" && node.text.isNotEmpty) return true;
        if (node.name.local == "drawing") return true;
        if (node.name.local == "object") return true;
      }
      return false;
    });

    return !hasContent;
  }
}

String _toArabicNumerals(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String result = input;
  for (int i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], arabicIndic[i]);
  }
  return result;
}

int? _getRowPageNum(XmlElement row) {
  var allCells = row.findElements("w:tc").toList();
  if (allCells.isNotEmpty) {
    var firstCellText = allCells.first.text;
    var match = RegExp(r"\{\{PG:(\d+)\}\}").firstMatch(firstCellText);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }
  return null;
}

Map<String, dynamic>? getTableBreakPosition(XmlElement table) {
  var allRows = table.findElements("w:tr").toList();
  int? startPageNum;

  for (int rowIndex = 0; rowIndex < allRows.length; rowIndex++) {
    var row = allRows[rowIndex];

    // Skip header rows - their {{PG:X}} values are from the original document
    // and don't reflect where they'll appear in split tables
    var trPr = row.getElement("w:trPr");
    bool isHeaderRow = trPr != null && trPr.getElement("w:tblHeader") != null;
    if (isHeaderRow) {
      continue;
    }

    // Check for PG marker first - this is the authoritative source
    int? pageNum = _getRowPageNum(row);
    if (pageNum != null) {
      if (startPageNum == null) {
        startPageNum = pageNum;
      } else if (pageNum > startPageNum) {
        if (rowIndex == 0) {
          return {"rowIndex": rowIndex, "position": "first_row"};
        }
        return {"rowIndex": rowIndex, "position": "middle"};
      }
      // If row has PG marker and it matches current page, skip lastRenderedPageBreak check
      // because PG marker is authoritative - lastRenderedPageBreak inside this row
      // just means Word rendered part of the row on the next visual page, but the
      // row still belongs to this page according to Word's pagination
      continue;
    }

    // Only check lastRenderedPageBreak if no PG marker was found for this row
    var breaks = row.findAllElements("w:lastRenderedPageBreak").toList();
    if (breaks.isNotEmpty) {
      // Special case: row 0 with lastRenderedPageBreak is ALWAYS inherited from a previous split
      // Skip it entirely
      if (rowIndex == 0) {
        continue; // Skip to row 1+
      }

      // Normal lastRenderedPageBreak handling for rows > 0 (without PG markers)
      bool foundTextBefore = false;
      var allCells = row.findElements("w:tc").toList();

      for (var cell in allCells) {
        var paragraphs = cell.findElements("w:p").toList();
        for (var p in paragraphs) {
          var runs = p.findElements("w:r").toList();
          for (var run in runs) {
            var children = run.childElements.toList();
            for (var child in children) {
              if (child.name.local == "lastRenderedPageBreak") {
                if (!foundTextBefore && rowIndex > 0) {
                  return {"rowIndex": rowIndex, "position": "start"};
                } else if (foundTextBefore) {
                  return {"rowIndex": rowIndex, "position": "middle"};
                }
              } else if (child.name.local == "t" && child.text.isNotEmpty) {
                foundTextBefore = true;
              }
            }
          }
        }
      }
    }
  }
  return null;
}

Map<String, XmlElement>? splitTableAtPageBreak(XmlElement table) {
  var breakInfo = getTableBreakPosition(table);
  if (breakInfo == null) return null;

  int rowIndex = breakInfo["rowIndex"] as int;

  return splitTableAtIndex(table, rowIndex);
}

String getLastRenderBreakPosition(XmlElement element) {
  int brL = element.findAllElements("w:lastRenderedPageBreak").length;
  if (brL == 0) return "none";

  var allRuns = element.findElements("w:r").toList();
  bool foundTextBefore = false;

  for (int runIndex = 0; runIndex < allRuns.length; runIndex++) {
    var run = allRuns[runIndex];
    var children = run.childElements.toList();

    for (var child in children) {
      if (child.name.local == "lastRenderedPageBreak") {
        if (!foundTextBefore) {
          return "start";
        } else {
          return "middle";
        }
      } else if (child.name.local == "t" && child.text.isNotEmpty) {
        foundTextBefore = true;
      }
    }
  }

  return "none";
}

Map<String, XmlElement>? splitParagraphAtBreak(XmlElement paragraph) {
  try {
    var pPr = paragraph.getElement("w:pPr");
    String pPrXml = pPr?.toXmlString() ?? "";

    List<String> runsBefore = [];
    List<String> runsAfter = [];
    bool foundBreak = false;

    var allRuns = paragraph.childElements
        .where((e) => e.name.local == "r")
        .toList();

    for (var run in allRuns) {
      if (!foundBreak) {
        var breakElement = run
            .findElements("w:lastRenderedPageBreak")
            .firstOrNull;

        if (breakElement != null) {
          foundBreak = true;
          var splitRun = splitRunAtBreak(run);
          if (splitRun['before'] != null && splitRun['before']!.isNotEmpty) {
            runsBefore.add(splitRun['before']!);
          }
          if (splitRun['after'] != null && splitRun['after']!.isNotEmpty) {
            runsAfter.add(splitRun['after']!);
          }
        } else {
          runsBefore.add(run.toXmlString());
        }
      } else {
        runsAfter.add(run.toXmlString());
      }
    }

    if (!foundBreak) return null;

    String beforeXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsBefore.join()}</w:p>';
    String afterXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsAfter.join()}</w:p>';

    var beforeDoc = XmlDocument.parse(beforeXml);
    var afterDoc = XmlDocument.parse(afterXml);

    return {'before': beforeDoc.rootElement, 'after': afterDoc.rootElement};
  } catch (e) {
    return null;
  }
}

Map<String, String?> splitRunAtBreak(XmlElement run) {
  var rPr = run.getElement("w:rPr");
  String rPrXml = rPr?.toXmlString() ?? "";

  List<String> contentBefore = [];
  List<String> contentAfter = [];
  bool foundBreak = false;

  for (var child in run.childElements) {
    if (child.name.local == "lastRenderedPageBreak") {
      foundBreak = true;
      continue;
    }

    if (child.name.local == "rPr") continue;

    if (!foundBreak) {
      contentBefore.add(child.toXmlString());
    } else {
      contentAfter.add(child.toXmlString());
    }
  }

  String? beforeRun = contentBefore.isNotEmpty
      ? '<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$rPrXml${contentBefore.join()}</w:r>'
      : null;
  String? afterRun = contentAfter.isNotEmpty
      ? '<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$rPrXml${contentAfter.join()}</w:r>'
      : null;

  return {'before': beforeRun, 'after': afterRun};
}

Map<String, XmlElement>? splitParagraphAtBrPage(XmlElement paragraph) {
  try {
    List<XmlElement> brs = paragraph.findAllElements("w:br").toList();
    bool hasBrPage = brs.any((br) => br.getAttribute("w:type") == "page");
    if (!hasBrPage) return null;

    var pPr = paragraph.getElement("w:pPr");
    String pPrXml = pPr?.toXmlString() ?? "";

    List<String> runsBefore = [];
    List<String> runsAfter = [];
    bool foundBreak = false;

    var allRuns = paragraph.childElements
        .where((e) => e.name.local == "r")
        .toList();

    for (var run in allRuns) {
      if (!foundBreak) {
        var breakElements = run.findElements("w:br").toList();
        var pageBreak = breakElements
            .where((br) => br.getAttribute("w:type") == "page")
            .firstOrNull;

        if (pageBreak != null) {
          foundBreak = true;
          var splitRun = splitRunAtBrPage(run);
          if (splitRun['before'] != null && splitRun['before']!.isNotEmpty) {
            runsBefore.add(splitRun['before']!);
          }
          if (splitRun['after'] != null && splitRun['after']!.isNotEmpty) {
            runsAfter.add(splitRun['after']!);
          }
        } else {
          runsBefore.add(run.toXmlString());
        }
      } else {
        runsAfter.add(run.toXmlString());
      }
    }

    if (!foundBreak) return null;

    String beforeXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsBefore.join()}</w:p>';
    String afterXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsAfter.join()}</w:p>';

    var beforeDoc = XmlDocument.parse(beforeXml);
    var afterDoc = XmlDocument.parse(afterXml);

    return {'before': beforeDoc.rootElement, 'after': afterDoc.rootElement};
  } catch (e) {
    return null;
  }
}

Map<String, String?> splitRunAtBrPage(XmlElement run) {
  var rPr = run.getElement("w:rPr");
  String rPrXml = rPr?.toXmlString() ?? "";

  List<String> contentBefore = [];
  List<String> contentAfter = [];
  bool foundBreak = false;

  for (var child in run.childElements) {
    if (child.name.local == "br" && child.getAttribute("w:type") == "page") {
      foundBreak = true;
      continue;
    }

    if (child.name.local == "rPr") continue;

    if (!foundBreak) {
      contentBefore.add(child.toXmlString());
    } else {
      contentAfter.add(child.toXmlString());
    }
  }

  String? beforeRun = contentBefore.isNotEmpty
      ? '<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$rPrXml${contentBefore.join()}</w:r>'
      : null;
  String? afterRun = contentAfter.isNotEmpty
      ? '<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$rPrXml${contentAfter.join()}</w:r>'
      : null;

  return {'before': beforeRun, 'after': afterRun};
}

bool hasLastRender(XmlElement element, {required XmlElement? nextElement}) {
  return getLastRenderBreakPosition(element) == "start";
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

bool hasFullPageImage(XmlElement element, WordDocument wordDocument) {
  double pageHeightEmu = 10692000;

  if (wordDocument.sectpr?.height != null && wordDocument.sectpr!.height! > 0) {
    pageHeightEmu = wordDocument.sectpr!.height! * 9525;
  }

  Iterable<XmlElement> anchors = element.findAllElements("wp:anchor");
  for (XmlElement anchor in anchors) {
    String? behindDoc = anchor.getAttribute("behindDoc");
    if (behindDoc == "1") continue;

    XmlElement? extent = anchor.getElement("wp:extent");
    if (extent != null) {
      String? cyStr = extent.getAttribute("cy");
      if (cyStr != null) {
        double cy = double.tryParse(cyStr) ?? 0;
        if (cy >= pageHeightEmu * 0.85) {
          return true;
        }
      }
    }
  }
  return false;
}

Map<String, XmlElement>? splitTableAtIndex(XmlElement table, int splitIndex) {
  var allRows = table.findElements("w:tr").toList();
  if (splitIndex >= allRows.length || splitIndex <= 0) return null;

  var tblPr = table.getElement("w:tblPr");
  var tblGrid = table.getElement("w:tblGrid");
  String tblPrXml = tblPr?.toXmlString() ?? "";
  String tblGridXml = tblGrid?.toXmlString() ?? "";

  List<XmlElement> headerRows = [];
  for (var row in allRows) {
    var trPr = row.getElement("w:trPr");
    if (trPr != null && trPr.getElement("w:tblHeader") != null) {
      headerRows.add(row);
    } else {
      break;
    }
  }

  List<String> rowsBeforeXml = [];
  List<String> rowsAfterXml = [];

  for (int i = 0; i < allRows.length; i++) {
    if (i < splitIndex) {
      rowsBeforeXml.add(allRows[i].toXmlString());
    } else {
      rowsAfterXml.add(allRows[i].toXmlString());
    }
  }

  if (rowsBeforeXml.isEmpty || rowsAfterXml.isEmpty) return null;

  if (headerRows.isNotEmpty && splitIndex > headerRows.length) {
    List<String> headerXml = headerRows.map((r) => r.toXmlString()).toList();
    rowsAfterXml = [...headerXml, ...rowsAfterXml];
  }

  try {
    String beforeXml =
        '<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$tblPrXml$tblGridXml${rowsBeforeXml.join()}</w:tbl>';
    String afterXml =
        '<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$tblPrXml$tblGridXml${rowsAfterXml.join()}</w:tbl>';

    var beforeDoc = XmlDocument.parse(beforeXml);
    var afterDoc = XmlDocument.parse(afterXml);
    return {'before': beforeDoc.rootElement, 'after': afterDoc.rootElement};
  } catch (e) {
    return null;
  }
}
