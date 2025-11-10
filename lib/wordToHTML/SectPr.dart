import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/ArchiveToXml.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/PPr.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:xml/xml.dart';

import '../Utils/ImageParser.dart';
import '../main.dart';
import 'DocFooter.dart';
import '../Models/WordDocument.dart';
import '../Models/WordPage.dart';

class SectPr {
  double? width; // Page width in twips (1/20th of a point)
  double? height; // Page height in twips
  double topMargin = 8;
  double bottomMargin = 8;
  double leftMargin = 8;
  double rightMargin = 8;
  int firstRange = 0;
  int lastRange = 0;
  WordDocument parent;
  XmlElement? footer;
  XmlElement? headerFirst, headerEven, headerOdd, headerDefault;
  XmlElement? sectPrElement;

  SectPr(
      {this.width,
      this.height,
      required this.topMargin,
      required this.bottomMargin,
      required this.leftMargin,
      required this.rightMargin,
      required this.parent,
      this.footer,
      this.sectPrElement}) {
    getHeaders();
  }

  SectPr.empty(this.parent) {
    getHeaders();
  }

  @override
  String toString() {
    return 'Page Size: ${width}x$height twips\n'
        'Margins - Top: $topMargin, Bottom: $bottomMargin, '
        'Left: $leftMargin, Right: $rightMargin';
  }

  static SectPr fromDocument(XmlDocument documentXml, WordDocument parent) {
    final sectPrElement = documentXml.findAllElements('w:sectPr').firstOrNull;
    return sectPrElement != null
        ? fromElement(sectPrElement, parent)
        : SectPr.empty(parent);
  }

  static SectPr fromElement(XmlElement sectPrElement, WordDocument parent0) {
    double? width;
    double? height;
    double? topMargin;
    double? bottomMargin;
    double? leftMargin;
    double? rightMargin;
    // Parse page size <w:pgSz>
    final pgSzElement = sectPrElement.findElements('w:pgSz').firstOrNull;
    if (pgSzElement != null) {
      width = double.tryParse(pgSzElement.getAttribute('w:w') ?? '');
      height = double.tryParse(pgSzElement.getAttribute('w:h') ?? '');
    }

    // Parse margins <w:pgMar>
    final pgMarElement = sectPrElement.findElements('w:pgMar').firstOrNull;
    if (pgMarElement != null) {
      topMargin = double.tryParse(pgMarElement.getAttribute('w:top') ?? '');
      bottomMargin =
          double.tryParse(pgMarElement.getAttribute('w:bottom') ?? '');
      leftMargin = double.tryParse(pgMarElement.getAttribute('w:left') ?? '');
      rightMargin = double.tryParse(pgMarElement.getAttribute('w:right') ?? '');
    }

    XmlElement? footer = getSectPrFooter(sectPrElement, parent0);
    SectPr sectPr = SectPr(
        width: width?.twipsToDp(),
        height: height?.twipsToDp(),
        topMargin: topMargin?.twipsToDp(),
        bottomMargin: bottomMargin?.twipsToDp(),
        leftMargin: leftMargin?.twipsToDp(),
        rightMargin: rightMargin?.twipsToDp(),
        footer: footer,
        parent: parent0,
        sectPrElement: sectPrElement);
    return sectPr;
  }

  void getHeaders() {
    if (sectPrElement == null) return;
    headerFirst = getSectPrHeader(sectPrElement!, parent, type: "first");
    headerDefault = getSectPrHeader(sectPrElement!, parent, type: "default");
    headerEven = getSectPrHeader(sectPrElement!, parent, type: "even");
    headerOdd = getSectPrHeader(sectPrElement!, parent, type: "odd");
    // print("headerFirst: ${headerFirst?.toXmlString()}");
    // print("headerDefault: ${headerDefault?.toXmlString()}");
    // print("headerEven: ${headerEven?.toXmlString()}");
    // print("headerOdd: ${headerOdd?.toXmlString()}");
  }

  // getSectHeaderHtml() {
  //   XmlElement? currentHeader = getRequestedHeader();
  //   if (currentHeader == null) return "<p></p>";
  //   // print("currentHeader: ${currentHeader.toXmlString(pretty: true)}");
  //   String html = "";
  //   currentHeader.childElements.forEach((e) {
  //     Paragraph p = Paragraph().fromXml(e);
  //     html = html + p.toHTML();
  //   });
  //   // print("hh:"+html);
  //   return html;
  // }
  Widget getSectHeaderWidget(WordPage wordPage) {
    XmlElement? currentHeader = getRequestedHeader();
    if (currentHeader == null) return Container();
    // print("currentHeader: ${currentHeader.toXmlString(pretty: true)}");
    List<Widget> psWidgets = [];
    List<Paragraph> ps = [];
    print("current header:${currentHeader.toXmlString()}");
    currentHeader.childElements.forEach((e) {
      Paragraph p = Paragraph(wordPage).fromXml(e);
      ps.add(p);
      psWidgets.add(p.toWidget());
    });
    // print("hh:"+html);

    // Widget ImagesWidget = imageToWidgetList(images);
    return Wrap(
      children: [
        // ImagesWidget,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: psWidgets,
        ),
      ],
    );
  }

  XmlElement? getRequestedHeader() {
    if (parent.currentPage == firstRange)
      return headerFirst ?? headerDefault;
    else if (parent.currentPage.isEven)
      return headerEven ?? headerDefault;
    else if (parent.currentPage.isOdd)
      return headerOdd ?? headerDefault;
    else
      return headerDefault;
  }
}

isSectPr(XmlElement element) {
  return element.name.local == "sectPr" ||
      element.getElement("w:pPr")?.getElement("w:sectPr") != null;
}

SectPr getSectPrFrmXml(XmlElement element, WordDocument parent) {
  if (element.name.local == "sectPr") {
    // print("sectPrElement:"+element.toXmlString());

    return SectPr.fromElement(element, parent);
  } else {
    XmlElement sectEl = element.getElement("w:pPr")!.getElement("w:sectPr")!;
    // print("sectPrElement2:"+sectEl.toXmlString());

    return SectPr.fromElement(sectEl, parent);
  }
}
