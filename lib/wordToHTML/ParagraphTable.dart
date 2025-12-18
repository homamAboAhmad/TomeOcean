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
    // Ensure pXml is available. If loaded from cache, it might need parsing from xmlString
    if (pXml == null && xmlString.isNotEmpty) {
      try {
        pXml = XmlDocument.parse(xmlString).rootElement;
      } catch (e) {
        print("Error parsing table XML: $e");
      }
    }

    if (pXml != null)
      return WordTableWidget(pXml!, super.parent);
    else {
      return SizedBox.shrink();
    }
  }
}

class WordTableWidget extends StatelessWidget {
  XmlElement tblXml;
  WordPage parent;
  
  WordTableWidget(this.tblXml, this.parent);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    
    // 1. Calculate Total Table Width in Twips from Grid
    double totalGridTwips = _getTotalGridTwips();
    if (totalGridTwips == 0) totalGridTwips = 1;

    // 2. Convert Twips to Pixels (Standard Word scaling)
    // 1 Twip = 1/1440 inch. At 96 DPI, 1 pixel = 15 twips.
    // But we use a custom factor often used in this project: 0.0667
    double naturalWidthPx = totalGridTwips * 0.0667;

    // 3. Determine Scale Factor and Final Width
    double scaleFactor;
    double finalTableWidth;

    if (naturalWidthPx <= screenWidth) {
      // If table fits, use its natural size
      scaleFactor = 0.0667;
      finalTableWidth = naturalWidthPx;
    } else {
      // If table is too big, scale it down to fit screen
      finalTableWidth = screenWidth;
      scaleFactor = screenWidth / totalGridTwips;
    }

    return Container(
      width: screenWidth, // Container takes full width to allow centering
      alignment: Alignment.center, // Center the table if it's smaller than screen
      child: Container(
        width: finalTableWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: getRowsWList(scaleFactor),
        ),
      ),
    );
  }

  double _getTotalGridTwips() {
    var gridCols = tblXml.findAllElements('w:tblGrid').firstOrNull?.findAllElements('w:gridCol');
    if (gridCols != null && gridCols.isNotEmpty) {
      double sum = 0;
      for (var col in gridCols) {
        sum += double.tryParse(col.getAttribute('w:w') ?? '0') ?? 0;
      }
      if (sum > 0) return sum;
    }

    var firstRow = tblXml.findAllElements('w:tr').firstOrNull;
    if (firstRow != null) {
      double sum = 0;
      for (var cell in firstRow.findAllElements('w:tc')) {
        var w = cell.getElement('w:tcPr')?.getElement('w:tcW')?.getAttribute('w:w');
        sum += double.tryParse(w ?? '0') ?? 0;
      }
      if (sum > 0) return sum;
    }

    return 0;
  }

  Widget getCellWidget(XmlElement rowCell, double scaleFactor) {
    double cellTwips = 0;
    final tcW = rowCell.getElement("w:tcPr")?.getElement("w:tcW");
    if (tcW != null) {
       cellTwips = double.tryParse(tcW.getAttribute("w:w") ?? "0") ?? 0;
    }
    
    double cellWidthPx = cellTwips * scaleFactor;
    if (cellWidthPx <= 0) cellWidthPx = 10; // Minimal width fallback

    var paragraphsXml = rowCell.findAllElements("w:p");
    
    if (paragraphsXml.isEmpty)
      return Container(
        width: cellWidthPx,
        constraints: BoxConstraints(minHeight: 20),
      );

    List<Widget> pWidgets = [];
    for (var pXml in paragraphsXml) {
        Paragraph paragraph = Paragraph(parent).fromXml(pXml);

        // تخطي الفقرة فقط إذا كانت خالية تماماً ولا تحتوي حتى على فواصل أسطر
        if ((paragraph.text.trim().isEmpty) &&
            paragraph.runs.every((r) =>
                (r.text ?? "").trim().isEmpty &&
                r.hasBrBefore == false &&
                r.hasBrAfter == false)) {
          continue;
        }
        
        // Fix Alignment for Table Cells:
        // Center text if it's 'justify' (highKashida) to avoid ugly left/right gaps on short lines
        if (paragraph.textAlign == TextAlign.justify) {
           paragraph.textAlign = TextAlign.center;
        }
        
        // Ensure RTL
        if (paragraph.textDirection != TextDirection.rtl) {
            paragraph.textDirection = TextDirection.rtl;
        }

        pWidgets.add(
          DefaultTextStyle.merge(
            style: const TextStyle(height: 0.9), // تقليل ارتفاع السطر داخل الجداول
            child: paragraph.toWidget(),
          ),
        );
    }

    return Container(
      width: cellWidthPx,
      padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0), // تقليل padding الرأسي
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pWidgets,
      ),
    );
  }

  // استخراج ارتفاع الصف من XML (w:trHeight)
  double? _getRowHeightTwips(XmlElement row) {
    var trPr = row.getElement('w:trPr');
    if (trPr == null) return null;
    
    var trHeight = trPr.getElement('w:trHeight');
    if (trHeight == null) return null;
    
    String? heightVal = trHeight.getAttribute('w:val');
    if (heightVal == null) return null;
    
    return double.tryParse(heightVal);
  }

  List<Widget> getRowsWList(double scaleFactor) {
    List<XmlElement> rows = tblXml.childElements.where((n) => n.name.local == 'tr').toList();
    List<Widget> rowsW = [];
    
    for (var row in rows) {
       List<XmlElement> rowCells = row.childElements.where((n) => n.name.local == 'tc').toList();
       List<Widget> cellsW = [];
       
       for (var cell in rowCells) {
         cellsW.add(getCellWidget(cell, scaleFactor));
       }
       
       // استخدام ارتفاع الصف من XML كحد أدنى فقط (minHeight)
       // لأن المحتوى قد يكون أكبر من الارتفاع المحدد
       double? rowHeightTwips = _getRowHeightTwips(row);
       double? rowHeightPx = rowHeightTwips != null ? rowHeightTwips * 0.0667 : null;
       
       Widget rowWidget = Row(
         mainAxisSize: MainAxisSize.min,
         textDirection: TextDirection.rtl,
         crossAxisAlignment: CrossAxisAlignment.start,
         children: cellsW,
       );
       
       // إذا كان هناك ارتفاع محدد، نستخدم ConstrainedBox مع minHeight
       // هذا يضمن أن الصف لا يكون أصغر من الارتفاع المحدد، لكن يمكن أن يكون أكبر إذا كان المحتوى أكبر
       if (rowHeightPx != null && rowHeightPx > 0) {
         rowsW.add(ConstrainedBox(
           constraints: BoxConstraints(minHeight: rowHeightPx),
           child: rowWidget,
         ));
       } else {
         rowsW.add(rowWidget);
       }
    }
    return rowsW;
  }
}
