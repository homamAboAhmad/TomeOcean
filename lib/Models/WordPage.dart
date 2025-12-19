// import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/wordToHTML/FootNote.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

import '../WordToWidget/ImageToWidget.dart';
import '../wordToHTML/Paragraph.dart';
import '../wordToHTML/SectPr.dart';

part 'WordPage.g.dart';

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class WordPage {
  List<Paragraph> ps = [];
  List<FootNote> fns = [];
  String pageNum = "";

  /// The 1-based page index (used for bookmark tracking)
  int pageIndex = 0;
  @JsonKey(ignore: true)
  WordDocument parent;

  WordPage(this.parent);

  WordPage.empty() : parent = WordDocument.empty();

  factory WordPage.fromJson(Map<String, dynamic> json) =>
      _$WordPageFromJson(json);
  Map<String, dynamic> toJson() => _$WordPageToJson(this);

  static WordPage fromMap(Map<String, dynamic> json, WordDocument parent) {
    final wordPage = _$WordPageFromJson(json);
    wordPage.parent = parent;
    wordPage.ps = (json['ps'] as List<dynamic>)
        .map((e) => Paragraph.fromMap(e as Map<String, dynamic>, wordPage))
        .toList();
    for (var fn in wordPage.fns) {
      fn.p.parent = wordPage; // Re-establish parent for footnote paragraphs
    }
    return wordPage;
  }

  String text() {
    String text = "";
    ps.forEach((paragraph) {
      text = text + "\n" + paragraph.text;
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
      children: [...ps.map((e) => e.toWidget()).toList()],
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

  /// الصور الخلفية (behindDoc=true) - تُعرض خلف الهيدر والمحتوى
  Widget getBackgroundImages() {
    List<ImageData> list = getPageImageData();
    List<ImageData> backgroundImages = list
        .where((img) => img.behindDoc)
        .toList();
    return imageToWidgetList(backgroundImages);
  }

  /// الصور الأمامية (behindDoc=false) - تُعرض أمام الهيدر والمحتوى
  Widget getForegroundImages() {
    List<ImageData> list = getPageImageData();
    List<ImageData> foregroundImages = list
        .where((img) => !img.behindDoc)
        .toList();
    // ترتيب حسب relativeHeight
    foregroundImages.sort(
      (a, b) => a.relativeHeight.compareTo(b.relativeHeight),
    );
    return imageToWidgetList(foregroundImages);
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

  /// الحواشي (Footnotes) - تظهر داخل حدود الصفحة
  Widget footnotesW() {
    if (fns.isEmpty) return SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...fns.map(
          (fn) => SelectionArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 2.0,
              ),
              child: fn.p.toWidget(),
            ),
          ),
        ),
      ],
    );
  }

  /// رقم الصفحة (Footer) - يظهر في الهامش السفلي
  Widget footerW() {
    SectPr sectPr = parent.getSectPrForPage(this.pageIndex - 1);

    // Calculate page number using the document's current page index
    String pageNumStr = sectPr.calculatePageNumber(this.pageIndex - 1);

    Widget footerContent = sectPr.getSectFooterWidget(this, pageNumStr);

    return footerContent;
  }

  // getPageNumW removed as it is no longer needed

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

  /// طباعة XML الصفحة كاملاً مع إخفاء بيانات الصور الطويلة
  void printPageXml() {
    print(
      "╔══════════════════════════════════════════════════════════════════╗",
    );
    print(
      "║                     PAGE XML START                               ║",
    );
    print(
      "╚══════════════════════════════════════════════════════════════════╝",
    );

    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      "╔══════════════════════════════════════════════════════════════════╗",
    );
    buffer.writeln(
      "║                     PAGE XML START                               ║",
    );
    buffer.writeln(
      "╚══════════════════════════════════════════════════════════════════╝",
    );

    for (int i = 0; i < ps.length; i++) {
      var p = ps[i];
      // استخدام xmlString المحفوظ، أو pXml إذا كان متاحاً
      String? xmlStr;
      if (p.xmlString.isNotEmpty) {
        xmlStr = p.xmlString;
      } else if (p.pXml != null) {
        xmlStr = p.pXml!.toXmlString(pretty: true);
      }

      if (xmlStr != null && xmlStr.isNotEmpty) {
        String logMsg = "\n--- Paragraph $i ---";
        print(logMsg);
        print(xmlStr);

        buffer.writeln(logMsg);
        buffer.writeln(xmlStr);
      }
    }

    print(
      "\n╔══════════════════════════════════════════════════════════════════╗",
    );
    print(
      "║                      PAGE XML END                                ║",
    );
    print(
      "╚══════════════════════════════════════════════════════════════════╝",
    );

    buffer.writeln(
      "\n╔══════════════════════════════════════════════════════════════════╗",
    );
    buffer.writeln(
      "║                      PAGE XML END                                ║",
    );
    buffer.writeln(
      "╚══════════════════════════════════════════════════════════════════╝",
    );

    // try {
    //   final file = File('page_xml_debug.xml');
    //   file.writeAsStringSync(buffer.toString());
    //   print("✅ XML saved to file: ${file.absolute.path}");
    // } catch (e) {
    //   print("❌ Error saving XML to file: $e");
    // }
  }
}

List<ImageData> getParagraphImages(List<Paragraph> paragraphs) {
  List<ImageData> list = [];
  paragraphs.forEach((p) {
    p.runs.forEach((r) {
      if (r.image != null && !r.isRelativeFromVParagraph()) {
        // تخطي مربعات النص هنا لأننا نعرضها داخل الفقرة نفسها
        if (r.image!.textBoxText != null && r.image!.textBoxText!.isNotEmpty) {
          return;
        }
        list.add(r.image!);
      } /*else if (r.image != null && r.isRelativeFromVParagraph()) {
        print("there is image but is relative");
      }*/
    });
  });
  // ترتيب الصور: في Stack العناصر الأخيرة تظهر فوق العناصر السابقة
  // 1. أولاً: الصور خلف النص (behindDoc=true) تأتي أولاً في القائمة (تظهر تحت)
  // 2. ثانياً: الصور أمام النص (behindDoc=false) تأتي في النهاية (تظهر فوق)
  // 3. داخل كل مجموعة: ترتيب تصاعدي حسب relativeHeight
  list.sort((a, b) {
    // الصور خلف النص تأتي أولاً
    if (a.behindDoc != b.behindDoc) {
      return a.behindDoc ? -1 : 1; // behindDoc=true يأتي أولاً (يظهر تحت)
    }
    // داخل نفس المجموعة، ترتيب حسب relativeHeight تصاعدياً
    return a.relativeHeight.compareTo(b.relativeHeight);
  });

  return list;
}

Widget imageToWidgetList(List<ImageData> list) {
  if (list.isEmpty) {
    return SizedBox.shrink();
  }

  List<Widget> imagesW = [];
  list.forEach((image) {
    imagesW.add(getImageWidget(image));
  });

  // Stack مع Align children يعمل بشكل صحيح
  // ترتيب الصور حسب behindDoc و relativeHeight يحدد أي صورة تظهر فوق الأخرى
  return Stack(children: [...imagesW]);
}
