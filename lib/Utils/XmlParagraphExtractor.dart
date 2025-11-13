
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
      // print("this is SectPr");
      allPs.add(element);
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

    for (XmlElement element0 in sdt.childElements) {
      // print(element0.name.local);
      // print(element0.text);
      // element0.innerText = extractTextFromXmlElement(element0);
      // Paragraph paragraph = Paragraph().fromXml(element0);
      // print("paragraph:"+paragraph.toHTML());
      element0.setAttribute("isSdtRow", "True");
      ps.add(element0);
    }
  }
  return ps;
}
