import 'dart:math';
import 'package:flutter/foundation.dart';

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
import 'package:golden_shamela/Utils/XmlElementClone.dart';
import 'package:golden_shamela/Utils/TocPageInjector.dart';

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

    // === Fix: Inject Page Markers for TOC using lastRenderedPageBreak ===
    // This allows TOC to split across pages even if the Python script missed it.
    // We assume TOC starts at the current max page (or 1 if new).
    // Determining the start page is tricky. If TOC is at the beginning, it's 1.
    // If it's in the middle, we need the last page seen.
    // For now, we pass 1 as a baseline, but ideally we should track it.
    // Since this runs on `allPs` before any processing, we can rely on `TocPageInjector`
    // to find explicit pages if present in previous paragraphs.
    // However, `allPs` contains EVERYTHING.
    // Let's refine: We iterate and track page numbers.
    // Actually, `TocPageInjector` logic handles the stream. We just need to call it.
    // We start at page 1. The injector will increment as it finds breaks.
    // Optimization: If `allPs` has explicit markers in non-TOC paragraphs,
    // we should respect them. But `TocPageInjector` is designed for TOC only.
    // Let's just call it.
    TocPageInjector.injectPageMarkers(allPs, 1);
    // ====================================================================

    // === Refactoring Phase 5: Map-Based Pagination ===
    Map<int, List<XmlElement>> pagesMap = _groupParagraphsByPage(allPs);

    int maxPage = 1;
    if (pagesMap.isNotEmpty) {
      maxPage = pagesMap.keys.reduce(max);
    }

    for (int j = 1; j <= maxPage; j++) {
      List<XmlElement> pagePs = pagesMap[j] ?? [];

      WordPage wordPage = await getPage(pagePs, pageNum: j);
      pages.add(wordPage);

      onProgress?.call(j, maxPage);
    }
    return pages;
  }

  getPage(List<XmlElement> pagePs, {required int pageNum}) async {
    try {
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

          // Determine context for formatting
          // 1. Surrounding text in the main body (Paragraph p)
          bool isBodyArabic = isArabicText(p.text);

          // 2. Footnote text itself
          bool isFootnoteArabic = false;
          if (footNote != null && footNote.p.text.isNotEmpty) {
            isFootnoteArabic = isArabicText(footNote.p.text);
          }

          // Format the number for the BODY (Inline reference)
          String bodyNum = i.toString();
          if (isBodyArabic) {
            bodyNum = toArabicNumbers(bodyNum);
          }

          // Format the number for the FOOTNOTE (Bottom reference)
          String footerNum = i.toString();
          // Note: typically footnotes match the document language.
          // If the footnote text is Arabic, OR if the reference is from Arabic text (and footnote is ambiguous/short), use Arabic.
          if (isFootnoteArabic || isBodyArabic) {
            footerNum = toArabicNumbers(footerNum);
          }

          // Update Footnote at the bottom
          footNote?.updateDisplayNumber(footerNum);

          // Update Inline Reference
          run.fnDisplayNum = bodyNum;
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

  /// استخراج رقم الصفحة من {{PG:X}} marker داخل فقرة
  int? _extractPgMarkerFromParagraph(XmlElement element) {
    // تجميع النص الكامل للفقرة للتعامل مع الماركرات المقسمة على عدة runs
    // Word قد يقسم النص: run1="{{", run2="PG:25", run3="}}"
    String fullText = element
        .findAllElements("w:t")
        .map((e) => e.text)
        .join("");

    var match = RegExp(r"\{\{PG:(\d+)\}\}").firstMatch(fullText);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return null;
  }

  /// استخراج كل أرقام الصفحات من فقرة (للفقرات التي تحتوي على أكثر من marker)
  /// تُرجع قائمة من أرقام الصفحات بترتيب ظهورها
  List<int> _extractAllPgMarkersFromParagraph(XmlElement element) {
    List<int> pageNumbers = [];

    // نمر على كل الـ runs بالترتيب
    var runs = element.findAllElements("w:r").toList();
    for (var run in runs) {
      var texts = run.findAllElements("w:t");
      for (var t in texts) {
        var text = t.text ?? "";
        var matches = RegExp(r"\{\{PG:(\d+)\}\}").allMatches(text);
        for (var match in matches) {
          pageNumbers.add(int.parse(match.group(1)!));
        }
      }
    }

    return pageNumbers;
  }

  /// تقسيم فقرة تحتوي على markers متعددة إلى فقرات منفصلة
  /// تُرجع قائمة من (pageNum, XmlElement) لكل جزء
  List<MapEntry<int, XmlElement>> _splitParagraphByMarkers(XmlElement para) {
    List<MapEntry<int, XmlElement>> result = [];
    List<int> markers = _extractAllPgMarkersFromParagraph(para);

    // If no markers, treat as normal paragraph (page 1 or inherited depending on caller context, but here defaults to 1 if empty)
    if (markers.isEmpty) {
      result.add(MapEntry(1, para));
      return result;
    }

    // Get all children of the original paragraph
    var allChildren = para.children.whereType<XmlElement>().toList();

    // Find indices of markers
    List<int> markerChildIndices = [];
    for (int i = 0; i < allChildren.length; i++) {
      var child = allChildren[i];
      if (child.name.local == "r") {
        var textsJoined = child
            .findAllElements("w:t")
            .map((t) => t.text)
            .join("");
        if (textsJoined.contains(RegExp(r"\{\{PG:\d+\}\}"))) {
          markerChildIndices.add(i);
        }
      }
    }

    if (markerChildIndices.length != markers.length) {
      result.add(MapEntry(markers.first, para));
      return result;
    }

    // 1. Check for Pre-Marker Content (Inherited from Previous Page)
    int firstMarkerIdx = markerChildIndices[0];
    bool hasPreContent = false;
    for (int i = 0; i < firstMarkerIdx; i++) {
      if (allChildren[i].name.local != "pPr") {
        hasPreContent = true;
        break;
      }
    }

    if (hasPreContent) {
      // Create Inherited Part: From Start (0) to First Marker (exclusive)
      // The user wants to inject the "Previous Page" marker at the start of this part.
      // We assume the previous page is (markers[0] - 1).
      int prevPage = markers[0] > 1 ? markers[0] - 1 : 1;

      var inheritedPara = _createPartialPara(
        para,
        0,
        firstMarkerIdx,
        allChildren,
      );

      // Inject {{PG:Prev}} at the beginning of the inherited part
      _injectPageMarkerToPara(inheritedPara, prevPage);

      result.add(MapEntry(-1, inheritedPara));
    }

    // 2. Create Marker Parts (Content associated with each marker)
    // The user explicitly stated: "Keep the marker in the second copy".
    // So the range MUST START AT 'markerChildIndices[m]' (Inclusive).
    for (int m = 0; m < markers.length; m++) {
      int start = markerChildIndices[m]; // Start AT the marker
      int end = (m == markers.length - 1)
          ? allChildren.length
          : markerChildIndices[m + 1]; // End BEFORE next marker

      var partPara = _createPartialPara(para, start, end, allChildren);
      result.add(MapEntry(markers[m], partPara));
    }

    return result;
  }

  /// Helper to create a partial paragraph containing children from start to end index
  XmlElement _createPartialPara(
    XmlElement originalPara,
    int startIdx,
    int endIdx,
    List<XmlElement> allChildren,
  ) {
    var paraCopy = XmlElement(
      XmlName.fromString(originalPara.name.qualified),
      originalPara.attributes
          .map(
            (a) => XmlAttribute(XmlName.fromString(a.name.qualified), a.value),
          )
          .toList(),
      [],
    );

    // Always copy pPr if it exists (it defines style/alignment)
    var pPr = originalPara.getElement("w:pPr");
    if (pPr != null) {
      paraCopy.children.add(pPr.copy());
    }

    // Copy children in range
    for (int i = startIdx; i < endIdx; i++) {
      // Skip pPr as we already added it (if it was in the range)
      if (allChildren[i].name.local == "pPr") continue;
      paraCopy.children.add(allChildren[i].copy());
    }

    return paraCopy;
  }

  /// استخراج رقم الصفحة من جدول (أول خلية في أول صف غير header)
  int? _extractPgMarkerFromTable(XmlElement table) {
    var allRows = table.findElements("w:tr").toList();
    for (var row in allRows) {
      // تخطي صفوف الـ header
      var trPr = row.getElement("w:trPr");
      if (trPr != null && trPr.getElement("w:tblHeader") != null) {
        continue;
      }
      // البحث في أول خلية
      var firstCell = row.findElements("w:tc").firstOrNull;
      if (firstCell != null) {
        // تجميع النص الكامل للخلية
        String cellText = firstCell
            .findAllElements("w:t")
            .map((e) => e.text)
            .join("");
        var match = RegExp(r"\{\{PG:(\d+)\}\}").firstMatch(cellText);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }
    }
    return null;
  }

  /// استخراج رقم الصفحة من أي عنصر (فقرة أو جدول)
  int? _extractPgMarker(XmlElement element) {
    if (element.name.local == "tbl") {
      return _extractPgMarkerFromTable(element);
    } else {
      return _extractPgMarkerFromParagraph(element);
    }
  }

  // === Refactoring: Pagination Phase 1 (Pre-Processing) ===
  // تقوم هذه الدالة بتجهيز الفقرات:
  // 1. كشف الكسور (Splits) ومعالجتها.
  // 2. التحقق من الكسور الوهمية (Ghost Breaks).
  // 3. حقن ماركر الصفحة للجزء الثاني من الانقسام لضمان التجميع السلس.
  // === Refactoring: Pagination Phase 5 (Map-Based Approach) ===
  // === تحديث: الآن نعتمد على Python للتعامل مع فواصل الصفحات ===
  // === تحديث 2: Dart يقسم الفقرات التي تحتوي على markers متعددة ===
  Map<int, List<XmlElement>> _groupParagraphsByPage(List<XmlElement> rawPs) {
    Map<int, List<XmlElement>> pages = {};
    int currentPage = 1;

    void addToPage(int page, XmlElement element) {
      if (!pages.containsKey(page)) {
        pages[page] = [];
      }
      pages[page]!.add(element);
    }

    debugPrint("--- Start Grouping Paragraphs (Map Phase) ---");

    for (var element in rawPs) {
      // التحقق من نوع العنصر
      if (element.name.local == "p") {
        // فقرة: التحقق من وجود markers
        List<int> markers = _extractAllPgMarkersFromParagraph(element);

        if (element.getAttribute("isSdtRow") == "True") {
          debugPrint(
            "DEBUG SDT ROW: Markers: $markers. CurrentPage: $currentPage. Text: ${element.text.substring(0, element.text.length > 30 ? 30 : element.text.length)}",
          );
        }

        if (markers.isNotEmpty) {
          // الفقرة تحتوي على markers (واحد أو أكثر) - نقسمها لضمان فصل المحتوى السابق
          var splitParts = _splitParagraphByMarkers(element);
          debugPrint(
            "DEBUG: Split Paragraph into ${splitParts.length} parts. Markers: $markers",
          );

          for (var part in splitParts) {
            int targetPage = part.key;
            int finalTargetPage = targetPage;

            // -1 Indicates "Inherited" content (belongs to previous page)
            if (targetPage == -1) {
              finalTargetPage = currentPage;
              debugPrint(
                "  Part INHERITED -> assigned to Page $finalTargetPage",
              );
            } else {
              // Explicit page marker, switch current page
              currentPage = targetPage;
              finalTargetPage = targetPage;
              debugPrint(
                "  Part MARKER ($targetPage) -> assigned to Page $finalTargetPage",
              );
            }
            addToPage(finalTargetPage, part.value);
          }
        } else {
          // فقرة عادية بدون markers
          addToPage(currentPage, element);
        }
      } else {
        // جدول أو عنصر آخر
        int? markerPage = _extractPgMarker(element);
        if (markerPage != null) {
          currentPage = markerPage;
        }
        addToPage(currentPage, element);
      }

      // Legacy manual increment removed. We now trust {{PG:X}} markers exclusively.
      // if (isSectPr(element) || hasFullPageImage(element, wordDocument)) {
      //   currentPage++;
      // }
    }

    debugPrint("--- End Grouping: Mapped ${pages.keys.length} pages ---");
    return pages;
  }

  // دالة مساعدة لحقن الماركر في الفقرة
  void _injectPageMarkerToPara(XmlElement para, int pageNum) {
    // Check existing
    if (_extractPgMarker(para) != null) {
      debugPrint("Marker {{PG:$pageNum}} already exists, skipping injection.");
      return;
    }

    var runs = para.findAllElements('w:r');
    if (runs.isNotEmpty) {
      var firstRun = runs.first;
      var t = firstRun.findAllElements('w:t').firstOrNull;
      if (t != null) {
        String newText = "{{PG:$pageNum}}${t.text}";
        t.children.clear();
        t.children.add(XmlText(newText));
        debugPrint("Injected {{PG:$pageNum}} into existing run.");
      } else {
        firstRun.children.insert(
          0,
          XmlElement(XmlName('w:t'), [], [XmlText("{{PG:$pageNum}}")]),
        );
        debugPrint("Injected {{PG:$pageNum}} into new w:t in existing run.");
      }
    } else {
      // Create Run if missing
      para.children.add(
        XmlElement(XmlName('w:r'), [], [
          XmlElement(XmlName('w:t'), [], [XmlText("{{PG:$pageNum}}")]),
        ]),
      );
      debugPrint("Injected {{PG:$pageNum}} into new run.");
    }
  }

  /// تقسيم الفقرة إلى جزئين عند lastRenderedPageBreak
  Map<String, XmlElement>? splitParagraphAtRenderedBreak(XmlElement para) {
    if (para.findAllElements("w:lastRenderedPageBreak").isEmpty) return null;

    XmlElement para1 = XmlElement(
      XmlName.fromString(para.name.toXmlString()),
      para.attributes
          .map(
            (attr) => XmlAttribute(
              XmlName.fromString(attr.name.toXmlString()),
              attr.value,
            ),
          )
          .toList(),
      [],
      para.isSelfClosing,
    );

    XmlElement para2 = XmlElement(
      XmlName.fromString(para.name.toXmlString()),
      para.attributes
          .map(
            (attr) => XmlAttribute(
              XmlName.fromString(attr.name.toXmlString()),
              attr.value,
            ),
          )
          .toList(),
      [],
      para.isSelfClosing,
    );

    // نسخ الخصائص
    var pPr = para.getElement("w:pPr");
    if (pPr != null) {
      para1.children.add(pPr.clone());
      para2.children.add(pPr.clone());
    }

    bool breakFound = false;

    for (var child in para.children) {
      if (child is! XmlElement) {
        continue;
      }

      // تخطي pPr لأننا نسخناه بالفعل
      if (child.name.local == "pPr") continue;

      if (breakFound) {
        para2.children.add(child.clone());
        continue;
      }

      if (child.name.local == "r") {
        var breakElement = child.getElement("w:lastRenderedPageBreak");
        if (breakElement != null) {
          breakFound = true;

          // === تقسيم الـ Run داخلياً ===
          XmlElement run1 = XmlElement(
            XmlName.fromString(child.name.toXmlString()),
            child.attributes
                .map(
                  (a) => XmlAttribute(
                    XmlName.fromString(a.name.toXmlString()),
                    a.value,
                  ),
                )
                .toList(),
            [],
            child.isSelfClosing,
          );

          XmlElement run2 = XmlElement(
            XmlName.fromString(child.name.toXmlString()),
            child.attributes
                .map(
                  (a) => XmlAttribute(
                    XmlName.fromString(a.name.toXmlString()),
                    a.value,
                  ),
                )
                .toList(),
            [],
            child.isSelfClosing,
          );

          // نسخ rPr
          var rPr = child.getElement("w:rPr");
          if (rPr != null) {
            run1.children.add(rPr.clone());
            run2.children.add(rPr.clone());
          }

          bool splitInRun = false;
          // التكرار على العقد داخل الـ run (نصوص، صور، إلخ)
          for (var runChild in child.children) {
            if (runChild is XmlElement && runChild.name.local == "rPr")
              continue;

            if (runChild is XmlElement &&
                runChild.name.local == "lastRenderedPageBreak") {
              splitInRun = true;
              continue;
            }

            if (splitInRun) {
              run2.children.add(_cloneNodeManual(runChild));
            } else {
              run1.children.add(_cloneNodeManual(runChild));
            }
          }

          if (run1.children.isNotEmpty) para1.children.add(run1);
          if (run2.children.isNotEmpty) para2.children.add(run2);

          continue;
        }
      }

      para1.children.add(child.clone());
    }

    return {'before': para1, 'after': para2};
  }

  // دالة مساعدة لنسخ العقد غير Elements (مثل النصوص)
  XmlNode _cloneNodeManual(XmlNode node) {
    if (node is XmlElement) return node.clone();
    if (node is XmlText) return XmlText(node.text);
    return node; // fallback (reference copy for comments etc which is irrelevant mostly)
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
