import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:json_annotation/json_annotation.dart';

import '../Models/WordPage.dart';

part 'FootNote.g.dart';

@JsonSerializable(explicitToJson: true, constructor: 'empty')
class FootNote {
  Paragraph p;
  String id;
  String? displayNumber;

  FootNote(this.p, this.id);

  FootNote.empty() : p = Paragraph.empty(), id = '';

  factory FootNote.fromJson(Map<String, dynamic> json) =>
      _$FootNoteFromJson(json);
  Map<String, dynamic> toJson() => _$FootNoteToJson(this);

  static FootNote fromMap(Map<String, dynamic> json, WordPage parent) {
    final footNote = _$FootNoteFromJson(json);
    footNote.p = Paragraph.fromMap(json['p'] as Map<String, dynamic>, parent);
    return footNote;
  }

  updateDisplayNumber(String dn) {
    displayNumber = dn;
    if (p.runs.isEmpty) {
      // print("Warning: Footnote with ID ${id} has no runs in its paragraph.");
      return;
    }

    bool found = false;
    // 1. Try to find explicit w:footnoteRef
    for (runT r in p.runs) {
      if (r.isFootnoteRef) {
        r.fnDisplayNum = dn;
        r.footNoteId = id;
        r.updateFnDisplayNumber();
        found = true;
        break;
      }
    }

    // 2. Fallback: find run with FootnoteReference style AND no text
    if (!found) {
      for (runT r in p.runs) {
        if (r.rpr?.rPr?.getElement("w:rStyle")?.getAttribute("w:val") ==
            "FootnoteReference") {
          // Check if it has no text (likely the placeholder)
          if (r.xmlRun?.getAttribute("w:t") == null &&
              (r.text == null || r.text!.isEmpty)) {
            r.fnDisplayNum = dn;
            r.footNoteId = id;
            r.updateFnDisplayNumber();
            found = true;
            break;
          }
        }
      }
    }

    // Capture the style ID used by the footnote reference
    String? fnrStyle;
    for (runT r in p.runs) {
      if (r.isFootnoteRef || r.footNoteId == id) {
        fnrStyle = r.rpr?.rPr?.getElement("w:rStyle")?.getAttribute("w:val");
        if (fnrStyle != null) break;
      }
    }

    // Fallback if no specific ref found but we rely on hardcode
    if (fnrStyle == null) fnrStyle = "FootnoteReference";

    mergeFnrRuns(fnrStyle);
  }

  void mergeFnrRuns(String styleVal) {
    List<runT> fnrRuns = [];
    for (runT r in p.runs) {
      if (isFnr(r, styleVal)) fnrRuns.add(r);
    }
    String newTxt = "";
    for (runT r in fnrRuns) {
      newTxt = newTxt + (r.text ?? "");
      r.text = "";
    }
    if (fnrRuns.isNotEmpty) fnrRuns[0].text = newTxt;
  }

  bool isFnr(runT r, String styleVal) {
    return r.rpr?.rPr?.getElement("w:rStyle")?.getAttribute("w:val") ==
        styleVal;
  }
}
