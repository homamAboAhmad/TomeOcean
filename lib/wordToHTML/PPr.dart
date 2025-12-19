import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/RomanConverter.dart';
import 'package:golden_shamela/Utils/XmlElementClone.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/DocumentStyles.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/wordToHTML/abstractNum.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:golden_shamela/wordToHTML/TabStop.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

import '../Utils/DiplayWordNumber.dart';

part 'PPr.g.dart';

double twipsToPx = 0.0667;

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class PPr {
  @JsonKey(ignore: true)
  XmlElement? xmlpPr;
  @JsonKey(ignore: true)
  XmlElement? xmlprPr;
  String? textAlign;
  bool? rtl;
  double? paddingLeft;
  double? paddingRight;
  String? pStyle;
  int? numId;
  int? paragraphNumber;
  int? ilvl; // padding level if has numbering
  @JsonKey(ignore: true)
  List<String> doneElements = ["numPr", "pStyle", "rPr", "ind", "jc", "tabs"];
  String? numberingH;

  /// Tab stops for this paragraph (used for TOC dot leaders)
  List<TabStop> tabStops = [];

  /// TOC level (1-9) extracted from pStyle like TOC1, TOC2, etc.
  int? tocLevel;

  @JsonKey(ignore: true)
  Paragraph parent;
  @JsonKey(ignore: true)
  late WordDocument wordDocument = parent.parent.parent;

  PPr(this.parent);

  PPr.empty() : parent = Paragraph.empty();

  factory PPr.fromJson(Map<String, dynamic> json) => _$PPrFromJson(json);
  Map<String, dynamic> toJson() => _$PPrToJson(this);

  static PPr fromMap(Map<String, dynamic> json, Paragraph parent) {
    final pPr = _$PPrFromJson(json);
    pPr.parent = parent;
    pPr.wordDocument = parent.parent.parent;
    // Re-parse TOC level from pStyle when loading from cache
    pPr.parseTocLevel();
    return pPr;
  }

  double? spacingBefore;
  double? spacingAfter;
  double? lineHeight;

  PPr fromXml(XmlElement? xmlpPr0) {
    xmlpPr0?.childElements.forEach((xmlElement) {
      if (!doneElements.contains(xmlElement.name.local)) {
        // print("PPr:" + xmlElement.name.local);
        // print(xmlElement.toXmlString());
      }
    });
    this.xmlpPr = xmlpPr0;

    getPStyle();
    if (wordDocument.defaultPPr != null) {
      this.xmlpPr = mergePPr(
        this.xmlpPr,
        wordDocument.defaultPPr!.xmlpPr,
        wordDocument.defaultRPr!.rPr,
      );
    }

    this.xmlprPr = xmlpPr?.getElement("w:rPr");
    this.rtl = RPr(getEmptyRun()).fromXml(xmlprPr).rtl;
    if (textAlign == null) textAlign = getTextAlign();

    checkNumbering();
    getPadding();
    getSpacing(); // Parse spacing
    fixTextAlign();
    parseTabStops();
    parseTocLevel();
    return this;
  }

  void getSpacing() {
    XmlElement? spacing = xmlpPr?.getElement("w:spacing");

    // Word 2007+ default line spacing is 1.15 (not 1.0!)
    // When no spacing element exists, Word uses this default
    if (spacing == null) {
      lineHeight = 1.15; // Word 2007+ default
      return;
    }

    // Before / After spacing in twips (twentieths of a point)
    // 1 point = 20 twips, so twipsToPx converts correctly
    String? before = spacing.getAttribute("w:before");
    String? after = spacing.getAttribute("w:after");

    if (before != null) {
      spacingBefore = double.tryParse(before);
      if (spacingBefore != null) {
        spacingBefore = spacingBefore! * twipsToPx;
      }
    }

    if (after != null) {
      spacingAfter = double.tryParse(after);
      if (spacingAfter != null) {
        spacingAfter = spacingAfter! * twipsToPx;
      }
    }

    // Line spacing - interpretation depends on w:lineRule
    String? line = spacing.getAttribute("w:line");
    String? lineRule = spacing.getAttribute("w:lineRule");

    if (line != null) {
      double lineVal = double.tryParse(line) ?? 240;

      if (lineRule == "auto" || lineRule == null) {
        // "auto": w:line is in 240ths of a line
        // 240 = Single (1.0), 276 = 1.15, 360 = 1.5, 480 = Double (2.0)
        lineHeight = lineVal / 240.0;
      } else if (lineRule == "exact" || lineRule == "atLeast") {
        // "exact"/"atLeast": w:line is in twips (twentieths of a point)
        double points = lineVal / 20.0; // twips to points

        if (lineRule == "atLeast" && points < 10) {
          // For "atLeast" with very small values (like 0.9pt),
          // Word uses the natural line height of the font.
          // We tune this slightly below 1.15 to fit content on page without overflow.
          lineHeight =
              1.08; // تعديل دقيق لتقليل الـ Overflow (توفير حوالي 5-7%)
        } else {
          // Calculate the multiplier
          double calculatedHeight = points / 14.0;
          lineHeight = calculatedHeight < 0.8 ? 0.8 : calculatedHeight;
        }
      }
    } else {
      // No w:line specified - default to Word 2007+ default
      lineHeight = 1.15;
    }
  }

  String? getTextAlign() {
    String? s = xmlpPr?.getElement("w:jc")?.getAttribute("w:val");
    return s;
  }

  String toHTML() {
    String alignH = getAlignH();
    // print("style:2 $alignH");
    String rtlH = getRtlH();
    String paddingH = getPaddingH();
    numberingH = getNumberingH();
    String html = ''' style="$alignH$rtlH$paddingH "''';

    return html;
  }

  TextAlign? getTextAlignW() {
    if (textAlign == null) return null;

    if (textAlign == "both" && rtl != false)
      return TextAlign.justify;
    else if (textAlign!.contains("Kashida") && rtl != false) {
      return TextAlign.justify;
    }
    switch (textAlign) {
      case "left":
        return TextAlign.left;
      case "right":
        return TextAlign.right;
      case "center":
        return TextAlign.center;
      case "justify":
        return TextAlign.justify;
      case "start":
        return TextAlign.start;
      case "end":
        return TextAlign.end;
      default:
        return null;
    }
  }

  String getAlignH() {
    // print("style:2"+(textAlign??""));

    if (textAlign == null)
      return "";
    else if (textAlign == "both" && rtl != false)
      return '''text-align: justify;
    text-justify: inter-word; direction: rtl;''';
    else if (textAlign!.contains("Kashida") && rtl != false) {
      return '''text-align: justify;
    text-justify: inter-word; direction: rtl;''';
    }
    String alignH = textAlign != null ? "text-align: $textAlign;" : "";
    return alignH;
  }

  String getRtlH() {
    return rtl == true ? "direction: rtl;" : "";
  }

  TextDirection? getTextDirectionW() {
    return rtl == true ? TextDirection.rtl : null;
  }

  void fixTextAlign() {
    if (rtl == true && textAlign == null)
      textAlign = "right";
    else if (rtl == true && textAlign == "right")
      textAlign = "left";
  }

  String? getPadding() {
    String? rightTwips = xmlpPr
        ?.getElement("w:ind")
        ?.getAttribute(rtl != false ? "w:left" : "w:right");
    String? leftTwips = xmlpPr
        ?.getElement("w:ind")
        ?.getAttribute(rtl != false ? "w:right" : "w:left");
    if (paddingLeft == null)
      paddingLeft = leftTwips != null
          ? double.parse(leftTwips) * twipsToPx
          : null;
    if (paddingRight == null)
      paddingRight = rightTwips != null
          ? double.parse(rightTwips) * twipsToPx
          : null;

    // تطبيق firstLine بشكل صحيح - حتى لو لم يكن هناك padding موجود مسبقاً
    String? firstLine = xmlpPr
        ?.getElement("w:ind")
        ?.getAttribute("w:firstLine");
    if (firstLine != null) {
      double firstLinePx = double.parse(firstLine) * twipsToPx;
      // في RTL، المسافة البادئة للسطر الأول تكون من اليمين
      if (rtl != false) {
        paddingRight = (paddingRight ?? 0) + firstLinePx;
      } else {
        paddingLeft = (paddingLeft ?? 0) + firstLinePx;
      }
    }

    Level? level = getNumberingLevel();
    if (level != null) {
      //print("num padding:  "+level.indentLeft.twpsToPx().toString());
      if (rtl != false)
        paddingRight = (paddingRight ?? 0) + level.indentLeft.twpsToPx();
      else
        paddingLeft = (paddingLeft ?? 0) + level.indentLeft.twpsToPx();
    }
  }

  String getPaddingH() {
    String paddingH =
        (paddingRight != null ? "padding-right: $paddingRight px;" : "") +
        (paddingLeft != null ? "padding-left: $paddingLeft px;" : "");
    return paddingH;
  }

  getPStyle() {
    pStyle = xmlpPr?.getElement("w:pStyle")?.getAttribute("w:val");
    if (pStyle == null) return;
    WordDocument? wordDocument = parent.parent.parent;
    XmlElement? style = getDocumentStyle(pStyle!, wordDocument);
    // if (style != null) {
    // print("--- Found Style XML for style '$pStyle' ---");
    // print(style.toXmlString(pretty: true));
    // print("--- End Style XML ---");
    // }
    // print("pStyle ${style?.toXmlString()}");
    if (style == null) return;
    XmlElement? pStyleXml = style.getElement("w:pPr");
    XmlElement? rStyleXml = style.getElement("w:rPr");
    rStyleXml = mergeRPr(rStyleXml, wordDocument.defaultRPr?.rPr);

    xmlpPr = mergePPr(xmlpPr, pStyleXml, rStyleXml);
  }

  void checkNumbering() {
    // البحث عن numId و ilvl مباشرة من xmlpPr
    String? numIdS = xmlpPr
        ?.getElement("w:numPr")
        ?.getElement("w:numId")
        ?.getAttribute("w:val");
    if (numIdS != null) {
      numId = int.tryParse(numIdS);
    }

    String? ilvlS = xmlpPr
        ?.getElement("w:numPr")
        ?.getElement("w:ilvl")
        ?.getAttribute("w:val");
    if (ilvlS != null) {
      ilvl = int.tryParse(ilvlS);
    }

    // إذا لم نجد numId/ilvl في xmlpPr مباشرة، نبحث في pStyle
    if (numId == null && pStyle != null) {
      WordDocument? wordDocument = parent.parent.parent;
      XmlElement? style = getDocumentStyle(pStyle!, wordDocument);
      if (style != null) {
        XmlElement? pStyleXml = style.getElement("w:pPr");
        numIdS = pStyleXml
            ?.getElement("w:numPr")
            ?.getElement("w:numId")
            ?.getAttribute("w:val");
        if (numIdS != null) {
          numId = int.tryParse(numIdS);
        }

        ilvlS = pStyleXml
            ?.getElement("w:numPr")
            ?.getElement("w:ilvl")
            ?.getAttribute("w:val");
        if (ilvlS != null) {
          ilvl = int.tryParse(ilvlS);
        }
      }
    }

    if (numId != null && ilvl != null) {
      Level? level = getNumberingLevel();
      if (level != null) {
        int startLvl = level.startVal;
        paragraphNumber =
            startLvl - 1 + wordDocument.addParagraphNum(numId!, ilvl!);
      }
    }
  }

  Level? getNumberingLevel() {
    if (numId == null || ilvl == null) return null;

    int abstractNumId = wordDocument.numsMap[numId]?.abstractNumId ?? -1;
    if (abstractNumId == -1) return null;

    if (!wordDocument.abstractNumMap.containsKey(abstractNumId)) return null;

    return wordDocument.abstractNumMap[abstractNumId]!.levelsMap[ilvl];
  }

  String getNumberingH() {
    Level? level = getNumberingLevel();
    if (level == null) return "";
    String displayNumber = getDisblayNumber(
      level,
      numId: numId,
      paragraphNumber: paragraphNumber!,
    );
    return ''' <span style="display: inline-block; margin-left: ${level.indentHanging.twpsToPx()}px;">$displayNumber</span>''';
  }

  WidgetSpan getNumberingW() {
    Level? level = getNumberingLevel();
    if (level == null) {
      return WidgetSpan(child: Text(""));
    }

    String displayNumber = getDisblayNumber(
      level,
      numId: numId,
      paragraphNumber: paragraphNumber!,
    );

    // بناء TextStyle مع الخط المخصص إذا كان موجوداً
    TextStyle? textStyle;
    if (level.fontFamily != null && level.fontFamily!.isNotEmpty) {
      textStyle = TextStyle(fontFamily: level.fontFamily);
    }

    return WidgetSpan(
      child: Padding(
        padding: EdgeInsets.only(left: level.indentHanging.twpsToPx()),
        child: Text(displayNumber, style: textStyle),
      ),
    );
  }

  runT getEmptyRun() {
    runT emptyRun = parent.runs.isEmpty
        ? runT(parent, prPr: null, pPr: null)
        : parent.runs[0];
    return emptyRun;
  }

  /// Parse tab stops from w:tabs element
  /// Tab stops define custom positions and can have leader characters (dots, underscores, etc.)
  void parseTabStops() {
    tabStops = [];
    XmlElement? tabsElement = xmlpPr?.getElement("w:tabs");
    if (tabsElement == null) return;

    for (XmlElement tab in tabsElement.childElements) {
      if (tab.name.local != "tab") continue;

      TabStop tabStop = TabStop(
        type: tab.getAttribute("w:val"),
        position: double.tryParse(tab.getAttribute("w:pos") ?? "0"),
        leader: tab.getAttribute("w:leader"),
      );
      tabStops.add(tabStop);
    }
  }

  /// Parse TOC level from paragraph style (TOC1, TOC2, etc.)
  void parseTocLevel() {
    if (pStyle == null) {
      tocLevel = null;
      return;
    }

    String styleLower = pStyle!.toLowerCase();
    // Match patterns like "toc1", "toc2", "toc 1", "toc 2", etc.
    RegExp tocRegex = RegExp(r'^toc\s*(\d)$', caseSensitive: false);
    Match? match = tocRegex.firstMatch(styleLower);

    if (match != null) {
      tocLevel = int.tryParse(match.group(1) ?? "");
    } else {
      tocLevel = null;
    }
  }

  /// Check if this paragraph is a TOC (Table of Contents) entry
  bool isTOCStyle() {
    if (pStyle == null) return false;
    String styleLower = pStyle!.toLowerCase();
    return styleLower.startsWith("toc") ||
        styleLower == "tableofcontents" ||
        styleLower.contains("toc");
  }

  /// Get the right-aligned tab stop (typically used for page numbers in TOC)
  TabStop? getRightTabStop() {
    for (TabStop tab in tabStops) {
      if (tab.isRightAligned) return tab;
    }
    return null;
  }
}

XmlElement? mergePPr(
  XmlElement? xmlpPr,
  XmlElement? pStyleXml,
  XmlElement? rStyleXml,
) {
  if (pStyleXml == null) return xmlpPr;

  Map<String, XmlElement> currentElementsMap = {};
  xmlpPr?.childElements.forEach((e) {
    currentElementsMap[e.name.local] = e.clone();
  });
  XmlElement? mergedRpr = mergeRPr(xmlpPr?.getElement("w:rPr"), rStyleXml);

  if (mergedRpr != null) {
    currentElementsMap["rPr"] = mergedRpr.clone();
  }
  pStyleXml.childElements.forEach((e) {
    if (currentElementsMap[e.name.local] == null)
      currentElementsMap[e.name.local] = e.clone();
  });

  return XmlElement(
    XmlName.fromString(xmlpPr?.name.toXmlString() ?? "w:pPr"),
    xmlpPr?.attributes.toList().clone(),
    currentElementsMap.values,
  );
}
