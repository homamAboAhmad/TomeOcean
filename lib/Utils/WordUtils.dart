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

  Future<List<WordPage>> addParagraphToDocument(XmlElement? body) async {
    List<WordPage> pages = [];
    List<XmlElement> allPs = getAllXmlParagraphs(body);
    // print("📄 PAGINATION: Starting with ${allPs.length} paragraphs");

    if (allPs.isEmpty) {
      throw Exception(
        "No paragraphs found in document body. The document might be empty or structured in an unexpected way (e.g., all content is inside a textbox).",
      );
    }

    int j = 1;
    while (allPs.isNotEmpty) {
      // print("📄 PAGINATION: Creating page $j, allPs.length = ${allPs.length}");
      WordPage wordPage = await getPage(allPs, pageNum: j);
      pages.add(wordPage);
      // print("📄 PAGINATION: Page $j created with ${wordPage.ps.length} paragraphs");

      j++;
    }
    // print("📄 PAGINATION: Total pages created = ${pages.length}");
    return pages;
  }

  getPage(List<XmlElement> allPs, {required int pageNum}) async {
    try {
      // print("getPage: Starting for page $pageNum");
      List<XmlElement> pagePs = getPageXmlPs(allPs);
      // print("getPage: pagePs created with length ${pagePs.length}");
      WordPage wordPage = WordPage(wordDocument);
      // print("getPage: WordPage object created");
      wordPage.parent = wordDocument;
      addPsToPage(wordPage, pagePs, pageNum: pageNum);
      // print("getPage: addPsToPage completed");
      addFnToPage(wordPage);
      // print("getPage: addFnToPage completed");
      await Future.delayed(Duration(milliseconds: 200), () {});
      return wordPage;
    } catch (e, s) {
      // print("!!! CRASH inside getPage for page #${pageNum} !!!");
      // print("!!! Error: $e");
      // print("!!! StackTrace: $s");
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

          // Merge adjacent parentheses runs into the footnote run
          // Keep parentheses as-is, just merge them into one run
          String openParen = "";
          String closeParen = "";

          // Check previous run for opening parenthesis
          if (runIndex > 0) {
            runT prevRun = p.runs[runIndex - 1];
            if (prevRun.text == "(" &&
                prevRun.rpr?.vertAlign == "superscript") {
              openParen = "("; // Keep as-is
              prevRun.text = "";
            }
          }
          // Check next run for closing parenthesis
          if (runIndex < p.runs.length - 1) {
            runT nextRun = p.runs[runIndex + 1];
            if (nextRun.text == ")" &&
                nextRun.rpr?.vertAlign == "superscript") {
              closeParen = ")"; // Keep as-is
              nextRun.text = "";
            }
          }

          // Combine parentheses with the number
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
    wordPage.pageIndex = pageNum; // Set page index for bookmark tracking
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
    // print("getPageXmlPs: Received allPs.length = ${allPs.length}");
    XmlElement? remainingParagraph;
    int k = 0;
    List<XmlElement> pagePs = [];

    // Calculate available page height in twips
    // Default A4 height (16838 twips) if not specified
    double pageHeightTwips = 16838;
    double topMargin = 1440; // 1 inch
    double bottomMargin = 1440; // 1 inch

    if (wordDocument.sectpr != null) {
      // Convert dp back to twips for calculation (since SectPr stores in dp)
      // 1 dp approx 15-20 twips depending on density, but let's use standard conversion
      // Actually SectPr stores converted values, let's use raw values if possible or estimate
      // For simplicity, let's use a standard safe height for text area
      if (wordDocument.sectpr!.height != null) {
        // Note: SectPr.height is in dp (logical pixels), need to be careful with units
        // Let's rely on a safe item count derived from page size
        // Standard page is ~800-1000 height in dp
        pageHeightTwips =
            wordDocument.sectpr!.height! *
            15; // Rough back-conversion or use dp directly
      }
    }

    // Working in logical pixels (dp) is easier since Flutter uses dp
    double pageHeightDp =
        wordDocument.sectpr?.height ?? 842; // A4 height in points/dp
    double pageMarginDp =
        (wordDocument.sectpr?.topMargin ?? 56) +
        (wordDocument.sectpr?.bottomMargin ?? 56);
    double availableHeightDp = pageHeightDp - pageMarginDp;

    double currentContentHeight = 0;

    for (int i = 0; i < allPs.length; i++) {
      XmlElement element = allPs[i];
      XmlElement? nextElement = i + 1 < allPs.length ? allPs[i + 1] : null;

      // String paraId = element.getAttribute("w14:paraId") ?? "?";
      // bool hasImage = element.findAllElements("w:drawing").isNotEmpty;
      // print("  🔹 Processing paragraph $i (paraId=$paraId, hasImage=$hasImage)");

      // Check if this is a TOC item
      bool isTocItem = element.getAttribute("isSdtRow") == "True";

      // التحقق من موقع lastRenderedPageBreak
      String breakPosition = getLastRenderBreakPosition(element);
      // print("    breakPosition = $breakPosition");

      if (breakPosition == "start" && i > 0) {
        // print("    ⏹ BREAK: lastRenderedPageBreak at start, i > 0");
        // الفاصل في بداية الفقرة - نبدأ صفحة جديدة قبلها
        break;
      } else if (breakPosition == "middle") {
        // الفاصل في منتصف الفقرة - نقسمها
        var splitResult = splitParagraphAtBreak(element);
        if (splitResult != null) {
          pagePs.add(splitResult['before']!);
          k++;
          remainingParagraph = splitResult['after'];
          break;
        }
      }

      // Height-based pagination for TOC
      if (isTocItem) {
        // Estimate paragraph height
        // Default font size 14pt (approx 19px height with line spacing)
        double itemHeight = 30.0; // Increased base height

        // Try to get actual font size from XML
        // <w:sz w:val="40"/> -> 20pt
        var rPr = element.findAllElements("w:rPr").firstOrNull;
        if (rPr != null) {
          var sz = rPr.findAllElements("w:sz").firstOrNull;
          if (sz != null) {
            var val = double.tryParse(sz.getAttribute("w:val") ?? "28");
            if (val != null) {
              // val is in half-points. 40 = 20pt.
              // Line height is usually ~1.5-1.8 * font size for Arabic
              // Increasing to 2.2 to be safe and force break for dense pages
              double fontSizePt = val / 2;
              itemHeight = fontSizePt * 2.1;

              // If font size is large (Title), add extra padding
              if (fontSizePt > 24) {
                itemHeight += 40;
              }
            }
          }
        }

        // Add spacing between paragraphs if present
        var pPr = element.findAllElements("w:pPr").firstOrNull;
        if (pPr != null) {
          var spacing = pPr.findAllElements("w:spacing").firstOrNull;
          if (spacing != null) {
            var before = double.tryParse(
              spacing.getAttribute("w:before") ?? "0",
            );
            var after = double.tryParse(spacing.getAttribute("w:after") ?? "0");
            // spacing is in twips usually, convert to dp (approx / 20)
            if (before != null) itemHeight += (before / 20);
            if (after != null) itemHeight += (after / 20);
          }
        }

        currentContentHeight += itemHeight;

        // Safety margin: Stop a bit earlier than full page height
        double safetyMargin = 50.0;

        // print("DEBUG TOC: Item $k Height: $itemHeight, Total: $currentContentHeight / ${availableHeightDp - safetyMargin}");

        // If we exceed available height and it's not the first item
        if (currentContentHeight > (availableHeightDp - safetyMargin) &&
            k > 0) {
          // Only break if next item is also TOC
          if (nextElement != null &&
              nextElement.getAttribute("isSdtRow") == "True") {
            print(
              "DEBUG TOC: Forced break at $currentContentHeight dp (Item $k). Limit: ${availableHeightDp - safetyMargin}",
            );
            // remainingParagraph = element; // DO NOT SET THIS! It causes duplication because element is already in allPs
            break; // Stop adding to this page
          }
        }
      } else {
        // For non-TOC items, we might want to reset or estimate differently
        // For now, let's assume they take some space too if mixed
        // currentContentHeight += 20;
      }

      pagePs.add(element);
      k++;

      // التحقق من وجود w:br type="page" وتقسيم الفقرة إذا لزم
      var brPageResult = splitParagraphAtBrPage(element);
      if (brPageResult != null) {
        // استبدال الفقرة الأخيرة بالجزء الأول فقط
        pagePs.removeLast();
        pagePs.add(brPageResult['before']!);

        // التعامل مع الجزء ما بعد الفاصل
        var afterParagraph = brPageResult['after'];
        if (afterParagraph != null) {
          bool hasContent = afterParagraph.findElements("w:r").isNotEmpty;
          if (hasContent) {
            remainingParagraph = afterParagraph;
          }
        }

        // *** CLEANUP LOGIC: Merge next Empty SectPr Paragraph ***
        if (nextElement != null && isEmptySectPrParagraph(nextElement)) {
          print(
            "    🔹 Merging next Empty SectPr paragraph to avoid double break",
          );
          pagePs.add(nextElement);
          k++; // Consume next element
        }

        break; // End page
      }

      if (hasBrPage(element, nextElement: nextElement)) {
        // *** CLEANUP LOGIC: Merge next Empty SectPr Paragraph ***
        if (nextElement != null && isEmptySectPrParagraph(nextElement)) {
          print(
            "    🔹 Merging next Empty SectPr paragraph to avoid double break (hasBrPage)",
          );
          pagePs.add(nextElement);
          k++; // Consume next element
        }
        break;
      }

      // Check if paragraph ends a section (sectPr inside pPr means section break = new page)
      if (isSectPr(element)) {
        print("    ⏹ BREAK: sectPr found (section break)");
        break;
      }

      // Check if paragraph contains a full-page foreground image (not a frame)
      if (hasFullPageImage(element, wordDocument)) break;
    }

    // print("getPageXmlPs: Loop finished. Paragraphs for this page (k) = $k");
    updateAllPs(allPs, k, remainingParagraph);

    return pagePs;
  }

  void updateAllPs(
    List<XmlElement> allPs,
    int i,
    XmlElement? remainingParagraph,
  ) {
    // print("updateAllPs: Removing range 0..$i from allPs of length ${allPs.length}");
    allPs.removeRange(0, i);
    if (remainingParagraph != null) {
      allPs.insert(0, remainingParagraph);
    }
  }

  bool isLastPageLine(XmlElement element) {
    return element.getAttribute("isLastPageLine") == "true";
  }

  void addTableToPage(WordPage wordPage, XmlElement element) {
    // //print("table body: \n${element.toXmlString(pretty: true)}");
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

  /// Get major font for Complex Script (Arabic, Hebrew, etc.)
  String? getMajorFontCS(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:majorFont")
        ?.getElement("a:cs")
        ?.getAttribute("typeface");
  }

  /// Get minor font for Complex Script (Arabic, Hebrew, etc.)
  String? getMinorFontCS(XmlElement? fontScheme) {
    return fontScheme
        ?.getElement("a:minorFont")
        ?.getElement("a:cs")
        ?.getAttribute("typeface");
  }

  bool isEmptySectPrParagraph(XmlElement element) {
    // Must be a paragraph
    if (element.name.local != "p") return false;

    // Must have sectPr
    if (!isSectPr(element)) return false;

    // Must NOT have text content
    // Check if it has any runs with text or images
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

/// Convert Western Arabic numerals (0-9) to Arabic-Indic numerals (٠-٩)
String _toArabicNumerals(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String result = input;
  for (int i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], arabicIndic[i]);
  }
  return result;
}

/// يحدد موقع lastRenderedPageBreak في الفقرة
/// يرجع: "none" إذا لم يوجد، "start" إذا في البداية، "middle" إذا في المنتصف
String getLastRenderBreakPosition(XmlElement element) {
  int brL = element.findAllElements("w:lastRenderedPageBreak").length;
  if (brL == 0) return "none";

  // البحث في كل الـ runs للعثور على موقع الفاصل
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

/// يقسم الفقرة عند lastRenderedPageBreak
/// يرجع Map يحتوي على 'before' (الجزء قبل الفاصل) و 'after' (الجزء بعده)
Map<String, XmlElement>? splitParagraphAtBreak(XmlElement paragraph) {
  try {
    // استخراج w:pPr (خصائص الفقرة) لنسخها لكلا الجزءين
    var pPr = paragraph.getElement("w:pPr");
    String pPrXml = pPr?.toXmlString() ?? "";

    // جمع كل المحتوى قبل وبعد الفاصل
    List<String> runsBefore = [];
    List<String> runsAfter = [];
    bool foundBreak = false;

    var allRuns = paragraph.childElements
        .where((e) => e.name.local == "r")
        .toList();

    for (var run in allRuns) {
      if (!foundBreak) {
        // البحث عن الفاصل داخل هذا الـ run
        var breakElement = run
            .findElements("w:lastRenderedPageBreak")
            .firstOrNull;

        if (breakElement != null) {
          foundBreak = true;

          // تقسيم هذا الـ run
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

    // بناء الفقرتين الجديدتين
    // حتى لو كانت runsBefore فارغة، يجب إنشاء فقرة فارغة لإنهاء الصفحة الحالية
    // أو إذا كانت runsAfter فارغة، فهذا يعني أن الفقرة انتهت بفاصل صفحة

    String beforeXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsBefore.join()}</w:p>';
    String afterXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsAfter.join()}</w:p>';

    var beforeDoc = XmlDocument.parse(beforeXml);
    var afterDoc = XmlDocument.parse(afterXml);

    return {'before': beforeDoc.rootElement, 'after': afterDoc.rootElement};
  } catch (e) {
    print("DEBUG PAGE: Error splitting paragraph: $e");
    return null;
  }
}

/// يقسم run عند lastRenderedPageBreak
Map<String, String?> splitRunAtBreak(XmlElement run) {
  var rPr = run.getElement("w:rPr");
  String rPrXml = rPr?.toXmlString() ?? "";

  List<String> contentBefore = [];
  List<String> contentAfter = [];
  bool foundBreak = false;

  for (var child in run.childElements) {
    if (child.name.local == "lastRenderedPageBreak") {
      foundBreak = true;
      continue; // تجاهل عنصر الفاصل نفسه
    }

    if (child.name.local == "rPr") continue; // تم التعامل معه منفصلاً

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

/// يقسم الفقرة عند w:br type="page"
/// يرجع Map يحتوي على 'before' (الجزء قبل الفاصل) و 'after' (الجزء بعده)
/// أو null إذا لم يوجد w:br type="page"
Map<String, XmlElement>? splitParagraphAtBrPage(XmlElement paragraph) {
  try {
    // البحث عن w:br type="page"
    List<XmlElement> brs = paragraph.findAllElements("w:br").toList();
    bool hasBrPage = brs.any((br) => br.getAttribute("w:type") == "page");
    if (!hasBrPage) return null;

    // استخراج w:pPr (خصائص الفقرة) لنسخها لكلا الجزءين
    var pPr = paragraph.getElement("w:pPr");
    String pPrXml = pPr?.toXmlString() ?? "";

    // جمع كل المحتوى قبل وبعد الفاصل
    List<String> runsBefore = [];
    List<String> runsAfter = [];
    bool foundBreak = false;

    var allRuns = paragraph.childElements
        .where((e) => e.name.local == "r")
        .toList();

    for (var run in allRuns) {
      if (!foundBreak) {
        // البحث عن w:br type="page" داخل هذا الـ run
        var breakElements = run.findElements("w:br").toList();
        var pageBreak = breakElements
            .where((br) => br.getAttribute("w:type") == "page")
            .firstOrNull;

        if (pageBreak != null) {
          foundBreak = true;

          // تقسيم هذا الـ run عند الـ page break
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

    // بناء الفقرتين الجديدتين
    String beforeXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsBefore.join()}</w:p>';
    String afterXml =
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$pPrXml${runsAfter.join()}</w:p>';

    var beforeDoc = XmlDocument.parse(beforeXml);
    var afterDoc = XmlDocument.parse(afterXml);

    return {'before': beforeDoc.rootElement, 'after': afterDoc.rootElement};
  } catch (e) {
    print("DEBUG PAGE: Error splitting paragraph at br page: $e");
    return null;
  }
}

/// يقسم run عند w:br type="page"
Map<String, String?> splitRunAtBrPage(XmlElement run) {
  var rPr = run.getElement("w:rPr");
  String rPrXml = rPr?.toXmlString() ?? "";

  List<String> contentBefore = [];
  List<String> contentAfter = [];
  bool foundBreak = false;

  for (var child in run.childElements) {
    if (child.name.local == "br" && child.getAttribute("w:type") == "page") {
      foundBreak = true;
      continue; // تجاهل عنصر الفاصل نفسه
    }

    if (child.name.local == "rPr") continue; // تم التعامل معه منفصلاً

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

/// دالة للتوافق مع الكود القديم
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

/// Check if a paragraph contains a full-page FOREGROUND image (not a frame/background)
/// This helps detect cover pages or full-page images that should end the current page
bool hasFullPageImage(XmlElement element, WordDocument wordDocument) {
  // Default A4 page height in EMU (29.7cm ≈ 10692000 EMU)
  // 1 inch = 914400 EMU, A4 height ≈ 11.69 inches
  double pageHeightEmu = 10692000;

  // Try to get actual page height from sectPr
  // sectPr.height is stored in dp (converted from twips)
  // We need to convert back: dp -> twips -> EMU
  // 1 twip = 635 EMU, 1 dp ≈ 15 twips (approximation)
  if (wordDocument.sectpr?.height != null && wordDocument.sectpr!.height! > 0) {
    // height in dp, convert to approximate EMU
    // dp * 15 (twips per dp) * 635 (EMU per twip) ≈ dp * 9525
    pageHeightEmu = wordDocument.sectpr!.height! * 9525;
  }

  // Find all anchor images in the paragraph
  Iterable<XmlElement> anchors = element.findAllElements("wp:anchor");
  for (XmlElement anchor in anchors) {
    // Only consider foreground images (behindDoc="0" or not specified)
    // behindDoc="1" means it's a background/frame image - skip those
    String? behindDoc = anchor.getAttribute("behindDoc");
    if (behindDoc == "1") continue;

    // Get image dimensions from wp:extent
    XmlElement? extent = anchor.getElement("wp:extent");
    if (extent != null) {
      String? cyStr = extent.getAttribute("cy");
      if (cyStr != null) {
        double cy = double.tryParse(cyStr) ?? 0;
        // If image height >= 85% of page height, consider it a full-page image
        if (cy >= pageHeightEmu * 0.85) {
          return true;
        }
      }
    }
  }
  return false;
}
