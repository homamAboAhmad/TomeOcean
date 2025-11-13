


import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:json_annotation/json_annotation.dart';

import '../Models/WordPage.dart';

part 'FootNote.g.dart';

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class FootNote{
  Paragraph p;
  String id;
  String? displayNumber;

  FootNote(this.p, this.id);

  FootNote.empty() : p = Paragraph.empty(), id = '';

  factory FootNote.fromJson(Map<String, dynamic> json) => _$FootNoteFromJson(json);
  Map<String, dynamic> toJson() => _$FootNoteToJson(this);

  static FootNote fromMap(Map<String, dynamic> json, WordPage parent) {
    final footNote = _$FootNoteFromJson(json);
    footNote.p = Paragraph.fromMap(json['p'] as Map<String, dynamic>, parent);
    return footNote;
  }

  updateDisplayNumber(String dn){
    displayNumber =dn;
    if (p.runs.isEmpty) {
      print("Warning: Footnote with ID ${id} has no runs in its paragraph.");
      return;
    }
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