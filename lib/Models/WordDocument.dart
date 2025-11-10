import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/PPr.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:xml/xml.dart';

import '../FontsLoaderController.dart';
import '../wordToHTML/DocRelations.dart';
import '../wordToHTML/FootNote.dart';
import '../wordToHTML/Num.dart';
import '../wordToHTML/SectPr.dart';
import '../wordToHTML/abstractNum.dart';

class WordDocument {
  String title="BOOK";
  List<WordPage> pages = [];
  RPr? defaultRPr;
  PPr? defaultPPr;
  String? majorFont, minorFont;
  String autoDarkColor = "000000";
  String autoLightColor = "FFFFFF";
  Map<int, AbstractNum> abstractNumMap = {};
  Map<int, Num> numsMap = {};
  List<String> fontsList = [];
  Map<int, int> paragraphNumMap = {};
  SectPr? sectpr;
  List<SectPr> sectPrList = [];
  int currentPage = 0;
  List<String> pageContents = [];
  Map<String, FootNote> docFootNotes = {};
  Map<String,int> bookMarksMap = {};
  Map<String, RelId> relIdList = {};
  Map<String,Uint8List> docImages = {};
  Map<String, XmlElement> documentStyles = {};
  bool withDiacritics=true;
  List<IndexItem> index =[];
  String? selectedIndexItem;

  List<String> getFontsList() {
    return fontsList;
  }

  WordPage getCurrentPage() {
    WordPage empty = WordPage(this);
    empty.parent=this;
    if (pages.length == 0)
      return empty;
    else
      return pages[currentPage] ?? empty;
  }

  WordPage getLastPage() {
    return pages.last;
  }

  // Map<String, Style> getFontsStyle() {
  //   List<String> fonts = getFontsList();
  //   loadFonts(fonts);
  //   Map<String, Style> styles = {};
  //   fonts.forEach((font) {
  //     // print(font.toString());
  //
  //     String fixedFont = getFixedFontName(font);
  //     if (!isProblemFont(font))
  //       styles["span.$fixedFont"] = Style(
  //         fontFamily: font,
  //       );
  //   });
  //   styles["p.style"] = Style(
  //     whiteSpace: WhiteSpace.pre,
  //   );
  //   // styles["img"] = Style(
  //   //   display: Display.inlineBlock,
  //   //   // margin: Margins(left: Margin(200)), // إضافة مسافة حول الصور
  //   //
  //   // );
  //   // styles["div"] = Style(
  //   //   margin: Margins(top: Margin(100))
  //   // );
  //   styles["img"] = Style(
  //     display: Display.inlineBlock,
  //   );
  //   styles["div.P2"] = Style(
  //     display: Display.inlineBlock,
  //   );
  //   // styles["span.(A)_Arslan_Wessam_B.ttf"]=Style(fontFamily: "arslanB");
  //   // print(styles.keys.map((s)=>s).join("-").to/String());
  //   return styles;
  // }

  int addParagraphNum(int numId, int ilvl) {
    int key = ilvl * 1000 + numId;
    if (paragraphNumMap[key] == null)
      paragraphNumMap[key] = 1;
    else
      paragraphNumMap[key] = paragraphNumMap[key]! + 1;

    return paragraphNumMap[key]!;
  }

  SectPr getPageSectPr() {
    if (sectPrList.isEmpty)
      return SectPr.empty(this);
    else {
      SectPr sectPr = sectPrList[0];
      sectPrList.forEach((sect) {
        if (currentPage >= sect.firstRange && currentPage <= sect.lastRange) {
          sectPr = sect;
          return;
        }
      });
      return sectPr;
    }
  }

  addSectPr(XmlElement element) {
    print("sectPr Found into p");
    SectPr sectpr = getSectPrFrmXml(element,this);
    SectPr? lastSectPr = sectPrList.lastOrNull;
    sectpr.firstRange = lastSectPr != null ? lastSectPr.lastRange + 1 : 0;
    sectpr.lastRange = this.pages.length;
    sectpr.parent=this;
    sectPrList.add(sectpr);
    print(sectPrList.length);
  }

  addBookMark(String bookMarkToc){
    bookMarksMap[bookMarkToc]=pages.length-1;
  }
}

String getFixedFontName(String font) {
  return font
      .replaceAll(" ", "_")
      .replaceAll(")", "")
      .replaceAll("(", "")
      .replaceAll("-", "_")
      .toLowerCase();
}

List<String> problemFontsList = [/*"Tholoth Rounded", "AL-Qairwan"*/];

bool isProblemFont(String font) {
  return problemFontsList.contains(font);
}
