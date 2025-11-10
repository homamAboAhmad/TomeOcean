

import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';

import '../main.dart';

class HyperLinkRun extends runT{
  HyperLinkRun(super.parent,{required super.prPr, required super.pPr});
  @override
  void checkParaRpr() {
    rpr?.b = prPr?.b;
    rpr?.i = prPr?.i;
    rpr?.u = prPr?.u;
    rpr?.uColor = prPr?.uColor;
    rpr?.color = prPr?.color;
    rpr?.highlightColor = prPr?.highlightColor;
    rpr?.rtl = prPr?.rtl;
    rpr?.font = prPr?.font;
    rpr?.fontSize = prPr?.fontSize;
    rpr?.vertAlign = prPr?.vertAlign;
  }


}
extension bookMarkRun on runT{
  bool hasBookMark(){
    return xmlRun?.getElement("w:bookmarkStart")!=null;
  }
  String? getBookMarkToc(){
    if(!hasBookMark())return null;
    return xmlRun?.getElement("w:bookmarkStart")?.getAttribute("w:name");
  }
  void checkBookMark() {
    String? bookMarkToc = getBookMarkToc();
    if(bookMarkToc!=null) {
      WordDocument? wordDocument = parent?.parent?.parent;
      wordDocument?.addBookMark(bookMarkToc);
    }
  }

  String tocH(){
    if(toc==null) return '';
    else return 'toc="$toc"';
  }
  void checkToc() {
    String? instrTxt =xmlRun?.getElement("w:instrText")?.text;
    if(instrTxt==null) return;
    if(instrTxt.contains("Toc")){
      toc = instrTxt.split(" ")[0];
    }
  }
}