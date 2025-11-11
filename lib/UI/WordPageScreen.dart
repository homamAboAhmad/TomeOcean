import 'dart:typed_data';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';

import '../Constants.dart';
import '../Utils/DirectionWidgetSpan.dart';
import '../Utils/Widgets/ZoomableSecreen.dart';
import '../Utils/colorMap.dart';
import '../main.dart';
import '../wordToHTML/ParagraphHyperLink.dart';

class WordPageScreen extends StatefulWidget {
  WordPage wordPage;
  WordDocument wordDocument;

  WordPageScreen(this.wordPage, {required this.wordDocument,super.key});

  @override
  State<WordPageScreen> createState() => _WordPageScreenState();
}

var widgetSpanKeys;

class _WordPageScreenState extends State<WordPageScreen> {
  late WordDocument wordDocument;
  @override
  Widget build(BuildContext context) {
    wordDocument =widget.wordDocument;
    // return CustomInteractiveViewer(
    //   child: SizedBox(
    //     height: (wordDocument.getPageSectPr().height ?? 1000),
    //     width: wordDocument.getPageSectPr().width ?? 800,
    //     child: GestureDetector(
    //       onLongPress: () {
    //         print("<wordPage>");
    //         widget.wordPage.ps.forEach((p) {
    //           print(p.pXml?.toXmlString(pretty: true));
    //         });
    //         print("</wordPage>");
    //       },
    //       child: Container(
    //         decoration: BoxDecoration(color: Colors.white),
    //         child: Stack(
    //           children: [
    //             pageHeaderW(),
    //             widget.wordPage.getPageIamgesWiLi(),
    //             Container(
    //               margin: getSectionMargins(),
    //               child: SelectionArea(
    //                 child: Column(
    //                   textDirection: TextDirection.rtl,
    //                   mainAxisAlignment: MainAxisAlignment.start,
    //                   crossAxisAlignment: CrossAxisAlignment.start,
    //                   mainAxisSize: MainAxisSize.min,
    //                   children: [
    //                     // ...widget.wordPage.ps
    //                     //     .map((e) => e.toWidget())
    //                     //     .toList(),
    //                     pageContentW(),
    //                     getSeperator(widget.wordPage.fns.isNotEmpty),
    //                     footerW()
    //                   ],
    //                 ),
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     ),
    //   ),
    // );
    return Center(
      child: CustomInteractiveViewer(
        child: SizedBox(
          // height: 2000,
          height: wordDocument.getPageSectPr().height ?? 1000,
          width: wordDocument.getPageSectPr().width ?? 800,
          child: GestureDetector(
            onLongPress: () {
              print("<wordPage>");
              widget.wordPage.ps.forEach((p) {
                print(p.pXml?.toXmlString(pretty: true));
              });
              print("</wordPage>");
            },
            child: Container(
              decoration: BoxDecoration(color: Colors.white),
              child: Stack(
                children: [
                  pageHeaderW(),
                  widget.wordPage.getPageIamgesWiLi(),
                  Container(
                    margin: getSectionMargins(),
                    child: SingleChildScrollView(
                      child: SelectionArea(
                        child: Column(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ...widget.wordPage.ps
                            //     .map((e) => e.toWidget())
                            //     .toList(),
                            pageContentW(),
                            getSeperator(widget.wordPage.fns.isNotEmpty),
                            footerW()
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget getSeperator(bool isVisible) {
    return Visibility(
        visible: isVisible,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            color: Colors.black,
            height: 1,
            width: 250,
          ),
        ));
  }

  getSectionMargins() {
    // print("wordDocument.getPageSectPr()");
    // print(wordDocument.sectPrList.length);
    // print(wordDocument.getPageSectPr().rightMargin);
    // print(wordDocument.getPageSectPr().topMargin);
    // print(wordDocument.getPageSectPr().bottomMargin);

    return EdgeInsets.only(
      left: wordDocument.getPageSectPr().leftMargin ?? 8.0,
      right: wordDocument.getPageSectPr().rightMargin ?? 8.0,
      top: wordDocument.getPageSectPr().topMargin ?? 8.0,
      bottom: wordDocument.getPageSectPr().bottomMargin ?? 8.0,
    );
  }

  // Widget pageContentW() {
  //   // print(widget.wordPage.toHTML());
  //   return Html(
  //     // data: """<span class='aga_arabesque' style='font-size:40;'>&#xF079; &#xF01C;</span>""",
  //     data: """${widget.wordPage.toHTML()}""",
  //     style: wordDocument.getFontsStyle(),
  //     extensions: getHtmlExtensions(),
  //   );
  // }

  footerW() {
    return Visibility(
        visible: /*wordPage.fns.isNotEmpty*/ true,
        child: widget.wordPage.footerW());
  }

  Widget pageHeaderW() {
    return Padding(
      padding: EdgeInsets.only(
        left: wordDocument.getPageSectPr().leftMargin ?? 8.0,
        right: wordDocument.getPageSectPr().rightMargin ?? 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              // height: wordDocument.getPageSectPr()?.topMargin ?? 100,
              // width: (wordDocument.getPageSectPr()?.width ?? 800) - 200,
              child: wordDocument.getPageSectPr().getSectHeaderWidget(widget.wordPage)),
        ],
      ),
    );
  }

  pageContentW() {
    return widget.wordPage.toWidget();

  }
}

// List<HtmlExtension> getHtmlExtensions() {
//   return [
//     HRExtension(),
//     SdtRowExtension(),
//     TabExtenstion(),
//     TableExtenstion(),
//   ];
// }
//
// TagExtension TabExtenstion() {
//   return TagExtension(
//       tagsToExtend: {"tab"},
//       builder: (extentsionContext) {
//         double width = (wordDocument.getPageSectPr().width ?? 800) - 400;
//         String dots = getManydots(width);
//         return Text("");
//       });
// }
//
// TagExtension HRExtension() {
//   return TagExtension(
//       tagsToExtend: {"hr"},
//       builder: (extentsionContext) {
//         String stroke = extentsionContext.attributes["stroke"] ?? "1";
//         String colorS = extentsionContext.attributes["color"] ?? "black";
//         Color? color = colorMap[colorS];
//         double height = double.parse(stroke);
//
//         return Container(
//           width: (wordDocument.getPageSectPr().width ?? 800) - 300,
//           margin: EdgeInsets.only(left: 12, right: 12),
//           height: height,
//           color: color ?? Colors.black,
//         );
//       });
// }
//
// TableExtenstion() {
//   return TagExtension(
//       tagsToExtend: {"table"},
//       builder: (extentsionContext) {
//         Map<String, Style> styles = {};
//         styles.addAll(wordDocument.getFontsStyle());
//         //styles.remove("p.style");
//         return Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             mainAxisSize: MainAxisSize.min,
//             children: extentsionContext.elementChildren.first.children.map((e) {
//               return Row(
//                 textDirection: TextDirection.rtl,
//                 mainAxisSize: MainAxisSize.min,
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: e.children.map((e2) {
//                   String e2Html = e2.innerHtml
//                       .replaceAll("<br>", "")
//                       .replaceAll('</br>', "");
//                   return Html(
//                     data: e2Html,
//                     style: styles,
//                     shrinkWrap: true,
//                   );
//                 }).toList(),
//               );
//             }).toList(),
//           ),
//         );
//       });
// }
//
// SdtRowExtension() {
//   return TagExtension(
//       tagsToExtend: {SDT_ROW_HTML},
//       builder: (extentsionContext) {
//         var spans = extentsionContext.elementChildren.first.children
//             .where((e) => e.text.isNotEmpty)
//             .toList();
//         var lastSpanHtml = spans.isNotEmpty ? spans.last.outerHtml : "";
//         // if (spans.isNotEmpty) spans.removeLast();
//         String spanhtml = "";
//         spans.forEach((span) {
//           //print(span.attributes["toc"]);
//           if (spans.last != span) spanhtml = spanhtml + span.outerHtml;
//         });
//         return Row(
//           textDirection: TextDirection.rtl,
//           mainAxisSize: MainAxisSize.max,
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Html(
//               data: spanhtml,
//               shrinkWrap: true,
//               style: wordDocument.getFontsStyle(),
//             ),
//             Expanded(
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   int dotCount = (constraints.maxWidth / 4).floor();
//                   if (lastSpanHtml.isEmpty)
//                     return Container(
//                       width: 0,
//                       height: 0,
//                     );
//                   return Text(
//                     List.generate(dotCount, (index) => '.').join(),
//                     style: TextStyle(fontSize: 16),
//                     textAlign: TextAlign.center,
//                   );
//                 },
//               ),
//             ),
//             lastSpanHtml.isNotEmpty
//                 ? Html(
//                     data: lastSpanHtml,
//                     shrinkWrap: true,
//                     style: wordDocument.getFontsStyle(),
//                   )
//                 : Container(
//                     width: 0,
//                     height: 0,
//                   ),
//           ],
//         );
//       });
// }
// String getManydots(double width) {
//   return " . . . . . . . . . . . . . . . . . . . . ";
//   // String dots = "";
//   // print("width: $width");
//   // for(int i =0;i<width;i+20){
//   //   dots+=;
//   // }
//   // return dots;
// }
