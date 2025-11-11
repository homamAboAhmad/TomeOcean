import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Extensions/TextAlignExtensios.dart';
import 'package:golden_shamela/TestApp2.dart';
import 'package:golden_shamela/wordToHTML/ParagraphHyperLink.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:xml/xml.dart';

import 'package:golden_shamela/Utils/TestXmlWriter.dart'; // Add this import
import 'package:golden_shamela/Utils/custom_text_selection_controls.dart';

import '../WordToWidget/ImageToWidget.dart';
import '../main.dart';
import 'PPr.dart';
import 'RPr.dart';

class Paragraph {
  PPr? pPr;
  RPr? prPr;
  List<runT> runs = [];
  String text = "";
  XmlElement? pXml;
  String pageNum = "";
  List<runT> imageRunTs = [];
  List<runT> textRunTs = [];
  TextAlign textAlign = TextAlign.start;
  WordPage parent;
  TextDirection textDirection = TextDirection.rtl;
  Paragraph(this.parent);
  Paragraph fromXml(XmlElement paragraphXml) {
    pXml = paragraphXml;
    XmlElement? xmlpPr = paragraphXml.getElement("w:pPr");
    if (xmlpPr != null) pPr = PPr(this).fromXml(xmlpPr);
    XmlElement? xmlprPr = pPr?.xmlprPr;
    text = paragraphXml.text;

    if (xmlprPr != null) prPr = RPr(pPr!.getEmptyRun()).fromXml(xmlprPr);
    runs = [];
    paragraphXml.childElements.forEach((element) {
      if (element.name.local == "r") {
        runT runt0 = runT(this,prPr: prPr, pPr: pPr).fromXml(element);

        runt0.parent=this;
        pPr?.parent = this;
        prPr?.parent = runt0;
        runs.add(runt0);
        //addFont(runt0);
      }
    });
    fixPDirection();
    getPAlign();
    getPTextDirection();
    getPageNum();
    checkHyperLink();
    getPRunsByType();
    return this;
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


  Widget toWidget() {
     List<InlineSpan> spans = getPSpans();
     return GestureDetector(
       onLongPress: () { // Modify onLongPress
         if (pXml != null) {
           writeParagraphXmlToTestAsset(navigatorKey.currentContext!, pXml!);
         }
       },
       child: Padding(
         padding: _getPPaddings(),
         child: Stack(
           fit: StackFit.loose,
           children: [
             if (imageRunTs.isNotEmpty) _getImageRunsW(),
             _getTRunsW(spans)
           ],
         ),
       ),
     );
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

  getPageNum() {
    pageNum = pXml
        ?.findAllElements("w:instrText")
        .where((e) =>
    e.text
        .toString()
        .trim()
        .isNotEmpty)
        .firstOrNull
        ?.text ??
        "";
  }

  void getPAlign() {
    textAlign = pPr?.getTextAlignW() ?? TextAlign.start;
  }

  void getPTextDirection() {
    textDirection = pPr?.getTextDirectionW() ??
        prPr?.getTextDirection() ??
        TextDirection.rtl;
  }
  List<InlineSpan> getAllPSpans() {
    List<InlineSpan> spans = [
      pPr?.getNumberingW() ?? TextSpan(text: ""),

      ...runs.map((e) => e.toWidgetWithImg()).toList()
    ];
    spans = fixRtlWidgetSpan(spans);
    return spans;
  }



  List<InlineSpan> getPSpans() {
    List<InlineSpan> spans = [
      pPr?.getNumberingW() ?? TextSpan(text: ""),
      ...textRunTs.map((e) => e.toWidget()).toList()
    ];
    spans = fixRtlWidgetSpan(spans);
    return spans;
  }

  EdgeInsets _getPPaddings() {
    return EdgeInsets.only(
        left: pPr?.paddingLeft ?? 0, right: pPr?.paddingRight ?? 0);
  }

  _getImageRunsW() {
    // return Container(height: 10,width: 125,color: Colors.yellow,);
    return Stack(
      fit: StackFit.loose,
      children: [
        ...imageRunTs.map((runImage) => getImageWidget(runImage.image!))
      ],
    );
  }

  _getTRunsW(List<InlineSpan> spans) {
    return Align(
      alignment: textAlign.toAlignment(pPr?.rtl),
      child: SelectableText.rich(
        TextSpan(style: prPr?.getTextStyle(), children: spans),
        textAlign: textAlign,
        textDirection: textDirection,
        selectionControls: CustomTextSelectionControls(
          bookTitle: parent.parent.title,
          pageNumber: parent.parent.currentPage + 1,
        ),
      ),
    );
  }
}
