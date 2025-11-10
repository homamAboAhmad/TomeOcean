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
import 'package:xml/xml.dart';

import '../Utils/DiplayWordNumber.dart';

double twipsToPx = 0.0667;

class PPr {
  XmlElement? xmlpPr;
  XmlElement? xmlprPr;
  String? textAlign;
  bool? rtl;
  double? paddingLeft;
  double? paddingRight;
  String? pStyle;
  int? numId;
  int? paragraphNumber;
  int? ilvl; // padding level if has numbering
  List<String> doneElements = ["numPr", "pStyle", "rPr", "ind", "jc"];
  String? numberingH;
  Paragraph parent;
  late WordDocument wordDocument = parent.parent.parent;

  PPr(this.parent);

  PPr fromXml(XmlElement? xmlpPr0) {
    xmlpPr0?.childElements.forEach((xmlElement) {
      if (!doneElements.contains(xmlElement.name.local)) {
        // print("PPr:" + xmlElement.name.local);
        // print(xmlElement.toXmlString());
      }
    });
    this.xmlpPr = xmlpPr0;

    getPStyle();
    if (wordDocument.defaultPPr != null)
      this.xmlpPr = mergePPr(this.xmlpPr, wordDocument.defaultPPr!.xmlpPr,
          wordDocument.defaultRPr!.rPr);

    this.xmlprPr = xmlpPr?.getElement("w:rPr");
    this.rtl = RPr(getEmptyRun()).fromXml(xmlprPr).rtl;
    if (textAlign == null) textAlign = getTextAlign();

    checkNumbering();
    getPadding();
    fixTextAlign();
    return this;
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
    if (textAlign == null)
      return null;
    else if (textAlign == "both" && rtl != false)
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
        return null; // إذا كانت القيمة غير معروفة، نرجع null
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
    else if (rtl == true && textAlign == "right") textAlign = "left";
  }

  String? getPadding() {
    String? rightTwips = xmlpPr
        ?.getElement("w:ind")
        ?.getAttribute(rtl != false ? "w:left" : "w:right");
    String? leftTwips = xmlpPr
        ?.getElement("w:ind")
        ?.getAttribute(rtl != false ? "w:right" : "w:left");
    if (paddingLeft == null)
      paddingLeft =
          leftTwips != null ? double.parse(leftTwips) * twipsToPx : null;
    if (paddingRight == null)
      paddingRight =
          rightTwips != null ? double.parse(rightTwips) * twipsToPx : null;

    String? firstLine =
        xmlpPr?.getElement("w:ind")?.getAttribute("w:firstLine");
    if (firstLine != null) {
      if (paddingRight != null)
        paddingRight = paddingRight! + double.parse(firstLine) * twipsToPx;
      else if (paddingLeft != null)
        paddingLeft = paddingLeft! + double.parse(firstLine) * twipsToPx;
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
    // print("pStyle ${style?.toXmlString()}");
    if (style == null) return;
    XmlElement? pStyleXml = style.getElement("w:pPr");
    XmlElement? rStyleXml = style.getElement("w:rPr");
    rStyleXml = mergeRPr(rStyleXml, wordDocument.defaultRPr?.rPr);

    xmlpPr = mergePPr(xmlpPr, pStyleXml, rStyleXml);
  }

  void checkNumbering() {
    if (pStyle == null) return;
    String? numIdS = xmlpPr
        ?.getElement("w:numPr")
        ?.getElement("w:numId")
        ?.getAttribute("w:val");
    if (numIdS != null) numId = int.tryParse(numIdS);

    String? ilvlS = xmlpPr
        ?.getElement("w:numPr")
        ?.getElement("w:ilvl")
        ?.getAttribute("w:val");
    if (ilvlS != null) ilvl = int.tryParse(ilvlS);

    if (numId != null && ilvl != null) {
      Level? level = getNumberingLevel();
      int startLvl = level?.startVal ?? 0;
      paragraphNumber =
          startLvl - 1 + wordDocument.addParagraphNum(numId!, ilvl!);
    }
  }

  Level? getNumberingLevel() {
    if (pStyle == null) return null;
    if (numId == null) return null;
    int abstractNumId = wordDocument.numsMap[numId]?.abstractNumId ?? -1;
    if (abstractNumId == -1) return null;
    Level? level =
        wordDocument.abstractNumMap[abstractNumId]!.levelsMap[ilvl ?? 0];
    return level;
  }

  String getNumberingH() {
    Level? level = getNumberingLevel();
    if (level == null) return "";
    String displayNumber = getDisblayNumber(level,
        numId: numId, paragraphNumber: paragraphNumber!);
    return ''' <span style="display: inline-block; margin-left: ${level.indentHanging.twpsToPx()}px;">$displayNumber</span>''';
  }

  WidgetSpan getNumberingW() {
    Level? level = getNumberingLevel();
    if (level == null) return WidgetSpan(child: Text(""));
    String displayNumber = getDisblayNumber(level,
        numId: numId, paragraphNumber: paragraphNumber!);
    return WidgetSpan(
      child: Padding(
        padding: EdgeInsets.only(left: level.indentHanging.twpsToPx()),
        child: Text(displayNumber),
      ),
    );
    // return ''' <span style="display: inline-block; margin-left: ${level.indentHanging.twpsToPx()}px;">$displayNumber</span>''';
  }

  runT getEmptyRun() {
    runT emptyRun = parent.runs.isEmpty
        ? runT(parent, prPr: null, pPr: null)
        : parent.runs[0];
    return emptyRun;
  }
}

XmlElement? mergePPr(
    XmlElement? xmlpPr, XmlElement? pStyleXml, XmlElement? rStyleXml) {
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

  return XmlElement(XmlName.fromString(xmlpPr?.name.toXmlString() ?? "w:pPr"),
      xmlpPr?.attributes.toList().clone(), currentElementsMap.values);
}
