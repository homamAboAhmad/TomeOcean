import 'package:golden_shamela/wordToHTML/Paragraph.dart';

import 'HyperLinkRun.dart';
const SDT_ROW_HTML = "sdtr";
extension Paragraphhyperlink on Paragraph {
  void checkHyperLink() {
    if(pXml?.getElement("w:hyperlink")==null) return;
    // print("hyperLink: ${pXml!.getElement("w:hyperlink")!.toXmlString(pretty: true)}");

    pXml!.getElement("w:hyperlink")!.childElements.forEach((e){
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
