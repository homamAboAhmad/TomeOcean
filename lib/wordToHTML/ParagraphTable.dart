import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/XmlElementUtils.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:xml/xml.dart';

class ParagraphTable extends Paragraph {
  ParagraphTable(super.parent);


  @override
  Widget toWidget() {
    if (pXml != null)
      return WordTableWidget(pXml!,super.parent);
    else {
      print("no table Found!!!!");
      return Container();
    }
  }

}

class WordTableWidget extends StatelessWidget {
  XmlElement tblXml;
  WordPage parent;
  double tableWidthPx = 4000;
  WordTableWidget(this.tblXml,this.parent);

  @override
  Widget build(BuildContext context) {
    tableWidthPx = getTableWidthPx(context);
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [...getRowsWList()],
      ),
    );

  }

  List<XmlElement> getXmlRows() {
    return tblXml.childElements.where((n) => n.name.local == 'tr').toList();
  }

  double getRowHeight(XmlElement row) {
    String rowHeightS = row
            .getElement("w:trPr")
            ?.getElement("w:trHeight")
            ?.getAttribute("w:val") ??
        "350";
    double rowHeight = double.tryParse(rowHeightS)?.twpsToPx() * 1.5 ?? 50;
    return rowHeight;
  }

  List<XmlElement> getRowCells(XmlElement row) {
    return row.childElements.where((n) => n.name.local == 'tc').toList();

  }

  double getCellWidth(XmlElement rowCell) {
    final tcW = rowCell
        .getElement("w:tcPr")
        ?.getElement("w:tcW");
    if (tcW == null) return 200;
    final wS = tcW.getAttribute("w:w") ?? "0";
    String type = tcW.getAttribute("type") ?? "dxa";
    final wVal = double.tryParse(wS) ?? 0;

    switch (type) {
      case "dxa":
        return wVal.twpsToPx(); // 1 dxa = 1/20 نقطة ≈ twipsToPx
      case "pct":
      // pct يُعطى بخمسين من المئة، ونطبق كنسبة من عرض الجدول
        return tableWidthPx * (wVal / 5000);
      case "auto":
      // اختر عرض افتراضي أو قم بقياس المحتوى
        return wVal > 0 ? wVal.twpsToPx() : 100;
      default:
      // fallback: اعتبرها dxa
        return wVal.twpsToPx();
    }
  }


  Widget getCellWidget(XmlElement rowCell) {
    double cellWidth = getCellWidth(rowCell);
    XmlElement? xmlElement = rowCell.getElement("w:p");
    if (xmlElement == null)
      return Container(
        width: cellWidth,
      );
    Paragraph paragraph = Paragraph(parent).fromXml(xmlElement);
    return Container(
      decoration:
          BoxDecoration(border: Border.all(width: 1, color: Colors.black54)),
      width: cellWidth - cellWidth / 5,
      child: paragraph.toWidget(),
    );
  }

  List<Widget> getRowCellsWList(XmlElement row) {
    List<XmlElement> rowCells = getRowCells(row);
    List<Widget> rowCellsW = [];
    rowCells.forEach((rowCell) {
      rowCellsW.add(getCellWidget(rowCell));
    });
    return rowCellsW;
  }

 List<Widget> getRowsWList() {
   List<XmlElement> rows = getXmlRows();
   List<Widget> rowsW = [];
   rows.forEach((row) {
     rowsW.add(SizedBox(
       height: getRowHeight(row),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         textDirection: TextDirection.rtl,
         children: [...getRowCellsWList(row)],
       ),
     ));
   });
   return rowsW;
 }

  double getTableWidthPx(BuildContext context) {
    final tblW = tblXml
        .getElement('w:tblPr')
        ?.getElement('w:tblW');
    if (tblW == null) return MediaQuery.sizeOf(context).width;

    final wS = tblW.getAttribute('w:w') ?? '0';
    String type = tblW.getAttribute('type') ?? 'dxa';
    final wVal = double.tryParse(wS) ?? 0;
    switch (type) {
      case 'pct':
        return MediaQuery.sizeOf(context).width * (wVal / 5000);
      case 'dxa':
      case 'fixed':
        return wVal.twpsToPx();
      default:
        return MediaQuery.sizeOf(context).width;
    }
  }

}
