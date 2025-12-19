import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/Utils/TxtUtils.dart';
import 'package:golden_shamela/WordToWidget/ImageToWidget.dart';
import 'package:golden_shamela/wordToHTML/HyperLinkRun.dart';
import 'package:golden_shamela/wordToHTML/PPr.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/wordToHTML/TabStop.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';

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

  /// Whether this run contains a w:tab element (for TOC entry/page number separation)
  /// This is serialized to cache since xmlRun is ignored
  bool hasTab = false;

  @JsonKey(ignore: true)
  Paragraph parent;

  @JsonKey(ignore: true)
  Map<String, RelId>? customRelIdList;

  runT(
    this.parent, {
    required this.prPr,
    required this.pPr,
    this.customRelIdList,
  });

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
      runT.image = ImageData.fromMap(
        json['image'] as Map<String, dynamic>,
        runT,
      );
    }

    // التحقق من الرموز عند التحميل من الكاش أيضاً
    // (xmlRun سيكون null، لكن rpr?.font يجب أن يكون محفوظاً)
    runT.checkSymbol();

    return runT;
  }

  bool isFootnoteRef = false;

  fromXml(XmlElement? xmlRun) {
    this.xmlRun = xmlRun;
    // Check for tab element (used for TOC entry/page number separation)
    hasTab = xmlRun?.getElement("w:tab") != null;
    getText();

    checkBr();
    checkFnId();
    checkBookMark();

    // Check for footnoteRef
    isFootnoteRef = xmlRun?.getElement("w:footnoteRef") != null;

    XmlElement? xmlrPr = xmlRun?.getElement("w:rPr");
    if (xmlrPr != null) {
      rpr = RPr(this).fromXml(xmlrPr);
      rpr?.parent = this;
    }
    // التحقق من الرموز (w:sym) بعد استخراج النص وتعيين rpr
    checkSymbol();
    checkParaRpr();
    checkToc();

    bool isImg = isImageRun(xmlRun);
    if (isImg) {
      // print("DEBUG: Found image run in fromXml");
      try {
        image = parseImageData(this, customRelIdList: customRelIdList);
        // if (image != null) {
        //   print("DEBUG: Image parsed successfully. ID: ${image?.rId}, TextBox: ${image?.textBoxText}");
        // } else {
        //   print("DEBUG: Image parsing returned null");
        // }
      } catch (e) {
        // Error parsing image data - silently ignore
      }
    }
    return this;
  }

  isRelativeFromVParagraph() {
    if (image == null) return false;

    // Reverted: Allow text boxes to be relative/positioned if the XML says so.
    // This allows them to overlap images correctly.
    // if (image!.textBoxText != null && image!.textBoxText!.isNotEmpty) return false;

    return image?.relativeFromV == "paragraph" ||
        image?.relativeFromV == "line";
  }

  InlineSpan toWidgetWithImg() {
    // Fix: Check image property instead of xmlRun since xmlRun is not saved in cache
    if (image != null) {
      Widget w = getImageWidget(image!);
      // Reverted the newline insertion.
      // We treat the text box as an inline widget. It should flow naturally after the preceding element.
      return WidgetSpan(child: w);
    } else
      return toWidget();
  }

  InlineSpan toWidget() {
    // Fix: Check image property instead of xmlRun since xmlRun is not saved in cache
    if (image != null) {
      // Debugging: why is this treated as text run if it's an image?
      // print("DEBUG: toWidget called for Image Run. This should not happen if it's in imageRunTs.");
      return TextSpan(text: "");
    }

    String bBr = hasBrBefore ? "\n" : "";
    String aBr = hasBrAfter ? "\n" : "";
    Widget? tab = getTabWidget();
    // fixFnr() removed - parentheses are now fixed in addFnToPage
    checkSymbol();

    double vAlign = rpr?.getVertAlignNum() ?? 0;
    String fixedText = checkDiacritics();

    // Get effective text style (falls back to prPr if rpr is null)
    TextStyle effectiveStyle = getEffectiveTextStyle();

    if (vAlign != 0) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
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
            Text("$bBr$fixedText$aBr", style: effectiveStyle),
            tab,
          ],
        ),
      );
    } else {
      return TextSpan(text: "$bBr$fixedText$aBr", style: effectiveStyle);
    }
  }

  /// Get effective TextStyle, falling back to paragraph properties when run properties are null
  TextStyle getEffectiveTextStyle() {
    TextStyle style;
    // If rpr exists, use it
    if (rpr != null) {
      style = rpr!.getTextStyle();
    }
    // If rpr is null but prPr exists, use prPr
    else if (prPr != null) {
      style = prPr!.getTextStyle();
    }
    // Final fallback
    else {
      style = TextStyle(color: Colors.black, fontSize: 14, fontFamily: "jreg");
    }

    // Apply paragraph properties (line height) from parent Paragraph's PPr
    double? lineHeight = pPr?.lineHeight;
    // Fallback to parent paragraph's PPr if run's pPr doesn't have it
    if (lineHeight == null && parent.pPr != null) {
      lineHeight = parent.pPr!.lineHeight;
    }
    // Final fallback: Word 2007+ default spacing (1.15, not 1.0!)
    lineHeight ??= 1.15;

    style = style.copyWith(height: lineHeight);

    return style;
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
        else if (elements[i].name.local == "br")
          brP = i;
      }
      hasBrBefore = brP < tP;
      hasBrAfter = brP > tP;
    }
  }

  void checkFnId() {
    footNoteId = xmlRun
        ?.getElement("w:footnoteReference")
        ?.getAttribute("w:id");
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
    else if (text!.contains(")"))
      text = text!.replaceFirst(")", "(");
  }

  void getText() {
    // If this run contains instruction text (field code), ignore it
    if (xmlRun?.getElement("w:instrText") != null) {
      text = "";
      return;
    }

    // أولاً: محاولة استخراج النص من w:t
    String? tText = xmlRun?.getElement("w:t")?.text;

    text = tText ?? "";

    // إذا لم يكن هناك نص في w:t، نبحث عن w:sym
    if ((text?.isEmpty ?? true) && xmlRun != null) {
      var symElement = xmlRun!.findElements("w:sym").firstOrNull;
      if (symElement != null) {
        String? charHex = symElement.getAttribute("w:char");
        if (charHex != null && charHex.isNotEmpty) {
          try {
            int codePoint = int.parse(charHex, radix: 16);
            text = String.fromCharCode(codePoint);
          } catch (e) {
            text = "?"; // رمز بديل
          }
        }
      }
    }
  }

  checkSymbol() {
    // إذا كان xmlRun موجوداً، نبحث عن w:sym مباشرة
    if (xmlRun != null && hasSymbol()) {
      if (rpr == null) {
        rpr = RPr(this);
      }

      var symElement = xmlRun!.findElements("w:sym").firstOrNull;
      String? fontName = symElement?.getAttribute("w:font");
      String? charHex = symElement?.getAttribute("w:char");

      if (fontName != null && fontName.isNotEmpty) {
        rpr?.font = fontName;
      }

      if (charHex != null && charHex.isNotEmpty) {
        try {
          int codePoint = int.parse(charHex, radix: 16);
          if (text?.isEmpty ?? true) {
            text = String.fromCharCode(codePoint);
          }
        } catch (e) {
          if (text?.isEmpty ?? true) {
            text = "?";
          }
        }
      } else {
        if (text?.isEmpty ?? true) {
          text = "?";
        }
      }
    } else {
      // تحديد الخط المناسب حسب نوع النص
      if (rpr != null) {
        String? appropriateFont = changeFontByTxt(text);
        if (appropriateFont != null && appropriateFont.isNotEmpty) {
          rpr?.font = appropriateFont;
        }
      }
    }
  }

  bool hasSymbol() {
    return xmlRun?.findElements("w:sym").isNotEmpty ?? false;
  }

  Widget? getTabWidget() {
    if (xmlRun?.getElement("w:tab") == null) return null;

    // Get tab stops from parent paragraph's pPr
    PPr? paragraphPPr = parent.pPr;

    // Get the first defined tab stop (most common case: single tab)
    // Word applies tabs in order, so we use the first one for now
    TabStop? tabStop;
    if (paragraphPPr != null && paragraphPPr.tabStops.isNotEmpty) {
      tabStop = paragraphPPr.tabStops.first;
    }

    // Calculate width from tab position (twips to pixels)
    // If no tab defined, use default Word tab (720 twips = 0.5 inch)
    double tabWidth = tabStop?.positionInPx ?? (720 * 0.0667);

    // Ensure minimum visible width
    if (tabWidth < 20) tabWidth = 20;

    // Get leader type if any
    String? leaderType = tabStop?.leader;
    bool hasLeader = tabStop?.hasLeader ?? false;

    if (hasLeader) {
      return _buildLeaderWidget(leaderType, tabWidth);
    } else {
      // No leader - just space
      return SizedBox(width: tabWidth);
    }
  }

  Widget _buildLeaderWidget(String? leaderType, double width) {
    String leaderChar;
    switch (leaderType) {
      case "dot":
        leaderChar = ".";
        break;
      case "underscore":
        leaderChar = "_";
        break;
      case "hyphen":
        leaderChar = "-";
        break;
      case "middleDot":
        leaderChar = "·";
        break;
      case "heavy":
        leaderChar = "●";
        break;
      default:
        leaderChar = ".";
    }

    // Calculate how many characters needed to fill the width
    // Approximate char width based on leader type
    double charWidth = leaderChar == "."
        ? 4.0
        : (leaderChar == "_" ? 8.0 : 6.0);
    int charCount = (width / charWidth).floor();
    if (charCount < 1) charCount = 1;

    return SizedBox(
      width: width,
      child: Text(
        leaderChar * charCount,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontFamily: "jreg",
          color: Colors.black,
          letterSpacing: leaderChar == "_"
              ? 0
              : 1.0, // Underscores need no spacing
        ),
      ),
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
      return removeDiacritics(text ?? "");
  }
}
