// import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/wordToHTML/FootNote.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:xml/xml.dart';

import '../WordToWidget/ImageToWidget.dart';
import '../wordToHTML/Paragraph.dart';

class WordPage {
  List<Paragraph> ps = [];
  List<FootNote> fns = [];
  String pageNum = "";
  WordDocument parent;
  WordPage(this.parent);
  String text() {
    String text = "";
    ps.forEach((paragraph) {
      text = text +"\n"+ paragraph.text;
    });
    return text;
  }

  addParagraph(XmlElement element) {
    Paragraph p = Paragraph(this).fromXml(element);
    ps.add(p);
    // wordDocument.fontsList.addAll(p.fontsMap);
  }


  Widget toWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...ps
            .map((e) => e.toWidget())
            .toList()
      ],
    );
    // List<InlineSpan> spans =[];
    // ps.forEach((p){
    //   spans.addAll(p.getAllPSpans());
    //   spans.add(TextSpan(text: "\n"));
    // });
    // return SelectableText.rich(
    //     TextSpan(children: spans),
    //   textDirection: TextDirection.rtl,
    //
    // );

  }


  List<ImageData> getPageImageData() {
    return getParagraphImages(ps);
  }


  Widget getPageIamgesWiLi() {
    List<ImageData> list = getPageImageData();
    return imageToWidgetList(list);
  }

  // String htmlFooter() {
  //   String pageNumHtml = getPageNumH();
  //   if (fns.isEmpty) return pageNumHtml;
  //   String html = "";
  //   fns.forEach((fn) {
  //     html = html + fn.p.toHTML();
  //   });
  //   html += pageNumHtml;
  //
  //   return html;
  // }

  Widget footerW() {
    Widget? pageNumW =getPageNumW();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if(pageNumW!=null) pageNumW,
        ...fns.map((fn)=>fn.p.toWidget())
      ],


    );
  }

  Widget? getPageNumW() {
    String pageNum = ps.lastOrNull?.pageNum ?? "";
    if (pageNum == "") return null;
    return Center(child: Text("-$pageNum-", style: TextStyle(
        color: Colors.black, fontSize: 16, fontFamily: "jreg"),
    ));
  }


// sortImages(List<ImageData> list) {
//   list.reversed;
// }

// String addImages(String html) {
//   ps.forEach((p) {
//     p.runs.forEach((r) {
//       if (r.image != null) html = html + r.image!.toHtml();
//     });
//   });
//   return html;
// }

//
// String getSeperator() {
//   return '''<hr style="border: none; border-top: 50px solid black; width: 100%; margin: auto;"> ''';
// }
}

List<ImageData> getParagraphImages(List<Paragraph> paragraphs) {
  List<ImageData> list = [];
  paragraphs.forEach((p) {
    p.runs.forEach((r) {
      if (r.image != null && !r.isRelativeFromVParagraph()) {
        list.add(r.image!);
      } /*else if (r.image != null && r.isRelativeFromVParagraph()) {
        print("there is image but is relative");
      }*/
    });
  });
  // sortImages(list);
  list.sort((a, b) => a.relativeHeight.compareTo(b.relativeHeight));

  return list;
}

Widget imageToWidgetList(List<ImageData> list) {

  List<Widget> imagesW = [];
  list.forEach((image) {
    imagesW.add(getImageWidget(image));
  });

  return Stack(
    children: [...imagesW],
  );
}
