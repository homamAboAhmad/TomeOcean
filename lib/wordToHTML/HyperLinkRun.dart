import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class HyperLinkRun extends runT {
  String? url;
  String? tooltip; // w:tooltip attribute from hyperlink

  HyperLinkRun(super.parent, {required super.prPr, required super.pPr});

  @override
  void checkParaRpr() {
    rpr?.b = prPr?.b;
    rpr?.i = prPr?.i;
    rpr?.u = prPr?.u;
    rpr?.uColor = prPr?.uColor;
    rpr?.color = prPr?.color;
    rpr?.highlightColor = prPr?.highlightColor;
    rpr?.rtl = prPr?.rtl;
    rpr?.font ??= prPr?.font;
    rpr?.fontSize = prPr?.fontSize;
    rpr?.vertAlign = prPr?.vertAlign;
  }

  @override
  InlineSpan toWidget() {
    if (url != null) {
      // Force blue color and underline for hyperlinks
      TextStyle style = getEffectiveTextStyle().copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        decorationColor: Colors.blue,
      );

      // Note: Tooltip cannot be used with TextSpan directly as it requires a Widget.
      // Using WidgetSpan breaks TOC layout, so we use TextSpan without tooltip.
      // The tooltip property is still available for future use if needed.
      return TextSpan(
        text: checkDiacritics(),
        style: style,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              final uri = Uri.parse(url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                print("Could not launch URL: $url");
              }
            } catch (e) {
              print("Error launching URL: $e");
            }
          },
      );
    }

    return super.toWidget();
  }
}

extension bookMarkRun on runT {
  bool hasBookMark() {
    return xmlRun?.getElement("w:bookmarkStart") != null;
  }

  String? getBookMarkToc() {
    if (!hasBookMark()) return null;
    return xmlRun?.getElement("w:bookmarkStart")?.getAttribute("w:name");
  }

  void checkBookMark() {
    String? bookMarkToc = getBookMarkToc();
    if (bookMarkToc != null) {
      WordDocument? wordDocument = parent?.parent?.parent;
      // print("DEBUG: Found bookmark '$bookMarkToc' - adding to map");
      wordDocument?.addBookMark(bookMarkToc);
    }
  }

  String tocH() {
    if (toc == null)
      return '';
    else
      return 'toc="$toc"';
  }

  void checkToc() {
    String? instrTxt = xmlRun?.getElement("w:instrText")?.text;
    if (instrTxt == null) return;
    if (instrTxt.contains("Toc")) {
      toc = instrTxt.split(" ")[0];
    }
  }
}
