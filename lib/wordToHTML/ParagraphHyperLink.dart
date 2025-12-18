import 'package:golden_shamela/wordToHTML/Paragraph.dart';

import 'HyperLinkRun.dart';
const SDT_ROW_HTML = "sdtr";
extension Paragraphhyperlink on Paragraph {
  void checkHyperLink() {
    if(pXml?.getElement("w:hyperlink")==null) return;
    // print("hyperLink: ${pXml!.getElement("w:hyperlink")!.toXmlString(pretty: true)}");
    
    // Extract anchor for TOC navigation (e.g., "_Toc123456")
    // This will be persisted to cache for navigation without XML
    final hyperlinkElement = pXml!.getElement("w:hyperlink")!;
    hyperlinkAnchor = hyperlinkElement.getAttribute("w:anchor");

    hyperlinkElement.childElements.forEach((e){
      if(e.name.local=="r"){
        HyperLinkRun run = HyperLinkRun(this,prPr: prPr, pPr: pPr).fromXml(e);
        run.parent = this;
        runs.add(run);
      }else{
        print("hyperLinkChild new: ${e.localName}");
      }
    });
  }


  bool isSdtRow(){
    return pXml?.getAttribute("isSdtRow")=="True";
  }

}
