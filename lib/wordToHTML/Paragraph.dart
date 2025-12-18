import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:golden_shamela/TestApp2.dart';
import 'package:golden_shamela/wordToHTML/ParagraphHyperLink.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/wordToHTML/TabStop.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';

import 'package:golden_shamela/Utils/custom_text_selection_controls.dart';
import 'package:golden_shamela/Utils/json_converters.dart';
import 'package:golden_shamela/wordToHTML/ParagraphTable.dart';

import '../WordToWidget/ImageToWidget.dart';
import '../core/app_state.dart';
import 'PPr.dart';

part 'Paragraph.g.dart';

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

  Paragraph fromXml(XmlElement paragraphXml) {
    pXml = paragraphXml;
    // حفظ XML كنص مع إخفاء بيانات الصور الطويلة
    xmlString = _sanitizeXmlForStorage(paragraphXml.toXmlString(pretty: true));
    XmlElement? xmlpPr = paragraphXml.getElement("w:pPr");
    if (xmlpPr != null) pPr = PPr(this).fromXml(xmlpPr);

    _setSectionType();

    XmlElement? xmlprPr = pPr?.xmlprPr;
    text = paragraphXml.text; // Re-add text assignment

    if (xmlprPr != null) prPr = RPr(pPr!.getEmptyRun()).fromXml(xmlprPr);

    // Fallback to defaultRPr if font is missing
    if (prPr != null && prPr!.font == null) {
      prPr!.font = pPr?.wordDocument.defaultRPr?.font;
    }

    runs = [];

    bool inFieldCode = false;
    bool pendingPageNum = false;
    bool pageNumReplaced =
        false; // Track if we already replaced the page number

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
          if (element
              .findAllElements("w:instrText")
              .any((e) => e.text.contains("PAGE"))) {
            pendingPageNum = true;
            pageNumReplaced = false; // Reset when starting a new PAGE field
          }
        }

        runT runt0 = runT(
          this,
          prPr: prPr,
          pPr: pPr,
          customRelIdList: customRelIdList,
        ).fromXml(element);

        if (inFieldCode && !hasSeparate && !hasEnd && !hasBegin) {
          runt0.text = "";
        }

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
        }

        runt0.parent = this;
        pPr?.parent = this;
        prPr?.parent = runt0;
        runs.add(runt0);
      } else if (element.name.local == "fldSimple") {
        String? instr = element.getAttribute("w:instr");
        if (instr != null &&
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
    });
    fixPDirection();
    getPAlign();
    getPTextDirection();
    getPageNum();
    checkHyperLink();
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

  void _setSectionType() {
    String? style = pPr?.pStyle?.toLowerCase();
    if (style == null) {
      sectionType = 'main';
      return;
    }

    if (style.startsWith('heading') || style == 'title') {
      sectionType = 'title';
    } else {
      sectionType = 'main';
    }
  }

  getPRunsByType() {
    imageRunTs = [];
    textRunTs = [];
    runs.forEach((runt) {
      if (runt.image != null && runt.isRelativeFromVParagraph()) {
        imageRunTs.add(runt);
      } else {
        textRunTs.add(runt);
      }
    });
    return {"iRuns": imageRunTs, "tRuns": textRunTs};
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

  Widget toWidget() {
    // Check if this is a TOC entry OR uses right-aligned leader tabs - use special rendering
    // This ensures proportional tabs and leaders (tastir) appear correctly without stretching left tabs
    if (shouldRenderAsTOC()) {
      return _buildTOCWidget();
    }

    // Check for centered paragraph with tabs (like headers: "أعمال [TAB] ❀ [TAB] الرافعي")
    // These need Row layout to distribute content evenly
    if (_isCenteredWithTabs()) {
      return _buildCenteredTabsWidget();
    }

    List<InlineSpan> spans = getPSpans();

    // لون تظليل الفقرة (إن وجد في w:pPr/w:shd)
    Color? backgroundColor = _getParagraphShadingColor();

    // الحدود (إن وجدت في w:pPr/w:pBdr)
    BoxDecoration? decoration = _getParagraphDecoration(backgroundColor);

    // تقسيم الصور إلى مجموعتين: خلف النص وأمام النص
    List<Widget> behindImages = _getPositionedImages(true);
    List<Widget> frontImages = _getPositionedImages(false);

    return GestureDetector(
      onLongPress: () {
        _printParagraphXml();
      },
      child: Padding(
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
      ),
    );
  }

  /// Check if this is a centered paragraph with tab characters
  bool _isCenteredWithTabs() {
    if (textAlign != TextAlign.center) return false;
    return textRunTs.any((r) => r.hasTab);
  }

  /// Build widget for centered paragraphs with tabs (e.g., headers)
  /// Layout: [Spacer] [Text1] [Spacer] [Symbol] [Spacer] [Text2] [Spacer]
  Widget _buildCenteredTabsWidget() {
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
    );

    return GestureDetector(
      onLongPress: () => _printParagraphXml(),
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

  /// Get paragraph decoration (borders from w:pBdr)
  BoxDecoration? _getParagraphDecoration(Color? backgroundColor) {
    Border? border = _getParagraphBorder();
    if (backgroundColor == null && border == null) return null;

    return BoxDecoration(color: backgroundColor, border: border);
  }

  /// Parse paragraph borders from w:pBdr element
  Border? _getParagraphBorder() {
    try {
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
    String? val = element.getAttribute("w:val");
    if (val == null || val == "nil" || val == "none") return null;

    // w:sz is in eighths of a point
    String? szStr = element.getAttribute("w:sz");
    double width = 1.0;
    if (szStr != null) {
      double sz = double.tryParse(szStr) ?? 8.0;
      width = sz / 8.0; // Convert to points
      if (width < 0.5) width = 0.5;
      if (width > 6) width = 6; // Cap for sanity
    }

    // Parse color
    Color color = Colors.black;
    String? colorStr = element.getAttribute("w:color");
    if (colorStr != null && colorStr != "auto") {
      try {
        String hex = colorStr;
        if (hex.length == 6) hex = "FF$hex";
        color = Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }

    return BorderSide(color: color, width: width);
  }

  /// Build a special widget for TOC (Table of Contents) entries
  /// Uses Row layout: [Entry Text] [Dot Leaders] [Page Number]
  Widget _buildTOCWidget() {
    // Extract the runs into three parts:
    // 1. Entry text runs (before the tab)
    // 2. Tab run (contains the leader)
    // 3. Page number runs (after the tab)
    List<runT> entryRuns = [];
    List<runT> pageNumRuns = [];
    bool foundTab = false;

    for (runT run in textRunTs) {
      if (run.hasTab) {
        foundTab = true;
      } else if (!foundTab) {
        entryRuns.add(run);
      } else {
        pageNumRuns.add(run);
      }
    }

    // Calculate indentation based on TOC level
    double indent = ((pPr?.tocLevel ?? 1) - 1) * 24.0;

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
            right: indent, // RTL: indent from right
            left: pPr?.paddingLeft ?? 0,
            top: 2,
            bottom: 2,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl, // TOC entries are RTL
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // 1. Entry text (flexible, wraps if needed)
                Flexible(
                  flex: 0,
                  child: RichText(
                    textDirection: TextDirection.rtl,
                    text: TextSpan(
                      children: entryRuns.map((r) => r.toWidget()).toList(),
                    ),
                  ),
                ),

                // 2. Dot leaders (expands to fill available space)
                // Get font from entry run that has a font defined
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
                      children: pageNumRuns.map((r) {
                        return r.toWidget();
                      }).toList(),
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
      final shd = pPr?.xmlpPr?.getElement("w:shd");
      final fill = shd?.getAttribute("w:fill");
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
    double leftMargin = parent.parent.getPageSectPr().leftMargin ?? 0;
    double pageWidth = parent.parent.getPageSectPr().width ?? 595;
    double rightMargin = parent.parent.getPageSectPr().rightMargin ?? 0;
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

    // ترتيب الصور حسب relativeHeight تصاعدياً
    // في Stack، العناصر الأخيرة تظهر فوق العناصر الأولى
    // لذا relativeHeight الأقل يأتي أولاً (يظهر تحت)
    var sortedImageRuns = imageRunTs
        .where((r) => r.image != null && r.image!.behindDoc == behindDoc)
        .toList();
    sortedImageRuns.sort(
      (a, b) => a.image!.relativeHeight.compareTo(b.image!.relativeHeight),
    );

    for (var run in sortedImageRuns) {
      var img = run.image!;

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
        // إذا كان relativeFromH="column" (margin)، فهو نسبي لبداية الفقرة -> left = posX
        // إذا كان relativeFromH="page"، فهو نسبي للصفحة -> left = posX - leftMargin
        if (img.relativeFromH == "page") {
          left = img.posX - leftMargin;
        } else {
          left = img.posX;
        }
      }

      widgets.add(
        Positioned(
          left: left,
          top: top,
          // إذا كانت هذه فقرة هيدر، نجعل الصورة تتجاهل الضغط
          // حتى يعمل الضغط المطول على الهيدر
          child: IgnorePointer(
            ignoring: isHeaderParagraph,
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

  /// طباعة XML الفقرة في الـ console
  void _printParagraphXml() {
    /* print(
      "╔══════════════════════════════════════════════════════════════════╗",
    );
    ...
    */
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
      pPr?.getNumberingW() ?? TextSpan(text: ""),
      ...textRunTs.map((e) => e.toWidget()).toList(),
    ];
    spans = fixRtlWidgetSpan(spans);
    return spans;
  }

  EdgeInsets _getPPaddings() {
    return EdgeInsets.only(
      left: pPr?.paddingLeft ?? 0,
      right: pPr?.paddingRight ?? 0,
      top: pPr?.spacingBefore ?? 0,
      bottom: pPr?.spacingAfter ?? 0,
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
    return SizedBox(
      width: double.infinity,
      child: SelectableText.rich(
        TextSpan(style: prPr?.getTextStyle(), children: spans),
        textAlign: textAlign,
        textDirection: textDirection,
        selectionControls: CustomTextSelectionControls(
          bookTitle: parent.parent.title,
          pageNumber: parent.parent.currentPage + 1,
          wordPage: parent,
        ),
      ),
    );
  }

  /// إخفاء بيانات الصور الطويلة (base64) من XML لتوفير المساحة
  String _sanitizeXmlForStorage(String xml) {
    // لا نحتاج لإخفاء شيء لأن بيانات الصور في ملفات منفصلة
    // لكن نحد من طول XML إذا كان طويلاً جداً
    if (xml.length > 50000) {
      return xml.substring(0, 50000) + "\n... [TRUNCATED] ...";
    }
    return xml;
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
