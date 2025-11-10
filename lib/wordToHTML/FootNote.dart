


import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';

class FootNote{
  Paragraph p;
  String id;
  String? _displayNumber;

  FootNote(this.p, this.id);

  updateDisplayNumber(String dn){
    _displayNumber =dn;
    int i = 0;
    runT r = p.runs[0];
    if(r.rpr?.rPr?.getElement("w:rStyle")?.getAttribute("w:val")=="FootnoteReference") {
      r.fnDisplayNum=dn;
      if(r.xmlRun?.getAttribute("w:t")==null) {
        r.footNoteId = id;
        r.updateFnDisplayNumber();
      }
   }
    mergeFnrRuns();

  }
  //fnr= foot note reference
  // this fix seperating fnr content from each other
  void mergeFnrRuns() {
    List<runT> fnrRuns = [];
    for(runT r in p.runs){
      if(isFnr(r))
        fnrRuns.add(r);
    }
    String newTxt = "";
    for(runT r in fnrRuns){
      newTxt = newTxt+(r.text??"");
      r.text ="";
    }
    if(fnrRuns.isNotEmpty)
    fnrRuns[0].text = newTxt;
  }

  bool isFnr(runT r){
    return r.rpr?.rPr?.getElement("w:rStyle")?.getAttribute("w:val")=="FootnoteReference";
  }

}