import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:golden_shamela/Utils/XmlElementClone.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/DocumentStyles.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

import '../Models/WordDocument.dart';

part 'RPr.g.dart';

const Map<String, String> _wordColorMap = {
  "black": "000000",
  "blue": "0000FF",
  "cyan": "00FFFF",
  "green": "008000",
  "magenta": "FF00FF",
  "red": "FF0000",
  "yellow": "FFFF00",
  "white": "FFFFFF",
  "darkBlue": "00008B",
  "darkCyan": "008B8B",
  "darkGreen": "006400",
  "darkMagenta": "8B008B",
  "darkRed": "8B0000",
  "darkYellow": "808000",
  "darkGray": "A9A9A9",
  "lightGray": "D3D3D3",
};

String? _normalizeColor(String? color) {
  if (color == null) return null;
  // Check if it's a named color
  if (_wordColorMap.containsKey(color)) {
    return _wordColorMap[color];
  }
  // Otherwise, just sanitize it
  return color.replaceAll("#", "");
}


@JsonSerializable(explicitToJson: true, constructor: 'empty')
class RPr {
  @JsonKey(ignore: true)
  XmlElement? rPr;
  String? color;
  String? uColor;
  String? highlightColor;
  double? fontSize;
  bool? b;
  bool? i;
  bool? u;
  bool? rtl;
  bool? strike;
  String? font;
  String? enFont,uniqueFont;
  String? vertAlign;
  String? rStyle;
  @JsonKey(ignore: true)
  runT parent;
  @JsonKey(ignore: true)
  late WordDocument wordDocument = parent.parent.parent.parent;
  RPr(this.parent);

  RPr.empty() : parent = runT.empty();

  factory RPr.fromJson(Map<String, dynamic> json) => _$RPrFromJson(json);
  Map<String, dynamic> toJson() => _$RPrToJson(this);

  static RPr fromMap(Map<String, dynamic> json, runT? parent) {
    final rPr = _$RPrFromJson(json);
    if (parent != null) {
      rPr.parent = parent;
      rPr.wordDocument = parent.parent.parent.parent;
    }
    return rPr;
  }

  @JsonKey(ignore: true)
  List<String> doneElements = [
    "b",
    "i",
    "u",
    "rtl",
    "color",
    "highlight",
    "shd",
    "sz",
    "szCs",
    "rFonts",
    "strike",
    "vertAlign",
    "bCs",
    "rStyle"
  ];

  RPr fromXml(XmlElement? xmlrPr) {
    this.rPr = xmlrPr;

    rStyle = this.rPr?.getElement("w:rStyle")?.getAttribute("w:val");
    getRStyle();

    xmlrPr?.childElements.forEach((xmlElement) {
      if (!doneElements.contains(xmlElement.name.local)) {
        // print("rpr:"+xmlElement.name.local);
        // print("rpr:"+xmlElement.toXmlString(pretty: true));
      }
    });

    b = isBold();
    i = isItalic();
    u = isUnderLine();
    rtl = isRtl();
    color = getColor();
    uColor = getUColor();
    highlightColor = getHLColor();
    if (highlightColor == null) highlightColor = getShdColor();
    fontSize = getFontSize();
    getFonts();
    strike = hasStrike();
    vertAlign = getVerticalAlign();

    return this;
  }

  TextStyle getTextStyle() {
    String? finalHlColor = _normalizeColor(highlightColor);
    Paint paint = Paint()..color = Color(int.parse("0xFF${finalHlColor ?? "000000"}"));

    Paint? hlColor = highlightColor != null ? paint : null;
    String? finalColor = _normalizeColor(color);

    return TextStyle(
      fontWeight: b == true ? FontWeight.bold : null,
      fontStyle: i == true ? FontStyle.italic : FontStyle.normal,
      decoration: getTextDecoration(),
      color: finalColor != null ? Color(int.parse("0xFF$finalColor")) : Colors.black,
      background: hlColor, // لون خلفية النص
      fontSize: fontSize ?? 14,
      fontFamily: font,
    );
  }

  String toHTML() {
    String bold = b == true ? '''font-weight: bold;''' : "";
    String italic = i == true ? '''font-style: italic; ''' : "";
    String underLine =
        u == true ? '''text-decoration: underline single #$uColor; ''' : "";
    String colorH = color != null ? '''color: #$color; ''' : "";
    String hlColorH =
        highlightColor != null ? "background-color:$highlightColor;" : "";
    String isRtl = rtl == true ? "direction: rtl;" : "";
    String fontSizeH = getFontSizeH();
    String fontH = getFontH();
    String strikeH = getStrikeH();
    String html =
        '''$fontH style="$colorH$bold$italic$underLine$hlColorH$isRtl$fontSizeH$strikeH" ''';

    return html;
  }

  TextDirection? getTextDirection() {
    if (isRtl() == true)
      return TextDirection.rtl;
    else if (isRtl() == false)
      return TextDirection.ltr;
    else
      return null;
  }

  String? getColor() {
    String? color = rPr?.getElement("w:color")?.getAttribute("w:val");
    if (color == "auto") color = wordDocument?.autoDarkColor??"000000 ";
    return color;
  }

  bool? isBold() {
    bool isBold =
        rPr?.getElement("w:b") != null || rPr?.getElement("w:bCs") != null;
    if (isBold) return true;
  }

  bool? isItalic() {
    bool isItalic = rPr?.getElement("w:i") != null;
    if (isItalic) return true;
  }

  bool? isUnderLine() {
    bool hasUnderLine = rPr?.getElement("w:u") != null;
    if (hasUnderLine) return true;
  }

  String? getUColor() {
    String? underLineColor = rPr?.getElement("w:u")?.getAttribute("w:color");
    return underLineColor ?? "000000";
  }

  String? getHLColor() {
    String? hlColor = rPr?.getElement("w:highlight")?.getAttribute("w:val");
    return hlColor;
  }

  bool? isRtl() {
    if (rPr?.getElement("w:rtl") != null)
      return true;
    else if (rPr?.getElement("w:ltr") != null)
      return false;
    else
      return null;
  }

  String? getShdColor() {
    String? shd = rPr?.getElement("w:shd")?.getAttribute("w:fill");
    if (shd == null) return null;
    return "#" + shd;
  }

  double? getFontSize() {
    String? sz = rPr?.getElement("w:sz")?.getAttribute("w:val");
    late double fSz;
    if (sz == null) return null;
    fSz = double.parse(sz) / 2;
    // fSz = fSz * 1.1;
    return fSz;
  }

  String getFontSizeH() {
    if (fontSize == null) fontSize = 14 + 14 * 0.1;
    return "font-size:$fontSize px;";
  }

  bool? hasStrike() {
    return rPr?.getElement("w:strike") != null;
  }

  String getStrikeH() {
    return strike == true ? " text-decoration: line-through" : "";
  }

  String? getArFont() {
    XmlElement? rFonts = rPr?.getElement("w:rFonts");
    String? cs = rFonts?.getAttribute("w:cs");

    // if(cs==null)print(rPr?.toXmlString());
    if (cs != null) return cs;
    String? cstheme = rFonts?.getAttribute("w:cstheme");
    if (cstheme == null) cstheme = rFonts?.getAttribute("w:eastAsiaTheme");

    if (cstheme != null && cstheme.contains("minor")) {
      return wordDocument.defaultRPr?.font;
    } else if (cstheme != null && cstheme.contains("major")) {
      return wordDocument.defaultRPr?.font;
    }
    return cstheme;
  }

  String getFontH() {
    if (font != null && isProblemFont(font!))
      font = wordDocument.defaultRPr?.font ?? "Traditional Arabic.ttf";

    String? fixedFont = font != null ? getFixedFontName(font!) : null;
    return font == null ? "" : '''class="$fixedFont";''';
  }

  String? getVerticalAlign() {
    return rPr?.getElement("w:vertAlign")?.getAttribute("w:val");
  }

  // String getVertAlignH1() {
  //   if (vertAlign == "superscript")
  //     return "<sup>";
  //   else if (vertAlign == "subscript")
  //     return "<sub>";
  //   else
  //     return "";
  // }

  double getVertAlignNum() {
    if (vertAlign == "superscript")
      return -8;
    else if (vertAlign == "subscript")
      return 8;
    else
      return 0;
  }

  String getVertAlignH2() {
    if (vertAlign == "superscript")
      return """</sup>""";
    else if (vertAlign == "subscript")
      return """</sub>""";
    else
      return "";
  }

  getRStyle() {
    if (rStyle == null) return;
    WordDocument? wordDocument = parent?.parent?.parent?.parent;
    XmlElement? rStyleXml = getRPrFRromStyle(rStyle!,wordDocument);
    if (rStyleXml == null) return;
    rPr = mergeRPr(rPr!, rStyleXml);
  }

  getTextDecoration() {
    return TextDecoration.combine([
      if (u == true) TextDecoration.underline, // إضافة إذا كانت u تساوي true
      if (strike == true) TextDecoration.lineThrough,
      ]);
  }
  // <w:rFonts w:ascii="romoz II" w:hAnsi="romoz II" w:cs="Barada Reqa"/>
  void getFonts() {
    font = getArFont();
    enFont =  rPr?.getElement("w:rFonts")?.getAttribute("w:ascii");
    uniqueFont = rPr?.getElement("w:rFonts")?.getAttribute("w:hAnsi");
  }
}

XmlElement? mergeRPr(XmlElement? rPr, XmlElement? baseRPr) {
  if (baseRPr == null) return rPr;
  if (rPr == null) return baseRPr;

  List<XmlElement> mergedElements = [
    ...rPr.childElements.map(((e) => e.clone())) ?? []
  ];
  Map<String, XmlElement> currentElementsMap = {};
  rPr.childElements.forEach((e) {
    currentElementsMap[e.name.local] = e;
  });
  baseRPr.childElements.forEach((e) {
    if (currentElementsMap[e.name.local] == null) mergedElements.add(e.clone());
  });

  XmlElement mergedRpr = XmlElement(XmlName.fromString(rPr.name.toXmlString()),
      rPr.attributes.toList().clone(), mergedElements);

  return mergedRpr;
}
