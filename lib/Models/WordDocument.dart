import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/PPr.dart';
import 'package:golden_shamela/wordToHTML/RPr.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

import '../FontsLoaderController.dart';
import '../Utils/json_converters.dart';
import '../wordToHTML/DocRelations.dart';
import '../wordToHTML/FootNote.dart';
import '../wordToHTML/Num.dart';
import '../wordToHTML/SectPr.dart';
import '../wordToHTML/abstractNum.dart';

part 'WordDocument.g.dart';

@JsonSerializable(explicitToJson: true)
class WordDocument {
  String title="BOOK";
  @JsonKey(ignore: true)
  List<WordPage> _loadedPages = []; // Cache for loaded pages
  @JsonKey(ignore: true)
  List<String> pageFilePaths = []; // Paths to page JSON files
  @JsonKey(ignore: true)
  String? pagesDirectory; // Directory where page JSONs are stored

  RPr? defaultRPr;
  PPr? defaultPPr;
  String? majorFont, minorFont;
  String autoDarkColor = "000000";
  String autoLightColor = "FFFFFF";
  Map<int, AbstractNum> abstractNumMap = {};
  @JsonKey(fromJson: _intKeyMapFromJsonNum, toJson: _intKeyMapToJsonNum)
  Map<int, Num> numsMap = {};
  @JsonKey(ignore: true)
  List<String> fontsList = [];
  @JsonKey(ignore: true)
  Map<int, int> paragraphNumMap = {};
  SectPr? sectpr;
  List<SectPr> sectPrList = [];
  int currentPage = 0;
  @JsonKey(ignore: true)
  List<String> pageContents = [];
  Map<String, FootNote> docFootNotes = {};
  Map<String,int> bookMarksMap = {};
  Map<String, RelId> relIdList = {};
  @JsonKey(fromJson: _docImagesFromJson, toJson: _docImagesToJson)
  Map<String,Uint8List> docImages = {};
  @JsonKey(fromJson: _documentStylesFromJson, toJson: _documentStylesToJson)
  Map<String, XmlElement> documentStyles = {};
  bool withDiacritics=true;
  List<IndexItem> index =[];
  String? selectedIndexItem;

  WordDocument() : _loadedPages = [], pageFilePaths = [];

  void setLoadedPages(List<WordPage> pages) {
    _loadedPages = pages;
    // Also update pageFilePaths to reflect the loaded pages
    pageFilePaths = List.generate(pages.length, (index) => '$index.json');
  }

  void initLoadedPages() {
    _loadedPages = List.filled(pageFilePaths.length, WordPage.empty(), growable: true);
  }

  WordDocument.empty() : _loadedPages = [], pageFilePaths = [], pagesDirectory = null;

  factory WordDocument.fromJson(Map<String, dynamic> json) => _$WordDocumentFromJson(json);
  Map<String, dynamic> toJson() => _$WordDocumentToJson(this);

  Map<String, dynamic> toMetadataJson() {
    final json = _$WordDocumentToJson(this);
    // Ensure pages are not included in metadata, as they are now lazy-loaded
    json.remove('pages');
    return json;
  }

  static WordDocument fromCacheJson(Map<String, dynamic> json) {
    final wordDocument = _$WordDocumentFromJson(json);

    if (json['sectpr'] != null) {
      wordDocument.sectpr = SectPr.fromMap(json['sectpr'] as Map<String, dynamic>, wordDocument);
    }
    wordDocument.sectPrList = (json['sectPrList'] as List<dynamic>)
        .map((e) => SectPr.fromMap(e as Map<String, dynamic>, wordDocument))
        .toList();

    // wordDocument.docFootNotes = (json['docFootNotes'] as Map<String, dynamic>).map(
    //         (k, e) => MapEntry(k, FootNote.fromMap(e as Map<String, dynamic>, wordDocument.pages[0]))); // Assuming footnotes are tied to the first page for now

    wordDocument.index = (json['index'] as List<dynamic>)
        .map((e) => IndexItem.fromMap(e as Map<String, dynamic>))
        .toList();

    wordDocument.relIdList = (json['relIdList'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, RelId.fromMap(e as Map<String, dynamic>)));

    wordDocument.abstractNumMap = (json['abstractNumMap'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(int.parse(k), AbstractNum.fromMap(e as Map<String, dynamic>)));

    wordDocument.numsMap = (json['numsMap'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(int.parse(k), Num.fromMap(e as Map<String, dynamic>)));
    return wordDocument;
  }

  static Map<String, Uint8List> _docImagesFromJson(Map<String, dynamic> json) {
    print("_docImagesFromJson called with json: $json");
    return json.map((key, value) => MapEntry(key, uint8ListFromJson(value as String?) ?? Uint8List(0)));
  }

  static Map<String, String> _docImagesToJson(Map<String, Uint8List> object) {
    return object.map((key, value) => MapEntry(key, uint8ListToJson(value)!));
  }

  static Map<String, XmlElement> _documentStylesFromJson(Map<String, dynamic> json) {
    final converter = XmlElementConverter();
    return json.map((key, value) => MapEntry(key, converter.fromJson(value as String?) ?? XmlElement(XmlName('empty'))));
  }

  static Map<String, String> _documentStylesToJson(Map<String, XmlElement> object) {
    final converter = XmlElementConverter();
    return object.map((key, value) => MapEntry(key, converter.toJson(value)!));
  }

  static Map<int, AbstractNum> _intKeyMapFromJsonAbstractNum(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(int.parse(key), AbstractNum.fromJson(value as Map<String, dynamic>)));
  }

  static Map<String, dynamic> _intKeyMapToJsonAbstractNum(Map<int, AbstractNum> object) {
    return object.map((key, value) => MapEntry(key.toString(), value.toJson()));
  }

  static Map<int, Num> _intKeyMapFromJsonNum(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(int.parse(key), Num.fromJson(value as Map<String, dynamic>)));
  }

  static Map<String, dynamic> _intKeyMapToJsonNum(Map<int, Num> object) {
    return object.map((key, value) => MapEntry(key.toString(), value.toJson()));
  }

  List<String> getFontsList() {
    return fontsList;
  }

  Future<WordPage> getPage(int index) async {
    if (index < 0 || index >= pageFilePaths.length) {
      throw RangeError.index(index, pageFilePaths, "Page index out of bounds");
    }

    // Check if page is a placeholder (ps is empty for placeholders)
    if (_loadedPages.length > index && _loadedPages[index].ps.isNotEmpty) {
      return _loadedPages[index];
    }

    // Load page from file
    if (pagesDirectory == null) {
      throw StateError("pagesDirectory is not set for lazy loading.");
    }
    final pageFile = File('${pagesDirectory!}/${pageFilePaths[index]}');
    final pageJsonString = await pageFile.readAsString();
    final pageJsonMap = jsonDecode(pageJsonString) as Map<String, dynamic>;
    final loadedPage = WordPage.fromMap(pageJsonMap, this);

    // Ensure _loadedPages has the correct length before assigning.
    if (_loadedPages.length != pageFilePaths.length) {
      _loadedPages = List.filled(pageFilePaths.length, WordPage.empty(), growable: true);
    }

    _loadedPages[index] = loadedPage;
    return loadedPage;
  }

  // This method needs to be re-evaluated based on how UI consumes pages
  // For now, it will return a placeholder or throw an error.
  WordPage getCurrentPage() {
    throw UnimplementedError("getCurrentPage is not implemented for lazy loading. Use getPage(currentPage) instead.");
  }

  // This method needs to be re-evaluated based on how UI consumes pages
  // For now, it will return a placeholder or throw an error.
  WordPage getLastPage() {
    throw UnimplementedError("getLastPage is not implemented for lazy loading. Use getPage(pageFilePaths.length - 1) instead.");
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
    sectpr.lastRange = pageFilePaths.length; // Use pageFilePaths.length
    sectpr.parent=this;
    sectPrList.add(sectpr);
    print(sectPrList.length);
  }

  addBookMark(String bookMarkToc){
    bookMarksMap[bookMarkToc]=pageFilePaths.length-1; // Use pageFilePaths.length
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
