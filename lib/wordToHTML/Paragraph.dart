import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:golden_shamela/TestApp2.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/wordToHTML/HyperLinkRun.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/wordToHTML/TabStop.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';

import 'package:golden_shamela/Utils/json_converters.dart';
import 'package:golden_shamela/wordToHTML/ParagraphTable.dart';

import '../WordToWidget/ImageToWidget.dart';
import '../core/app_state.dart';
import '../Utils/ArchiveToXml.dart';
import 'DocFootNotes.dart';
import 'PPr.dart';

part 'Paragraph.g.dart';

class ParagraphBorderSideSpec {
  final String style;
  final double width;
  final double space;
  final Color color;

  const ParagraphBorderSideSpec({
    required this.style,
    required this.width,
    required this.space,
    required this.color,
  });
}

class ParagraphBorderSpec {
  final String signature;
  final ParagraphBorderSideSpec? top;
  final ParagraphBorderSideSpec? bottom;
  final ParagraphBorderSideSpec? left;
  final ParagraphBorderSideSpec? right;
  final ParagraphBorderSideSpec? between;

  const ParagraphBorderSpec({
    required this.signature,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.between,
  });
}

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class Paragraph {
  PPr? pPr;
  RPr? prPr;

  @JsonKey(ignore: true)
  String? customPageNumber;
  List<runT> runs = [];
  String text = ""; // Reverted to field
  @JsonKey(ignore: true)
  XmlElement? pXml;
  String xmlString = ""; // Store XML as string for debugging
  String pageNum = "";
  List<runT> imageRunTs = [];
  List<runT> textRunTs = [];
  @TextAlignConverter()
  TextAlign textAlign = TextAlign.start;
  @JsonKey(ignore: true)
  WordPage parent;
  @TextDirectionConverter()
  TextDirection textDirection = TextDirection.rtl;
  String sectionType = 'main'; // Default to 'main'

  /// Hyperlink anchor for TOC navigation (e.g., "_Toc123456")
  /// Extracted from w:hyperlink during XML parsing for cache persistence
  String? hyperlinkAnchor;

  @JsonKey(ignore: true)
  Map<String, RelId>? customRelIdList; // For parsing headers/footers with their own relationships

  /// Flag to indicate this paragraph is in a header (images should be semi-transparent)
  @JsonKey(ignore: true)
  bool isHeaderParagraph = false;

  /// Flag to prevent text wrapping (used for single words in tables to avoid forced breaks)
  @JsonKey(ignore: true)
  bool preventWrap = false;

  Paragraph(this.parent);

  Paragraph.empty() : parent = WordPage.empty();

  factory Paragraph.fromJson(Map<String, dynamic> json) =>
      _$ParagraphFromJson(json);
  Map<String, dynamic> toJson() => _$ParagraphToJson(this);

  static Paragraph fromMap(Map<String, dynamic> json, WordPage parent) {
    final paragraph = _$ParagraphFromJson(json);
    paragraph.parent = parent;

    if (json['pPr'] != null) {
      paragraph.pPr = PPr.fromMap(
        json['pPr'] as Map<String, dynamic>,
        paragraph,
      );
    }
    if (json['prPr'] != null) {
      // prPr's parent is runT, which is not available here. It will be set when runT is deserialized.
      paragraph.prPr = RPr.fromMap(json['prPr'] as Map<String, dynamic>, null);
    }
    paragraph.runs = (json['runs'] as List<dynamic>)
        .map((e) => runT.fromMap(e as Map<String, dynamic>, paragraph))
        .toList();

    // إعادة بناء textRunTs و imageRunTs من runs المرتبطة بشكل صحيح
    // _$ParagraphFromJson تحمّل textRunTs/imageRunTs من JSON لكن بدون روابط parent صحيحة
    // نعيد بناءها من runs التي لديها روابط parent سليمة
    paragraph.getPRunsByType();

    paragraph.sectionType = json['sectionType'] as String? ?? 'main';
    paragraph.text =
        json['text'] as String? ?? ''; // Re-add text deserialization

    // إعادة حساب المحاذاة من pPr عند التحميل من الكاش
    paragraph.getPAlign();
    paragraph.getPTextDirection();

    // Check if this paragraph is actually a table based on XML content
    if (paragraph.xmlString.trim().startsWith('<w:tbl')) {
      ParagraphTable tableParagraph = ParagraphTable(parent);

      // Copy properties manually since we can't easily cast
      tableParagraph.pPr = paragraph.pPr;
      tableParagraph.prPr = paragraph.prPr;
      tableParagraph.runs = paragraph.runs;
      tableParagraph.text = paragraph.text;
      tableParagraph.xmlString = paragraph.xmlString;
      tableParagraph.pageNum = paragraph.pageNum;
      tableParagraph.imageRunTs = paragraph.imageRunTs;
      tableParagraph.textRunTs = paragraph.textRunTs;
      tableParagraph.textAlign = paragraph.textAlign;
      tableParagraph.textDirection = paragraph.textDirection;
      tableParagraph.sectionType = paragraph.sectionType;

      // Re-establish parent links for runs
      for (var run in tableParagraph.runs) {
        run.parent = tableParagraph;
      }

      // Parse XML to populate pXml (crucial for table rendering)
      try {
        if (tableParagraph.xmlString.isNotEmpty) {
          tableParagraph.pXml = XmlDocument.parse(
            tableParagraph.xmlString,
          ).rootElement;
        }
      } catch (e) {
        print("Error re-parsing table XML from cache: $e");
      }

      return tableParagraph;
    }

    return paragraph;
  }

  Paragraph fromXml(
    XmlElement paragraphXml, {
    bool skipNumberingCounter = false,
  }) {
    pXml = paragraphXml;
    // حفظ XML للجداول فقط (مطلوب لـ ParagraphTable عند التحميل من الكاش)
    // الفقرات العادية لا تحتاج XML محفوظ - يتم بناؤها من runs
    // حفظ XML لجميع الفقرات لأغراض التصحيح (Debugging)
    // كان سابقاً: if (tbl) ... else xmlString = "";
    xmlString = paragraphXml.toXmlString(pretty: false);
    if (xmlString.isNotEmpty) {
      // Only print occasionally to avoid spam, or print specific markers
      if (xmlString.contains("PG:")) {
        debugPrint(
          "DEBUG: Parsed Paragraph with Marker. XML len: ${xmlString.length}",
        );
      }
    } else {
      debugPrint("DEBUG: Parsed Paragraph produced EMPTY XML!");
    }

    // debugPrint("DEBUG: Parsed Paragraph from XML. String length: ${xmlString.length}");
    XmlElement? xmlpPr = paragraphXml.getElement("w:pPr");
    if (xmlpPr != null)
      pPr = PPr(
        this,
      ).fromXml(xmlpPr, skipNumberingCounter: skipNumberingCounter);

    _setSectionType();

    XmlElement? xmlprPr = pPr?.styleRunProperties;
    text = paragraphXml.text.replaceAll(
      RegExp(r'\{\{PG:\d+\}\}'),
      '',
    ); // Re-add text assignment

    if (xmlprPr != null) {
      prPr = RPr(pPr!.getEmptyRun()).fromXml(xmlprPr);
    }

    // Fallback to defaultRPr if font is missing
    if (prPr != null && prPr!.font == null) {
      prPr!.font = pPr?.wordDocument.defaultRPr?.font;
    }

    runs = [];

    bool inFieldCode = false;
    bool pendingPageNum = false;
    bool pageNumReplaced =
        false; // Track if we already replaced the page number

    // Track HYPERLINK field codes
    bool inHyperlinkField = false;
    String? hyperlinkFieldUrl;

    paragraphXml.childElements.forEach((element) {
      if (element.name.local == "r") {
        // Check for field characters to track state
        bool hasBegin = false;
        bool hasSeparate = false;
        bool hasEnd = false;

        for (var child in element.childElements) {
          if (child.name.local == "fldChar") {
            var type = child.getAttribute("w:fldCharType");
            if (type == "begin") hasBegin = true;
            if (type == "separate") hasSeparate = true;
            if (type == "end") hasEnd = true;
          }
        }

        if (hasBegin) inFieldCode = true;
        if (hasSeparate) inFieldCode = false;
        if (hasEnd) {
          inFieldCode = false;
        }

        // Check for PAGE instruction
        if (inFieldCode || hasBegin) {
          if (element.findAllElements("w:instrText").any((e) {
            return e.text.toUpperCase().contains("PAGE");
          })) {
            pendingPageNum = true;
            pageNumReplaced = false; // Reset when starting a new PAGE field
          }
        }

        // Check for HYPERLINK instruction in field code
        if (inFieldCode || hasBegin) {
          for (var instrEl in element.findAllElements("w:instrText")) {
            String instrText = instrEl.text;
            if (instrText.toUpperCase().contains("HYPERLINK")) {
              // Extract URL from: HYPERLINK "url" or HYPERLINK "url" \l "bookmark"
              final urlRegex = RegExp(
                r'HYPERLINK.*?"([^"]+)"',
                caseSensitive: false,
              );
              final match = urlRegex.firstMatch(instrText);
              if (match != null) {
                hyperlinkFieldUrl = match.group(1);
                inHyperlinkField = true;
              }
            }
          }
        }

        // Create the run
        runT runt0;

        // If we're in a hyperlink field (after separate, before end), create HyperLinkRun
        if (inHyperlinkField &&
            !inFieldCode &&
            !hasBegin &&
            !hasSeparate &&
            !hasEnd) {
          runt0 = HyperLinkRun(this, prPr: prPr, pPr: pPr).fromXml(element);

          // Check if this is an internal bookmark (e.g. _Toc...) or external URL
          if (hyperlinkFieldUrl != null && hyperlinkFieldUrl!.startsWith("_")) {
            hyperlinkAnchor = hyperlinkFieldUrl;
            (runt0 as HyperLinkRun).url = null; // Don't style as link
          } else {
            (runt0 as HyperLinkRun).url = hyperlinkFieldUrl;
          }
        } else {
          runt0 = runT(
            this,
            prPr: prPr,
            pPr: pPr,
            customRelIdList: customRelIdList,
          ).fromXml(element);
        }

        if (inFieldCode && !hasSeparate && !hasEnd && !hasBegin) {
          runt0.text = "";
        }

        // --- NEW: Parse {{PG:X}} Page Number Marker ---
        // This marker is injected by the Python script (hidden text with double braces)
        if (runt0.text != null && runt0.text!.contains("{{PG:")) {
          final RegExp pgRegex = RegExp(r"\{\{PG:(\d+)\}\}");
          final match = pgRegex.firstMatch(runt0.text!);
          if (match != null) {
            String? pageStr = match.group(1);
            if (pageStr != null) {
              pageNum = pageStr; // Set the paragraph's page number
              // print(
              //   "DEBUG PARA: Found marker {{PG:$pageNum}} - text preview: ${text.substring(0, text.length > 30 ? 30 : text.length)}...",
              // );
              // Remove the marker from the text so it doesn't show up
              runt0.text = runt0.text!.replaceAll(match.group(0)!, "");
            }
          }
        }
        // ---------------------------------------------

        if (element.findAllElements("w:instrText").isNotEmpty) {
          runt0.text = "";
        }

        if (runt0.text != null &&
            runt0.text!.toUpperCase().contains("PAGEREF")) {
          runt0.text = "";
        }

        // Replace PAGE field result - ONLY ONCE
        // We replace if we are tracking a PAGE field (pendingPageNum)
        // AND we haven't already replaced (pageNumReplaced is false)
        // AND we are not in the instruction part (inFieldCode is false)
        // AND we are not starting a new field (hasBegin)
        if (pendingPageNum &&
            !pageNumReplaced &&
            !inFieldCode &&
            !hasBegin &&
            customPageNumber != null) {
          runt0.text = customPageNumber!;
          pageNumReplaced = true;
        } else if (pendingPageNum && pageNumReplaced && !hasEnd) {
          // Skip additional runs inside PAGE field after we've already replaced
          runt0.text = "";
        }

        if (hasEnd) {
          pendingPageNum = false;
          pageNumReplaced = false; // Reset for next field
          // Reset hyperlink field tracking
          inHyperlinkField = false;
          hyperlinkFieldUrl = null;
        }

        runt0.parent = this;
        pPr?.parent = this;
        prPr?.parent = runt0;
        runs.add(runt0);
      } else if (element.name.local == "fldSimple") {
        String? instr = element.getAttribute("w:instr");

        // Check for HYPERLINK in fldSimple
        if (instr != null && instr.toUpperCase().contains("HYPERLINK")) {
          // Extract URL from: HYPERLINK "url"
          final urlRegex = RegExp(
            r'HYPERLINK\s+"([^"]+)"',
            caseSensitive: false,
          );
          final match = urlRegex.firstMatch(instr);
          String? url = match?.group(1);

          // Process children as HyperLinkRun
          element.childElements.forEach((child) {
            if (child.name.local == "r") {
              HyperLinkRun run = HyperLinkRun(
                this,
                prPr: prPr,
                pPr: pPr,
              ).fromXml(child);

              if (url != null && url.startsWith("_")) {
                hyperlinkAnchor = url;
                run.url = null;
              } else {
                run.url = url;
              }
              run.parent = this;
              runs.add(run);
            }
          });
        } else if (instr != null &&
            instr.contains("PAGE") &&
            customPageNumber != null) {
          runT runt0 = runT(
            this,
            prPr: prPr,
            pPr: pPr,
            customRelIdList: customRelIdList,
          );
          // Try to get formatting from the first run inside fldSimple if available
          var firstRun = element.findElements("w:r").firstOrNull;
          if (firstRun != null) {
            runt0 = runT(
              this,
              prPr: prPr,
              pPr: pPr,
              customRelIdList: customRelIdList,
            ).fromXml(firstRun);
          }
          runt0.text = customPageNumber!;
          runs.add(runt0);
        } else {
          // Process children normally
          element.childElements.forEach((child) {
            if (child.name.local == "r") {
              runT runt0 = runT(
                this,
                prPr: prPr,
                pPr: pPr,
                customRelIdList: customRelIdList,
              ).fromXml(child);
              runs.add(runt0);
            }
          });
        }
      }
      // Handle w:sdt (Structured Document Tag) - commonly used for page numbers in footers
      else if (element.name.local == "sdt") {
        // Check if this sdt contains a page number (docPartGallery with "Page Numbers")
        var sdtPr = element.getElement("w:sdtPr");
        var docPartObj = sdtPr?.getElement("w:docPartObj");
        var gallery = docPartObj?.getElement("w:docPartGallery");
        String? galleryVal = gallery?.getAttribute("w:val");
        bool isPageNumberSdt =
            galleryVal != null && galleryVal.contains("Page Numbers");

        // Get content from sdtContent
        var sdtContent = element.getElement("w:sdtContent");
        if (sdtContent != null) {
          // Process all runs inside sdtContent
          _processSdtContent(sdtContent, isPageNumberSdt, prPr, pPr);
        }
      }
      // Handle w:hyperlink - External links
      else if (element.name.local == "hyperlink") {
        // Extract Relationship ID (r:id) to find external URL
        String? rId = element.getAttribute("r:id");
        String? url;

        // Extract tooltip text (w:tooltip attribute)
        String? tooltip = element.getAttribute("w:tooltip");

        // Look up URL in document relationships
        // Use customRelIdList for headers/footers, fall back to main document
        if (rId != null) {
          final rels = customRelIdList ?? parent.parent.relIdList;
          if (rels.containsKey(rId)) {
            url = rels[rId]?.Target;
          }
        }

        // Also extract anchor for TOC navigation
        String? anchor = element.getAttribute("w:anchor");
        if (anchor != null) {
          hyperlinkAnchor = anchor;
        }

        // Process child runs as HyperLinkRun
        element.childElements.forEach((child) {
          if (child.name.local == "r") {
            HyperLinkRun run = HyperLinkRun(
              this,
              prPr: prPr,
              pPr: pPr,
            ).fromXml(child);
            run.url = url;
            run.tooltip = tooltip;
            run.parent = this;
            runs.add(run);
          }
        });
      }
    });
    fixPDirection();
    getPAlign();
    getPTextDirection();
    getPageNum();
    // Note: checkHyperLink() was removed because hyperlinks are already processed
    // in the main loop above (element.name.local == "hyperlink").
    // Calling it here would cause duplicate hyperlink runs.
    _extractBookmarks(); // Extract bookmarks from paragraph level
    getPRunsByType();
    return this;
  }

  /// Process content inside a w:sdt (Structured Document Tag)
  /// This handles page numbers and other structured content in footers
  void _processSdtContent(
    XmlElement sdtContent,
    bool isPageNumberSdt,
    RPr? prPr,
    PPr? pPr,
  ) {
    int fieldDepth = 0; // Track nested field depth
    bool currentFieldIsPage = false;
    bool currentFieldIsNumPages = false;
    bool pageNumReplaced =
        false; // Track if we already replaced the page number
    for (var child in sdtContent.childElements) {
      // Handle fldSimple inside SDT
      if (child.name.local == "fldSimple") {
        String? instr = child.getAttribute("w:instr");
        if (instr != null &&
            instr.contains("PAGE") &&
            customPageNumber != null) {
          runT runt0 = runT(
            this,
            prPr: prPr,
            pPr: pPr,
            customRelIdList: customRelIdList,
          );
          // Try to get formatting from the first run inside fldSimple
          var firstRun = child.findElements("w:r").firstOrNull;
          if (firstRun != null) {
            runt0 = runT(
              this,
              prPr: prPr,
              pPr: pPr,
              customRelIdList: customRelIdList,
            ).fromXml(firstRun);
          }
          runt0.text = customPageNumber!;
          runt0.parent = this;
          runs.add(runt0);
          continue;
        }
      }

      if (child.name.local == "r") {
        // Check for field characters
        bool hasBegin = false;
        bool hasSeparate = false;
        bool hasEnd = false;

        for (var el in child.childElements) {
          if (el.name.local == "fldChar") {
            var type = el.getAttribute("w:fldCharType");
            if (type == "begin") hasBegin = true;
            if (type == "separate") hasSeparate = true;
            if (type == "end") hasEnd = true;
          }
        }

        // Track field depth
        if (hasBegin) {
          fieldDepth++;
          // Reset field type flags for new field
          if (fieldDepth == 1) {
            currentFieldIsPage = false;
            currentFieldIsNumPages = false;
          }
        }

        // Check for field instructions when in a field
        if (fieldDepth > 0) {
          var instrTexts = child.findAllElements("w:instrText");
          for (var instr in instrTexts) {
            String instrText = instr.text.trim().toUpperCase();
            if (instrText.contains("NUMPAGES")) {
              currentFieldIsNumPages = true;
            } else if (instrText.contains("PAGE")) {
              currentFieldIsPage = true;
            }
          }
        }

        runT runt0 = runT(
          this,
          prPr: prPr,
          pPr: pPr,
          customRelIdList: customRelIdList,
        ).fromXml(child);

        // Clear instrText content
        if (child.findAllElements("w:instrText").isNotEmpty) {
          runt0.text = "";
        }

        // Skip field character runs (begin, separate, end)
        if (hasBegin || hasSeparate) {
          continue;
        }

        if (hasEnd) {
          fieldDepth--;
          if (fieldDepth <= 0) {
            fieldDepth = 0;
            currentFieldIsPage = false;
            currentFieldIsNumPages = false;
          }
          continue;
        }

        // Skip NUMPAGES result (when inside NUMPAGES field)
        if (currentFieldIsNumPages && fieldDepth > 0) {
          continue;
        }

        // Handle PAGE field content
        if (currentFieldIsPage && fieldDepth > 0) {
          if (!pageNumReplaced && customPageNumber != null) {
            // First run inside PAGE field - replace with actual page number
            runt0.text = customPageNumber!;
            pageNumReplaced = true;
          } else {
            // Additional runs inside PAGE field - skip them (e.g., if cached value spans multiple runs)
            continue;
          }
        }

        // Skip empty runs
        if (runt0.text == null || runt0.text!.isEmpty) {
          continue;
        }
        runt0.parent = this;
        runs.add(runt0);
      }
    }
  }

  /// Determines the section type for search indexing purposes.
  ///
  /// **Database Architect Note**: This method accurately classifies paragraphs into:
  /// - `title`: Main headings, sub-headings (Heading1-9, Title, TOC, etc.)
  /// - `main`: Regular body text (default)
  /// - `footnote`: Set separately in DocFootNotes.dart
  ///
  /// Note: 'comment' type is NOT used as it's under development.
  void _setSectionType() {
    String? style = pPr?.pStyle?.toLowerCase();
    if (style == null) {
      sectionType = 'main';
      return;
    }

    // Check for common heading/title style patterns in Word documents
    // This covers English and Arabic document styles
    if (style.startsWith('heading') || // Heading1, Heading2, etc.
        style.startsWith('toc') || // Table of Contents entries
        style == 'title' || // Title style
        style == 'subtitle' || // Subtitle style
        style.contains('heading') || // Custom heading styles
        style.contains('عنوان') || // Arabic: "عنوان" = Title
        style.contains('رأس') || // Arabic: "رأس" = Head
        style.contains('فصل') || // Arabic: "فصل" = Chapter
        style.contains('باب') || // Arabic: "باب" = Section/Gate
        style.contains('مطلب') || // Arabic: "مطلب" = Requirement/Section
        style.contains('مبحث') || // Arabic: "مبحث" = Topic
        style.contains('فرع') || // Arabic: "فرع" = Branch/Sub-section
        style.contains('مسألة')) {
      // Arabic: "مسألة" = Issue/Question
      sectionType = 'title';
    } else {
      sectionType = 'main';
    }
  }

  getPRunsByType() {
    imageRunTs = [];
    textRunTs = [];
    runs.forEach((runt) {
      final image = runt.image;
      final isSpecialDebugRid =
          image != null && RegExp(r'^rId(1[3-9])$').hasMatch(image.rId);
      final isVmlShape = image != null && image.vmlShapeData != null;
      // 1. Floating Images (wrapMode != null)
      if (image != null && image.wrapMode != null) {
        // Header/footer paragraphs: keep ALL floating images here since they are
        // not handled by WordPage.dart (headers render independently).
        // Decorative elements (lines, shapes) intentionally span the full page width.
        if (isHeaderParagraph) {
          imageRunTs.add(runt);
          if (isSpecialDebugRid || isVmlShape) {
            print(
              'VML_DEBUG_CLASSIFY: rId=${image.rId} shape=${image.vmlShapeData?.shapeType} -> imageRunTs(header) wrapMode=${image.wrapMode} isHeader=$isHeaderParagraph',
            );
          }
        }
        // Page content paragraphs: If relative to paragraph/line OR IS GROUP, add to Paragraph Stack.
        // EXCEPTION: paragraph-relative images that EXCEED the content area
        // (full-page covers) go to page level for correct rendering beyond margins.
        else if ((runt.isRelativeFromVParagraph() &&
                !_exceedsContentArea(runt)) ||
            image.isGroup) {
          imageRunTs.add(runt);
          if (isSpecialDebugRid) {
            print(
              'VML_DEBUG_CLASSIFY: rId=${image.rId} -> imageRunTs(paragraph) wrapMode=${image.wrapMode} relV=${image.relativeFromV} width=${image.width} height=${image.height}',
            );
          }
        } else if (isVmlShape) {
          // VML shape with absolute positioning NOT in header and NOT paragraph-relative
          // This is dropped! Log it.
          print(
            'VML_DEBUG_CLASSIFY: DROPPED! rId=${image.rId} shape=${image.vmlShapeData?.shapeType} wrapMode=${image.wrapMode} isHeader=$isHeaderParagraph relV=${image.relativeFromV} relH=${image.relativeFromH}',
          );
        }
        // If relative to page/margin, IGNORE here (handled by WordPage.dart)
        // This prevents them from polluting textRunTs and triggering inline logic.
      }
      // 2. Text and Inline Images (wrapMode == null)
      else {
        textRunTs.add(runt);
        if (isVmlShape) {
          print(
            'VML_DEBUG_CLASSIFY: rId=${image!.rId} shape=${image.vmlShapeData?.shapeType} -> textRunTs(inline/null-wrap) wrapMode=${image.wrapMode} isHeader=$isHeaderParagraph',
          );
        }
      }
    });
    if (isHeaderParagraph && imageRunTs.isNotEmpty) {
      print('VML_DEBUG_CLASSIFY: Header paragraph total: ${imageRunTs.length} imageRunTs, ${textRunTs.length} textRunTs');
    }
    return {"iRuns": imageRunTs, "tRuns": textRunTs};
  }

  /// Check if a run's image exceeds the content area (used to detect full-page covers)
  bool _exceedsContentArea(runT runt) {
    var sp = parent.parent.getSectPrForPage(parent.pageIndex);
    double contentW = (sp.width ?? 595) - sp.leftMargin - sp.rightMargin;
    double contentH = (sp.height ?? 842) - sp.topMargin - sp.bottomMargin;
    return runt.image!.width > contentW + 20 ||
        runt.image!.height > contentH + 20;
  }

  /// Check if this paragraph should use the special TOC rendering (Row + Expanded)
  /// This is true if:
  /// 1. It is an explicit TOC style
  /// 2. It contains a Right-aligned tab with a leader (which acts as a spring)
  /// We avoid this for Left/Center tabs to prevent them from stretching disproportionately.
  bool shouldRenderAsTOC() {
    if (pPr?.isTOCStyle() == true) return true;

    // Check for Right-aligned leader tabs defined in pPr
    // AND usage of a tab character in the runs
    bool hasRightLeaderDef =
        pPr?.tabStops.any((t) => t.isRightAligned && t.hasLeader) ?? false;
    bool hasTabUsage = textRunTs.any((r) => r.hasTab);

    return hasRightLeaderDef && hasTabUsage;
  }

  Widget toWidget({bool suppressParagraphBorder = false}) {
    // Check if this is a TOC entry OR uses right-aligned leader tabs - use special rendering
    // This ensures proportional tabs and leaders (tastir) appear correctly without stretching left tabs
    if (shouldRenderAsTOC()) {
      return _buildTOCWidget();
    }

    // Check for centered paragraph with tabs (like headers: "أعمال [TAB] ❀ [TAB] الرافعي")
    // These need Row layout to distribute content evenly
    if (_isCenteredWithTabs()) {
      return _buildCenteredTabsWidget(
        suppressParagraphBorder: suppressParagraphBorder,
      );
    }

    final singleInlineImageRun = _getSingleVisibleInlineImageRun();
    if (singleInlineImageRun != null) {
      Color? backgroundColor = _getParagraphShadingColor();
      BoxDecoration? decoration = _getParagraphDecoration(
        backgroundColor,
        includeBorder: !suppressParagraphBorder,
      );
      final image = singleInlineImageRun.image!;
      final double indent = pPr?.firstLineIndent ?? 0;
      final bool isRtlParagraph = textDirection == TextDirection.rtl;
      final bool isSpecialDebugRid = RegExp(
        r'^rId(1[3-9])$',
      ).hasMatch(image.rId);

      if (isSpecialDebugRid) {
        print(
          'VML_DEBUG_PARAGRAPH: special-inline-only path rId=${image.rId} indent=$indent textDirection=$textDirection paddings=${_getPPaddings()} imageW=${image.width} imageH=${image.height}',
        );
      }

      return Padding(
        padding: _getPPaddings(),
        child: Container(
          decoration: decoration,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: indent > 0 ? indent : 0),
            child: Align(
              alignment: textAlign == TextAlign.center
                  ? Alignment.center
                  : textAlign == TextAlign.left
                      ? Alignment.centerLeft
                      : textAlign == TextAlign.right
                          ? Alignment.centerRight
                          : (isRtlParagraph ? Alignment.centerRight : Alignment.centerLeft),
              child: getImageWidget(image),
            ),
          ),
        ),
      );
    }

    List<InlineSpan> spans = getPSpans();

    // لون تظليل الفقرة (إن وجد في w:pPr/w:shd)
    Color? backgroundColor = _getParagraphShadingColor();

    // الحدود (إن وجدت في w:pPr/w:pBdr)
    BoxDecoration? decoration = _getParagraphDecoration(
      backgroundColor,
      includeBorder: !suppressParagraphBorder,
    );

    // تقسيم الصور إلى مجموعتين: خلف النص وأمام النص
    List<Widget> behindImages = _getPositionedImages(true);
    List<Widget> frontImages = _getPositionedImages(false);

    return Padding(
      padding: _getPPaddings(),
      child: Container(
        decoration: decoration,
        // نستخدم Stack مع direction LTR لضمان أن left يعمل بشكل صحيح
        child: Stack(
          fit: StackFit.loose,
          clipBehavior: Clip.none,
          textDirection: TextDirection.ltr,
          children: [
            // 1. الصور الخلفية (behindDoc=true)
            // Positioned must be a DIRECT child of Stack for correct positioning.
            // IgnorePointer is already inside each Positioned (in _getPositionedImages).
            ...behindImages,

            // 2. النص (يحدد ارتفاع الفقرة)
            Directionality(
              textDirection: textDirection, // RTL usually
              child: _getTRunsW(spans),
            ),

            // 3. الصور الأمامية (behindDoc=false)
            ...frontImages,
          ],
        ),
      ),
    );
  }

  /// Check if this is a centered paragraph with tab characters
  bool _isCenteredWithTabs() {
    if (textAlign != TextAlign.center) return false;
    return textRunTs.any((r) => r.hasTab);
  }

  runT? _getSingleVisibleInlineImageRun() {
    final inlineImageRuns = textRunTs
        .where((r) => r.image != null && r.image!.wrapMode == null)
        .toList();
    final specialInlineRuns = inlineImageRuns
        .where((r) => RegExp(r'^rId(1[3-9])$').hasMatch(r.image!.rId))
        .toList();
    if (inlineImageRuns.length != 1) {
      if (specialInlineRuns.isNotEmpty) {
        print(
          'VML_DEBUG_PARAGRAPH: inlineImageRuns=${inlineImageRuns.length} visibleTextCheck=skipped rIds=${specialInlineRuns.map((e) => e.image!.rId).join(',')}',
        );
      }
      return null;
    }

    final visibleTextRuns = textRunTs.where((r) {
      if (r.image != null) {
        return false;
      }
      if (r.rpr?.vanish == true) {
        return false;
      }
      final text = r.text ?? '';
      return text.trim().isNotEmpty;
    }).toList();

    final image = inlineImageRuns.first.image!;
    final bool isSpecialDebugRid = RegExp(r'^rId(1[3-9])$').hasMatch(image.rId);
    if (isSpecialDebugRid) {
      final visibleTexts = visibleTextRuns
          .map((r) => (r.text ?? '').replaceAll('\n', ' '))
          .where((t) => t.trim().isNotEmpty)
          .toList();
      print(
        'VML_DEBUG_PARAGRAPH: candidate rId=${image.rId} inlineImageRuns=${inlineImageRuns.length} visibleTexts=${visibleTexts.join(' | ')} textRunTs=${textRunTs.length} runs=${runs.length}',
      );
    }

    if (visibleTextRuns.isNotEmpty) {
      return null;
    }

    return inlineImageRuns.first;
  }

  /// Build widget for centered paragraphs with tabs (e.g., headers)
  /// Layout: [Spacer] [Text1] [Spacer] [Symbol] [Spacer] [Text2] [Spacer]
  Widget _buildCenteredTabsWidget({bool suppressParagraphBorder = false}) {
    // Split runs by tab characters
    List<List<runT>> segments = [];
    List<runT> currentSegment = [];

    for (runT run in textRunTs) {
      if (run.hasTab) {
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
          currentSegment = [];
        }
      } else {
        currentSegment.add(run);
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    // Build Row with spacers between segments
    List<Widget> children = [];
    for (int i = 0; i < segments.length; i++) {
      if (i > 0) {
        // Add spacer between segments (acts as tab)
        children.add(Spacer());
      }

      // Build segment content
      children.add(
        RichText(
          textDirection: TextDirection.rtl,
          text: TextSpan(
            children: segments[i].map((r) => r.toWidget()).toList(),
          ),
        ),
      );
    }

    // الحدود
    BoxDecoration? decoration = _getParagraphDecoration(
      _getParagraphShadingColor(),
      includeBorder: !suppressParagraphBorder,
    );

    return GestureDetector(
      onLongPress: () => printParagraphXml(),
      child: Padding(
        padding: _getPPaddings(),
        child: Container(
          decoration: decoration,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  void _ensureParagraphXmlForDecoration() {
    if (pPr?.xmlpPr != null) return;
    if (xmlString.isEmpty) return;

    try {
      pXml ??= XmlDocument.parse(xmlString).rootElement;
      pPr?.xmlpPr ??= pXml?.getElement("w:pPr");
      pPr?.xmlprPr ??= pPr?.xmlpPr?.getElement("w:rPr");
    } catch (_) {}
  }

  ParagraphBorderSpec? getParagraphBorderSpec() {
    try {
      _ensureParagraphXmlForDecoration();
      final pBdr = pPr?.xmlpPr?.getElement("w:pBdr");
      if (pBdr == null) return null;

      final top = _parseBorderSideSpec(pBdr.getElement("w:top"));
      final bottom = _parseBorderSideSpec(pBdr.getElement("w:bottom"));
      final left = _parseBorderSideSpec(pBdr.getElement("w:left"));
      final right = _parseBorderSideSpec(pBdr.getElement("w:right"));
      final between = _parseBorderSideSpec(pBdr.getElement("w:between"));

      if (top == null && bottom == null && left == null && right == null) {
        return null;
      }

      return ParagraphBorderSpec(
        signature: pBdr.toXmlString(),
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        between: between,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get paragraph decoration (borders from w:pBdr)
  BoxDecoration? _getParagraphDecoration(
    Color? backgroundColor, {
    bool includeBorder = true,
  }) {
    Border? border = includeBorder ? _getParagraphBorder() : null;
    if (backgroundColor == null && border == null) return null;

    return BoxDecoration(color: backgroundColor, border: border);
  }

  /// Parse paragraph borders from w:pBdr element
  Border? _getParagraphBorder() {
    try {
      _ensureParagraphXmlForDecoration();
      final pBdr = pPr?.xmlpPr?.getElement("w:pBdr");
      if (pBdr == null) return null;

      BorderSide? top, bottom, left, right;

      // Parse each border side
      final topEl = pBdr.getElement("w:top");
      final bottomEl = pBdr.getElement("w:bottom");
      final leftEl = pBdr.getElement("w:left");
      final rightEl = pBdr.getElement("w:right");

      if (topEl != null) top = _parseBorderSide(topEl);
      if (bottomEl != null) bottom = _parseBorderSide(bottomEl);
      if (leftEl != null) left = _parseBorderSide(leftEl);
      if (rightEl != null) right = _parseBorderSide(rightEl);

      if (top == null && bottom == null && left == null && right == null) {
        return null;
      }

      return Border(
        top: top ?? BorderSide.none,
        bottom: bottom ?? BorderSide.none,
        left: left ?? BorderSide.none,
        right: right ?? BorderSide.none,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse a single border side from XML element
  BorderSide? _parseBorderSide(XmlElement element) {
    final spec = _parseBorderSideSpec(element);
    if (spec == null) return null;
    return BorderSide(color: spec.color, width: spec.width);
  }

  ParagraphBorderSideSpec? _parseBorderSideSpec(XmlElement? element) {
    if (element == null) return null;

    String? val = element.getAttribute("w:val");
    if (val == null || val == "nil" || val == "none") return null;

    String? szStr = element.getAttribute("w:sz");
    double width = 1.0;
    if (szStr != null) {
      double sz = double.tryParse(szStr) ?? 8.0;
      width = sz / 8.0;
      if (width < 0.5) width = 0.5;
      if (width > 6) width = 6;
    }

    String? spaceStr = element.getAttribute("w:space");
    double space = 0;
    if (spaceStr != null) {
      space = double.tryParse(spaceStr) ?? 0;
    }

    Color color = Colors.black;
    String? colorStr = element.getAttribute("w:color");
    String? themeColor = element.getAttribute("w:themeColor");
    if (themeColor != null) {
      String? resolved = resolveThemeColor(
        pPr?.wordDocument.themeColors ?? {},
        themeColor,
        element.getAttribute("w:themeTint"),
        element.getAttribute("w:themeShade"),
      );
      colorStr = resolved ?? colorStr;
    }
    if (colorStr != null && colorStr != "auto") {
      try {
        String hex = colorStr;
        if (hex.length == 6) hex = "FF$hex";
        color = Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }

    return ParagraphBorderSideSpec(
      style: val,
      width: width,
      space: space,
      color: color,
    );
  }

  /// Build a special widget for TOC (Table of Contents) entries
  /// Uses Row layout: [Entry Text] [Dot Leaders] [Page Number]
  Widget _buildTOCWidget() {
    // Split runs at the LAST tab (the leader tab before page number).
    // Earlier tabs are internal (e.g. between "1-" and text).
    List<runT> entryRuns = [];
    List<runT> pageNumRuns = [];
    int lastTabIndex = -1;
    for (int i = textRunTs.length - 1; i >= 0; i--) {
      if (textRunTs[i].hasTab) {
        lastTabIndex = i;
        break;
      }
    }

    for (int i = 0; i < textRunTs.length; i++) {
      if (i == lastTabIndex) continue; // Skip the leader tab itself
      if (lastTabIndex != -1 && i > lastTabIndex) {
        pageNumRuns.add(textRunTs[i]);
      } else {
        entryRuns.add(textRunTs[i]);
      }
    }

    // For TOC entries rendered as a single-line Row, the effective leading-edge
    // indent is the sum of paragraph indent (w:left) and firstLine indent
    // (w:firstLine), because the entire entry text represents the "first line."
    // Common TOC pattern: negative w:left + large w:firstLine = positive indent.
    // Clamp to non-negative: Flutter Padding does not allow negative values.
    double indent = (pPr?.paddingRight ?? 0) + (pPr?.firstLineIndent ?? 0);
    if (indent < 0) indent = 0;

    // Get leader type from tab stops
    String leaderType = "dot";
    TabStop? rightTab = pPr?.getRightTabStop();
    if (rightTab != null && rightTab.hasLeader) {
      leaderType = rightTab.leader ?? "dot";
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTOCTap(),
        hoverColor: Colors.blue.withOpacity(0.1),
        splashColor: Colors.blue.withOpacity(0.2),
        child: Padding(
          padding: EdgeInsets.only(
            right: 8 + indent,
            left: 8,
            top: 2,
            bottom: 2,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // 1. Entry text (takes natural width, no flex competition)
                Flexible(
                  flex: 0,
                  child: RichText(
                    textDirection: TextDirection.rtl,
                    text: TextSpan(
                      style: prPr?.getTextStyle(),
                      children: entryRuns.map((r) => r.toWidget()).toList(),
                    ),
                  ),
                ),

                // 2. Dot leaders (expands to fill available space)
                Expanded(
                  child: _buildLeaderWidget(
                    leaderType,
                    fontFamily: parent.parent.minorFont,
                    fontSize: _getTocMainFontSize(entryRuns),
                  ),
                ),

                // 3. Page number (fixed, at the end)
                if (pageNumRuns.isNotEmpty)
                  RichText(
                    textDirection: TextDirection.ltr, // Numbers are LTR
                    text: TextSpan(
                      style: prPr?.getTextStyle(),
                      children: pageNumRuns.map((r) => r.toWidget()).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get the main font from TOC entry runs (first run that has a font defined)
  String? _getTocMainFont(List<runT> entryRuns) {
    for (runT run in entryRuns) {
      if (run.rpr?.font != null && run.rpr!.font!.isNotEmpty) {
        return run.rpr!.font;
      }
    }
    return null;
  }

  /// Get the main font size from TOC entry runs (first run that has a font size defined)
  double? _getTocMainFontSize(List<runT> entryRuns) {
    for (runT run in entryRuns) {
      if (run.rpr?.fontSize != null) {
        return run.rpr!.fontSize;
      }
    }
    return null;
  }

  /// Build a leader widget (dots, underscores, etc.) for TOC
  Widget _buildLeaderWidget(
    String leaderType, {
    String? fontFamily,
    double? fontSize,
  }) {
    String leaderChar;
    switch (leaderType) {
      case "dot":
        leaderChar = ".";
        break;
      case "underscore":
        leaderChar = "_";
        break;
      case "hyphen":
        leaderChar = "-";
        break;
      default:
        leaderChar = ".";
    }

    // Use font from runs, fallback to jreg
    final effectiveFont = fontFamily ?? "jreg";
    final effectiveSize = fontSize ?? 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate char width based on font size
        double charWidth = leaderChar == "."
            ? (effectiveSize * 0.3)
            : (effectiveSize * 0.5);
        int charCount = (constraints.maxWidth / charWidth).floor();
        if (charCount < 3) charCount = 3;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            leaderChar * charCount,
            textDirection: TextDirection.ltr,
            overflow: TextOverflow.clip,
            maxLines: 1,
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: effectiveSize,
              letterSpacing: 1.0,
              color: Colors.black54,
            ),
          ),
        );
      },
    );
  }

  /// Handle tap on TOC entry - navigate to target page
  void _handleTOCTap() {
    // Use cached hyperlinkAnchor first, fallback to XML if available
    String? anchor = hyperlinkAnchor;
    if (anchor == null && pXml != null) {
      XmlElement? hyperlink = pXml?.getElement("w:hyperlink");
      anchor = hyperlink?.getAttribute("w:anchor");
    }

    if (anchor != null) {
      // Remove leading underscore if present (e.g., "_Toc123456" -> "Toc123456")
      String bookmarkName = anchor.startsWith("_")
          ? anchor.substring(1)
          : anchor;

      // Look up the page from bookmarks map
      int? targetPage =
          parent.parent.bookMarksMap[bookmarkName] ??
          parent.parent.bookMarksMap["_$bookmarkName"];

      if (targetPage != null) {
        // print("TOC: Navigating to page $targetPage for bookmark $bookmarkName");
        // Call the navigation callback if set
        if (AppState().onTocNavigate != null) {
          AppState().onTocNavigate!(targetPage);
        }
      } else {
        /* print("TOC: Bookmark not found: $bookmarkName");
        print(
          "     Available bookmarks: ${parent.parent.bookMarksMap.keys.take(10).toList()}...",
        ); */
      }
    } else {
      // print("TOC: No anchor found for this entry");
    }
  }

  // قراءة تظليل الفقرة من w:pPr/w:shd
  Color? _getParagraphShadingColor() {
    try {
      _ensureParagraphXmlForDecoration();
      final shd = pPr?.xmlpPr?.getElement("w:shd");
      if (shd == null) return null;

      // حل لون التيمة أولاً (themeFill + tint/shade)
      String? themeFill = shd.getAttribute("w:themeFill");
      if (themeFill != null) {
        String? resolved = resolveThemeColor(
          pPr?.wordDocument.themeColors ?? {},
          themeFill,
          shd.getAttribute("w:themeFillTint"),
          shd.getAttribute("w:themeFillShade"),
        );
        if (resolved != null && resolved.length == 6) {
          return Color(int.parse("0xFF$resolved"));
        }
      }

      // fallback: w:fill
      final fill = shd.getAttribute("w:fill");
      if (fill == null || fill.isEmpty) return null;
      String hex = fill;
      if (hex.length == 6) {
        hex = "FF$hex";
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  // دالة معدلة لتقبل فلتر behindDoc
  List<Widget> _getPositionedImages(bool behindDoc) {
    // الحصول على الهوامش لحساب الموقع النسبي الصحيح
    final sectPr = parent.parent.getSectPrForPage(parent.pageIndex);
    double leftMargin = sectPr.leftMargin ?? 0;
    double pageWidth = sectPr.width ?? 595;
    double rightMargin = sectPr.rightMargin ?? 0;
    double marginAreaWidth = pageWidth - leftMargin - rightMargin;

    List<Widget> widgets = [];

    // حساب أقصى ارتفاع للصور الملتفة (Wrapping Images)
    // نستخدم ارتفاع الصورة فقط (وليس موقعها المطلق) لأن أنظمة الإحداثيات قد تختلف
    double maxWrapImageHeight = 0;
    if (!behindDoc) {
      for (var run in runs) {
        if (run.image != null) {
          var img = run.image!;
          // نتحقق إذا كانت الصورة تسبب التفافاً (ليست خلف النص ولها خاصية التفاف)
          if (!img.behindDoc &&
              (img.wrapMode == "Square" ||
                  img.wrapMode == "TopAndBottom" ||
                  img.wrapMode == "Tight" ||
                  img.wrapMode == "Through")) {
            // نستخدم أكبر ارتفاع صورة (وليس موقعها المطلق)
            if (img.height > maxWrapImageHeight) {
              maxWrapImageHeight = img.height;
            }
          }
        }
      }
    }

    // ترتيب الصور حسب z-index/relativeHeight تصاعدياً
    // في Stack، العناصر الأخيرة تظهر فوق العناصر الأولى
    // لذا القيمة الأقل تأتي أولاً (تظهر تحت)
    var sortedImageRuns = imageRunTs
        .where((r) => r.image != null && r.image!.behindDoc == behindDoc)
        .toList();

    double _effectiveHeight(ImageData img) {
      if (img.vmlZIndex != 0) {
        return img.vmlZIndex;
      }
      return img.relativeHeight;
    }

    sortedImageRuns.sort((a, b) {
      final aImg = a.image!;
      final bImg = b.image!;
      final aHeight = _effectiveHeight(aImg);
      final bHeight = _effectiveHeight(bImg);

      if (aHeight != bHeight) {
        return aHeight.compareTo(bHeight);
      }

      final aType = aImg.vmlShapeData?.shapeType.toLowerCase();
      final bType = bImg.vmlShapeData?.shapeType.toLowerCase();
      if (aType == 'line' && bType != 'line') return -1;
      if (bType == 'line' && aType != 'line') return 1;

      return aImg.posY.compareTo(bImg.posY);
    });

    // debug ordering for imaging layer decisions
    for (var run in sortedImageRuns) {
      var img = run.image!;
      final zIndexDebug = img.vmlZIndex != 0 ? img.vmlZIndex : img.relativeHeight;
      print('VML_DEBUG_ORDER: image rId=${img.rId} shape=${img.vmlShapeData?.shapeType ?? 'none'} behind=${img.behindDoc} relHeight=${img.relativeHeight} vmlZIndex=${img.vmlZIndex} effectiveHeight=${zIndexDebug} posY=${img.posY}');

      double left = 0;
      double top = img.posY; // relativeFromV="paragraph" يعني posY نسبي للفقرة

      // تصحيح موقع مربعات النص إذا كان هناك صور تسبب التفافاً
      // نستخدم ارتفاع الصورة كموقع جديد (الصورة تبدأ من أعلى الفقرة تقريباً)
      if (maxWrapImageHeight > 0 &&
          img.relativeFromV == "paragraph" &&
          (img.textBoxText != null && img.textBoxText!.isNotEmpty)) {
        // إذا كان موقع مربع النص الأصلي داخل منطقة الصورة الملتفة
        if (top < maxWrapImageHeight) {
          // نضعه مباشرة بعد الصورة (بنسبة 90% من ارتفاعها)
          top = maxWrapImageHeight * 0.90;
        }
        // وإلا نبقي الموقع الأصلي (top) كما هو لأنه أصلاً أسفل الصورة
      }

      // حساب left بناءً على المحاذاة أو الإحداثيات
      // هذا المنطق مشابه لـ ImageToWidget.dart لكن مخصص للفقرة
      bool usesHAlign =
          img.posX == 0 && (img.alignH == "center" || img.alignH == "right");

      if (usesHAlign && img.alignH == "center") {
        // التمركز بالنسبة لمنطقة الهامش (عرض الصفحة - الهوامش)
        // داخل الفقرة، (0,0) هو بداية منطقة الهامش
        left = (marginAreaWidth - img.width) / 2;
      } else if (usesHAlign && img.alignH == "right") {
        left = marginAreaWidth - img.width;
      } else {
        // استخدام posX
        // إذا كان relativeFromH="page"، فهو نسبي للصفحة الكاملة
        // لكن الفقرات داخل المحتوى تُعرض بعد leftMargin
        if (img.relativeFromH == "page") {
          if (isHeaderParagraph) {
            // في الهيدر نضع الصورة مباشرة بناءً على إحداثيات الصفح
            left = img.posX;
          } else {
            // في المحتوى العام نخصم leftMargin لأن الحاوية تبدأ عند منطقة النص
            left = img.posX - leftMargin;
          }
        } else {
          left = img.posX;
        }
      }

      widgets.add(
        Positioned(
          left: left.isFinite ? left : 0,
          top: top.isFinite ? top : 0,
          // إذا كانت هذه فقرة هيدر، نجعل الصورة تتجاهل الضغط
          // حتى يعمل الضغط المطول على الهيدر
          // IgnorePointer prevents images from capturing pointer events
          // (which would block text selection/scrolling underneath)
          child: IgnorePointer(
            child: GestureDetector(
              onTap: () {
                /* print(
                  "═══════════════════════════════════════════════════════════",
                );
                print("IMAGE TAPPED (Positioned in Paragraph): ${img.rId}");
                print("  Calculated: left=$left, top=$top");
                print("  XML: posX=${img.posX}, posY=${img.posY}");
                print("  behindDoc: ${img.behindDoc}");
                print("  isHeaderParagraph: $isHeaderParagraph");
                print("  TextBox Content: ${img.textBoxText}");
                print(
                  "  Font: ${img.fontFamily}, Size: ${img.textSize}, Color: ${img.textColor}",
                );
                print(
                  "═══════════════════════════════════════════════════════════",
                ); */
              },
              child: Builder(
                builder: (context) {
                  // NEW: Handle VML shapes via VmlRendererWidget
                  if (img.vmlShapeData != null) {
                    return getImageWidget(img, innerOnly: true);
                  }

                  // NEW: Handle Group Images via ImageToWidget logic
                  if (img.isGroup) {
                    return getImageWidget(img, innerOnly: true);
                  }

                  // NEW: Handle Vector Shapes (Freeform etc.)
                  if (img.isVectorShape && img.vectorPath != null) {
                    return getImageWidget(img, innerOnly: true);
                  }

                  // عرض Text Box (تمت إعادته ليعمل داخل Stack)
                  if (img.textBoxText != null && img.textBoxText!.isNotEmpty) {
                    Color textColor = Colors.black;

                    if (img.textColor != null) {
                      try {
                        String hex = img.textColor!;
                        if (hex.length == 6) {
                          hex = "FF" + hex;
                        }
                        textColor = Color(int.parse(hex, radix: 16));
                      } catch (e) {
                        print("Error parsing color: ${img.textColor}");
                      }
                    }

                    // حجم الخط في الوورد بوحدة نصف-نقطة. في Flutter نحتاج تقريباً 1.33x ليطابق الـ pt.
                    double fontSize = ((img.textSize ?? 20.0) * 1.333);
                    String? fontFamily = img.fontFamily;

                    // استبدال النص برقم الصفحة الفعلي إذا كان يحتوي على حقل PAGE
                    String displayText = img.textBoxText!;
                    if (img.containsPageField && customPageNumber != null) {
                      displayText = customPageNumber!;
                    }

                    return Container(
                      width: img.width > 0 ? img.width : null,
                      height: img.height > 0 ? img.height : null,
                      alignment: Alignment.center,
                      child: Text(
                        displayText,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                          height: 1.05,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                        ),
                      ),
                    );
                  }

                  if (img.imageMemory == null || img.imageMemory!.isEmpty) {
                    return SizedBox.shrink();
                  }

                  // التحقق من صحة البيانات (Magic Bytes)
                  bool isValid = false;
                  if (img.imageMemory!.length > 4) {
                    // PNG: 89 50 4E 47
                    if (img.imageMemory![0] == 0x89 &&
                        img.imageMemory![1] == 0x50 &&
                        img.imageMemory![2] == 0x4E &&
                        img.imageMemory![3] == 0x47) {
                      isValid = true;
                      // print("✅ Valid PNG detected for ${img.rId} in Paragraph");
                    }
                    // JPEG: FF D8 FF
                    else if (img.imageMemory![0] == 0xFF &&
                        img.imageMemory![1] == 0xD8 &&
                        img.imageMemory![2] == 0xFF) {
                      isValid = true;
                    }
                    // GIF: 47 49 46 38
                    else if (img.imageMemory![0] == 0x47 &&
                        img.imageMemory![1] == 0x49 &&
                        img.imageMemory![2] == 0x46 &&
                        img.imageMemory![3] == 0x38) {
                      isValid = true;
                    }
                    // WebP: 52 49 46 46 ... 57 45 42 50 (RIFF ... WEBP)
                    else if (img.imageMemory![0] == 0x52 &&
                        img.imageMemory![1] == 0x49 &&
                        img.imageMemory![2] == 0x46 &&
                        img.imageMemory![3] == 0x46) {
                      isValid = true;
                    }
                    // EMF: 01 00 00 00
                    else if (img.imageMemory![0] == 0x01 &&
                        img.imageMemory![1] == 0x00 &&
                        img.imageMemory![2] == 0x00 &&
                        img.imageMemory![3] == 0x00) {
                      // محاولة استخراج PNG أو JPEG من داخل EMF
                      Uint8List? extracted = _extractImageFromEmf(
                        img.imageMemory!,
                      );
                      if (extracted != null) {
                        return Image.memory(
                          extracted,
                          width: img.width,
                          height: img.height,
                          fit: BoxFit.fill,
                        );
                      }

                      /* print(
                        "⚠️ EMF Image detected (rId: ${img.rId}) - Not supported natively by Flutter",
                      ); */
                      return Container(
                        width: img.width,
                        height: img.height,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          color: Colors.blue.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Text(
                            "EMF Image\n(Not Supported)",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                        ),
                      );
                    }
                  }

                  if (!isValid) {
                    print(
                      "⚠️ Invalid Image Format for rId: ${img.rId} (First 4 bytes: ${img.imageMemory!.take(4).toList()})",
                    );
                    return Container(
                      width: img.width,
                      height: img.height,
                      color: Colors.orange.withOpacity(0.2),
                      child: Center(
                        child: Text(
                          "Invalid Format",
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    );
                  }

                  // إنشاء widget الصورة
                  Widget imageWidget = Image.memory(
                    img.imageMemory!,
                    width: img.width,
                    height: img.height,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      /* print(
                        "═══════════════════════════════════════════════════════════",
                      );
                      print("❌ ERROR LOADING IMAGE: ${img.rId}");
                      print("  Error: $error");
                      print("  Data length: ${img.imageMemory?.length} bytes");
                      print(
                        "═══════════════════════════════════════════════════════════",
                      ); */
                      return Container(
                        width: img.width,
                        height: img.height,
                        color: Colors.red.withOpacity(0.2),
                        child: Center(
                          child: Icon(Icons.broken_image, color: Colors.red),
                        ),
                      );
                    },
                  );

                  return imageWidget;
                },
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// حفظ XML الفقرة في ملف للديبوج
  void printParagraphXml() async {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("=== Paragraph XML Debug ===");
    buffer.writeln("Section Type: $sectionType");
    buffer.writeln("Is Header: $isHeaderParagraph");
    buffer.writeln("");

    if (xmlString.isNotEmpty) {
      buffer.writeln(xmlString);
    } else if (pXml != null) {
      buffer.writeln(pXml!.toXmlString(pretty: true));
    } else {
      buffer.writeln("No XML found for this paragraph.");
    }

    buffer.writeln("");
    buffer.writeln("--- FONTS USED ---");
    int runIndex = 1;
    for (var run in textRunTs) {
      String preview = run.text ?? "";
      if (preview.length > 20) preview = preview.substring(0, 20) + "...";
      preview = preview.replaceAll("\n", "\\n");

      String? arFont = run.rpr?.font;
      String? enFont = run.rpr?.enFont;

      if (preview.trim().isNotEmpty) {
        buffer.writeln(
          "Run $runIndex (\"$preview\"): Ar: $arFont | En: $enFont",
        );
        runIndex++;
      }
    }

    buffer.writeln("");
    buffer.writeln("--- ALL RUNS (${runs.length} total) ---");
    int idx = 0;
    for (var run in runs) {
      idx++;
      bool hasImage = run.image != null;
      String imgInfo = hasImage
          ? "rId=${run.image!.rId}, wrapMode=${run.image!.wrapMode}, relFromV=${run.image!.relativeFromV}, mem=${run.image!.imageMemory != null ? '${run.image!.imageMemory!.length}b' : 'null'}"
          : "NO IMAGE";
      String textPreview = run.text ?? "";
      if (textPreview.length > 15)
        textPreview = textPreview.substring(0, 15) + "...";
      buffer.writeln("Run $idx: text=\"$textPreview\" | $imgInfo");
    }

    buffer.writeln("");
    buffer.writeln(
      "--- imageRunTs (${imageRunTs.length}) | textRunTs (${textRunTs.length}) ---",
    );
    for (var run in imageRunTs) {
      if (run.image != null) {
        buffer.writeln("Image rId: ${run.image!.rId}");
        buffer.writeln(
          "  Width: ${run.image!.width}, Height: ${run.image!.height}",
        );
        buffer.writeln("  Has imageMemory: ${run.image!.imageMemory != null}");
        if (run.image!.imageMemory != null) {
          buffer.writeln(
            "  imageMemory length: ${run.image!.imageMemory!.length} bytes",
          );
          if (run.image!.imageMemory!.length > 4) {
            buffer.writeln(
              "  First 4 bytes: ${run.image!.imageMemory!.take(4).toList()}",
            );
          }
        }
      }
    }

    buffer.writeln(
      "═══════════════════════════════════════════════════════════════════",
    );

    // إذا كانت الفقرة حاشية، نضيف XML الحاشية الخام من الأرشيف
    if (sectionType == 'footnote') {
      buffer.writeln("");
      buffer.writeln("=== FOOTNOTE RAW XML FROM ARCHIVE ===");
      try {
        var archive = parent.parent.archive;
        if (archive != null) {
          var archiveMap = archive.toMap();
          var footnotesFile = archiveMap['word/footnotes.xml'];
          if (footnotesFile != null) {
            debugDumpFootnotesXml(footnotesFile);
            buffer.writeln(
              "✅ Full footnotes.xml dumped to footnotes_debug.xml",
            );
          } else {
            buffer.writeln("⚠️ footnotes.xml not found in archive");
          }
        } else {
          buffer.writeln("⚠️ Archive not available (book loaded from cache?)");
        }
      } catch (e) {
        buffer.writeln("❌ Error dumping footnote XML: $e");
      }
    }

    // حفظ في ملف
    try {
      final file = File(
        'd:/ImportantProjects/golden_shamela/paragraph_debug.xml',
      );
      await file.writeAsString(buffer.toString());
      print("DEBUG: Paragraph XML saved to ${file.path}");
    } catch (e) {
      print("DEBUG: Error saving paragraph XML: $e");
      // Fallback to console
      print(buffer.toString());
    }
  }

  void fixPDirection() {
    // in some times runs have rtl and ppr and prpr does not, so this fix rtl
    if (pPr?.rtl != null) return;
    for (runT r in runs) {
      if (r.rpr?.rtl != null) {
        pPr?.rtl = r.rpr?.rtl;
        break;
      }
    }
  }

  /// Extract bookmarks from paragraph level XML
  /// w:bookmarkStart is a sibling of w:r, not a child, so we need to search at paragraph level
  void _extractBookmarks() {
    if (pXml == null) return;

    // Find all bookmarkStart elements at paragraph level
    for (XmlElement element in pXml!.childElements) {
      if (element.name.local == "bookmarkStart") {
        String? bookmarkName = element.getAttribute("w:name");
        if (bookmarkName != null && bookmarkName.isNotEmpty) {
          // Skip internal Word bookmarks (start with underscore but not Toc)
          if (bookmarkName.startsWith("_") && !bookmarkName.contains("Toc")) {
            continue;
          }
          // print("DEBUG: Found bookmark at paragraph level: $bookmarkName (page ${parent.pageIndex})");
          parent.parent.addBookMark(bookmarkName, pageIndex: parent.pageIndex);
        }
      }
    }
  }

  getPageNum() {
    // Only try to get from instrText if pageNum wasn't already set
    // (e.g., from {{PG:X}} marker injected by pageRender.py)
    if (pageNum.isNotEmpty) return;

    pageNum =
        pXml
            ?.findAllElements("w:instrText")
            .where((e) => e.text.toString().trim().isNotEmpty)
            .firstOrNull
            ?.text ??
        "";
  }

  void getPAlign() {
    TextAlign? alignFromPPr = pPr?.getTextAlignW();
    textAlign = alignFromPPr ?? TextAlign.start;
  }

  void getPTextDirection() {
    textDirection =
        pPr?.getTextDirectionW() ??
        prPr?.getTextDirection() ??
        TextDirection.rtl;
  }

  List<InlineSpan> getAllPSpans() {
    List<InlineSpan> spans = [
      pPr?.getNumberingW() ?? TextSpan(text: ""),

      ...runs.map((e) => e.toWidgetWithImg()).toList(),
    ];
    spans = fixRtlWidgetSpan(spans);
    return spans;
  }

  List<InlineSpan> getPSpans() {
    // If no runs and no numbering, it might be an empty paragraph (new line)
    // We should add a generic run to ensure it takes up space (line height)
    if (textRunTs.isEmpty && (pPr?.numId == null)) {
      return [TextSpan(text: "\u00A0")]; // Non-breaking space
    }

    List<InlineSpan> spans = [
      // w:firstLine — indent ONLY the first line (not all lines like container padding would)
      if (pPr?.firstLineIndent != null && pPr!.firstLineIndent! > 0)
        WidgetSpan(child: SizedBox(width: pPr!.firstLineIndent!)),
      pPr?.getNumberingW() ?? TextSpan(text: ""),
      ...textRunTs.map((e) => e.toWidgetWithImg()).toList(),
    ];
    spans = fixRtlWidgetSpan(spans);
    return spans;
  }

  EdgeInsets _getPPaddings() {
    // Sanitize padding to prevent negative values which crash Flutter's Padding widget
    // Word allows negative indentation (hanging), but Flutter Padding does not.
    double left = pPr?.paddingLeft ?? 0;
    double right = pPr?.paddingRight ?? 0;
    double top = pPr?.spacingBefore ?? 0;
    // Footnote paragraphs inherit from "Footnote Text" style which has w:after="0".
    // PPr defaults to ~18.7px when no w:spacing element exists (body-text default).
    // For footnotes, only apply spacingAfter when it was explicitly set in the XML.
    double bottom =
        (sectionType == 'footnote' && pPr?.spacingAfterExplicit != true)
        ? 0
        : (pPr?.spacingAfter ?? 0);

    return EdgeInsets.only(
      left: left < 0 ? 0 : left,
      right: right < 0 ? 0 : right,
      top: top < 0 ? 0 : top,
      bottom: bottom < 0 ? 0 : bottom,
    );
  }

  _getImageRunsW() {
    // العودة للطريقة الأصلية - استخدام getImageWidget
    return Stack(
      fit: StackFit.loose,
      children: [
        ...imageRunTs.map((runImage) => getImageWidget(runImage.image!)),
      ],
    );
  }

  _getTRunsW(List<InlineSpan> spans) {
    // Use Word 2007+ default (1.15) if lineHeight is not specified
    double effectiveLineHeight = pPr?.lineHeight ?? 1.15;

    // Calculate max font size from runs to ensure StrutStyle fits the largest text
    // This fixes the issue where paragraph default (e.g. 13.5pt) is used for Strut,
    // causing 20pt text runs to overlap because the line box is too small.
    double maxFontSize = prPr?.fontSize ?? 14.0;
    for (var run in textRunTs) {
      if (run.rpr?.fontSize != null) {
        if (run.rpr!.fontSize! > maxFontSize) {
          maxFontSize = run.rpr!.fontSize!;
        }
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(style: prPr?.getTextStyle(), children: spans),
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: !preventWrap,
        overflow: preventWrap ? TextOverflow.visible : TextOverflow.clip,
        strutStyle: StrutStyle(
          forceStrutHeight: !textRunTs.any((r) => r.image != null),
          height: effectiveLineHeight,
          fontSize: maxFontSize,
          fontFamily: prPr?.enFont,
          fontFamilyFallback: prPr?.font != null ? [prPr!.font!] : null,
        ),
      ),
    );
  }

  /// محاولة بسيطة لاستخراج صورة (PNG/JPG) مضمنة داخل ملف EMF
  /// يبحث عن توقيع PNG أو JPEG ويعيد البيانات من تلك النقطة
  Uint8List? _extractImageFromEmf(Uint8List emfData) {
    // البحث عن توقيع PNG: 89 50 4E 47
    for (int i = 0; i < emfData.length - 8; i++) {
      if (emfData[i] == 0x89 &&
          emfData[i + 1] == 0x50 &&
          emfData[i + 2] == 0x4E &&
          emfData[i + 3] == 0x47) {
        print("✅ Found PNG inside EMF at offset $i");
        return emfData.sublist(
          i,
        ); // قد يحتوي على بيانات زائدة في النهاية، لكن Image.memory عادة يتجاهلها
      }
    }

    // البحث عن توقيع JPEG: FF D8 FF
    for (int i = 0; i < emfData.length - 3; i++) {
      if (emfData[i] == 0xFF &&
          emfData[i + 1] == 0xD8 &&
          emfData[i + 2] == 0xFF) {
        print("✅ Found JPEG inside EMF at offset $i");
        return emfData.sublist(i);
      }
    }

    return null;
  }
}
