
import 'package:golden_shamela/main.dart';
import 'package:xml/xml.dart';

List<XmlElement> getAllXmlParagraphs(XmlElement? body) {
  if(body==null)return [];
  List<XmlElement> allPs = [];
  int k = 0;
  List<XmlElement> xmlElements = body.childElements.toList();
  List foundHeadings = [];
  // body.findAllElements("w:bookmarkStart").forEach((e){
  //   print("bookmarkStart: ${e.toXmlString()}");
  // });

  for(int i=0;i<xmlElements.length;i++){
    XmlElement element = xmlElements[i];

   // print("xmlElement $i \n ${element.toXmlString(pretty: true)}");

    bool isParagraph = element.name.local == "p";
    if (isParagraph) {
      if(element.findAllElements("w:bookmarkStart").isNotEmpty){
       // print(element.toXmlString());
      }
      allPs.add(element);
    } else if (element.name.local == "tbl") {
      allPs.add(element);
    } else if (element.name.local == "sdt") { // sdt is فهرس
      // print("isSdt $k");
      // print("isSdt ${element.toXmlString(pretty: true)}");

      List<XmlElement> indexPs = getIndexParagrphXmls(element);
      allPs.addAll(indexPs);
    } else if (element.name.local == "sectPr") {
      // sectPr at body level is document's final section properties
      // It's NOT a paragraph and should NOT be added to allPs
      // (sectPr inside w:pPr is handled separately when processing paragraphs)
      // Skip it entirely
    } else {
      // print("addParagraphToPage: new Type:" + element.name.local);
      // print("addParagraphToPage: new Type:" + element.toXmlString(pretty: true));
    }
    // if(k>41&&k<45) {
    //   print("$k"+element.text);
    //   print("$k"+element.toXmlString());
    // }
    k++;
  }
  // body?.childElements.forEach((element) {
  //
  //
  // });
  // print("foundHeadings $foundHeadings");
  return allPs;
}

List<XmlElement> getIndexParagrphXmls(XmlElement element) {
  List<XmlElement> ps = [];
  XmlElement? sdt = element.getElement("w:sdtContent");

  if (sdt != null) {
    sdt.lastElementChild?.setAttribute("isLastPageLine", "true");
    
    int tocItemIndex = 0;
    for (XmlElement element0 in sdt.childElements) {
      // Check if TOC item has page break
      bool hasPageBreak = element0.findAllElements("w:lastRenderedPageBreak").isNotEmpty;
      if (hasPageBreak) {
        print("DEBUG TOC: Item $tocItemIndex has lastRenderedPageBreak!");
      }
      
      element0.setAttribute("isSdtRow", "True");
      ps.add(element0);
      tocItemIndex++;
    }
    print("DEBUG TOC: Total items extracted: $tocItemIndex");
  }
  return ps;
}
