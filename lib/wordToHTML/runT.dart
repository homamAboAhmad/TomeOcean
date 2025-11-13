import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/Utils/TxtUtils.dart';
import 'package:golden_shamela/WordToWidget/ImageToWidget.dart';
import 'package:golden_shamela/wordToHTML/HyperLinkRun.dart';
import 'package:golden_shamela/wordToHTML/PPr.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

part 'runT.g.dart';

const BLANK = "*#&&#*";

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class runT {
  RPr? prPr;
  PPr? pPr;
  String? text;
  RPr? rpr;
  bool hasBrBefore = false;
  bool hasBrAfter = false;
  @JsonKey(ignore: true)
  XmlElement? xmlRun;
  String? footNoteId;
  String? fnDisplayNum;
  ImageData? image;
  String? toc;
  @JsonKey(ignore: true)
  Paragraph parent;

  runT(this.parent, {required this.prPr, required this.pPr});

  runT.empty() : parent = Paragraph.empty();

  factory runT.fromJson(Map<String, dynamic> json) => _$runTFromJson(json);
  Map<String, dynamic> toJson() => _$runTToJson(this);

  static runT fromMap(Map<String, dynamic> json, Paragraph parent) {
    final runT = _$runTFromJson(json);
    runT.parent = parent;

    if (json['rpr'] != null) {
      runT.rpr = RPr.fromMap(json['rpr'] as Map<String, dynamic>, runT);
    }
    if (json['image'] != null) {
      runT.image = ImageData.fromMap(json['image'] as Map<String, dynamic>, runT);
    }
    return runT;
  }

  fromXml(XmlElement? xmlRun) {
    this.xmlRun = xmlRun;
    getText();
    checkBr();
    checkFnId();
    checkBookMark();
    XmlElement? xmlrPr = xmlRun?.getElement("w:rPr");
    if (xmlrPr != null) {
      rpr = RPr(this).fromXml(xmlrPr);
      rpr?.parent = this;
    }
    checkParaRpr();
    checkToc();
    if (isImageRun(xmlRun)) {
      image = parseImageData(this);
    }
    return this;
  }

  isRelativeFromVParagraph() {
    return image?.relativeFromV == "paragraph";
  }

  InlineSpan toWidgetWithImg() {
    if (isImageRun(xmlRun) && isRelativeFromVParagraph())
      return WidgetSpan(
          child: getImageWidget(image!)
      );
    else
      return toWidget();
  }

  InlineSpan toWidget() {
    if (isImageRun(xmlRun)) {
      return TextSpan(text: "");
    }

    String bBr = hasBrBefore ? "\n" : "";
    String aBr = hasBrAfter ? "\n" : "";
    Widget? tab = getTabWidget();
    checkSymbol();

    double vAlign = rpr?.getVertAlignNum() ?? 0;
    String fixedText = checkDiacritics();
    if (vAlign != 0) {
      return WidgetSpan(
        child: Transform.translate(
          offset: Offset(0.0, vAlign),
          child: Text(
            "$fixedText",
            textAlign: TextAlign.end,
            textDirection: TextDirection.ltr,
            style: rpr?.getTextStyle(),
          ),
        ),
      );
    } else if (tab != null) {
      return WidgetSpan(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$bBr$fixedText$aBr",
              style: rpr?.getTextStyle() ?? TextStyle(
                  color: Colors.black, fontSize: 14, fontFamily: "jreg"),
            ),
            tab
          ],
        ),
      );
    } else {
      return TextSpan(
        text: "$bBr$fixedText$aBr",
        style: rpr?.getTextStyle() ??
            TextStyle(color: Colors.black, fontSize: 14, fontFamily: "jreg"),
      );

      // return WidgetSpan(
      //   child: Text(
      //      "$bBr$text$aBr",
      //     textDirection: TextDirection.rtl,
      //     textAlign: TextAlign.right,
      //     style:rpr?.getTextStyle()??TextStyle(color: Colors.black,fontSize: 14,fontFamily: "jreg"),
      //   ),
      // );
    }

    // if (image != null) html = image!.toHtml() + html;
  }


  void checkBr() {
    bool hasBr = xmlRun?.getElement("w:br") != null;
    if (hasBr) {
      int tP = 0;
      int brP = 0;
      List<XmlElement> elements = xmlRun!.childElements.toList();
      for (int i = 0; i < elements.length; i++) {
        if (elements[i].name.local == "t")
          tP = i;
        else if (elements[i].name.local == "br") brP = i;
      }
      hasBrBefore = brP < tP;
      hasBrAfter = brP > tP;
    }
  }

  void checkFnId() {
    footNoteId =
        xmlRun?.getElement("w:footnoteReference")?.getAttribute("w:id");
  }

  updateFnDisplayNumber() {
    if (footNoteId != null) {
      text = (text ?? "") + (fnDisplayNum ?? footNoteId!);
      text = text!.trim();
      text?.replaceAll(" ", "");
    }
  }

  void fixFnr() {
    if (text == null || rpr?.vertAlign != "superscript" || rpr?.rtl != true)
      return;
    if (text!.contains("("))
      text = text!.replaceFirst("(", ")");
    else if (text!.contains(")")) text = text!.replaceFirst(")", "(");
  }

  void getText() {
    text = xmlRun
        ?.getElement("w:t")
        ?.text ?? "";
    // if (text == "") text = " ";
  }

  checkSymbol() {
    if (hasSymbol()) {
      rpr?.font = xmlRun?.getElement("w:sym")?.getAttribute("w:font");
      // print("has symbol:" + xmlRun!.toXmlString(pretty: true));
      String symbolToTxt =
      (xmlRun?.getElement("w:sym")?.getAttribute("w:char") ?? "");
      int codePoint = int.parse(symbolToTxt, radix: 16);
      text = String.fromCharCode(codePoint);
      // print("has symbol: ${xmlRun?.getElement("w:sym")?.toXmlString()}");
    } else {
      rpr?.font = changeFontByTxt(text);
      // print("font: ${rpr?.font}");
    }
  }

  bool hasSymbol() {
    return xmlRun?.getElement("w:sym") != null;
  }

  Widget? getTabWidget() {
    // fix this if you wany to convert to complete html
    if (xmlRun?.getElement("w:tab") == null)
      return null;
    else
      return Container(
        width: 150,
        child: Center(child: Text("................................")),
      );
  }

  void checkParaRpr() {
    rpr?.b ??= prPr?.b;
    rpr?.i ??= prPr?.i;
    rpr?.u ??= prPr?.u;
    rpr?.uColor ??= prPr?.uColor;
    rpr?.color ??= prPr?.color;
    rpr?.highlightColor ??= prPr?.highlightColor;
    rpr?.rtl ??= prPr?.rtl;
    rpr?.font ??= prPr?.font;
    rpr?.fontSize ??= prPr?.fontSize;
    rpr?.vertAlign ??= prPr?.vertAlign;
  }

  String? changeFontByTxt(String? text) {
    if (text == null) return null;
    if (isArabic(text)) {
      return rpr?.font; // خط عربي
    } else if (text.contains(RegExp(r'[a-zA-Z]'))) {
      return rpr?.enFont; // خط إنجليزي
    } else {
      return rpr?.uniqueFont; // إذا كان النص غير محدد، نختار خط افتراضي
    }
  }

  // دالة لتحديد ما إذا كان النص عربيًا
  bool isArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  String checkDiacritics() {
    bool withDiacritics = parent.parent.parent.withDiacritics;
    if (withDiacritics)
      return text ?? "";
    else
    return removeDiacritics(text??"");
  }

}
