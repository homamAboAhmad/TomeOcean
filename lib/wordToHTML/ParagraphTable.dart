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

    // 1. Get Grid Column Widths
    List<double> gridColWidths = _getGridColWidths();

    // 2. Calculate Total Table Width in Twips
    double totalGridTwips = 0;
    if (gridColWidths.isNotEmpty) {
      totalGridTwips = gridColWidths.fold(0, (sum, w) => sum + w);
    } else {
      // Fallback: Check first row if grid is missing
      var firstRow = tblXml.findAllElements('w:tr').firstOrNull;
      if (firstRow != null) {
        for (var cell in firstRow.findAllElements('w:tc')) {
          var w = cell
              .getElement('w:tcPr')
              ?.getElement('w:tcW')
              ?.getAttribute('w:w');
          totalGridTwips += double.tryParse(w ?? '0') ?? 0;
        }
      }
    }

    if (totalGridTwips == 0) totalGridTwips = 1;

    // 3. Convert Twips to Pixels (Standard Word scaling)
    // using custom factor: 0.0667
    double naturalWidthPx = totalGridTwips * 0.0667;

    // 4. Determine Scale Factor and Final Width
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

    // Generate Rows
    List<Widget> rowWidgets = getRowsWList(scaleFactor, gridColWidths);

    return Container(
      width: screenWidth, // Container takes full width to allow centering
      alignment:
          Alignment.center, // Center the table if it's smaller than screen
      child: Container(
        width: finalTableWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
      ),
    );
  }

  List<double> _getGridColWidths() {
    var gridCols = tblXml
        .findAllElements('w:tblGrid')
        .firstOrNull
        ?.findAllElements('w:gridCol');
    if (gridCols != null && gridCols.isNotEmpty) {
      return gridCols
          .map((c) => double.tryParse(c.getAttribute('w:w') ?? '0') ?? 0)
          .toList();
    }
    return [];
  }

  int _getGridSpan(XmlElement cell) {
    var gridSpan = cell.getElement('w:tcPr')?.getElement('w:gridSpan');
    return int.tryParse(gridSpan?.getAttribute('w:val') ?? '1') ?? 1;
  }

  double? _getRowHeightTwips(XmlElement row) {
    var trPr = row.getElement('w:trPr');
    if (trPr == null) return null;

    var trHeight = trPr.getElement('w:trHeight');
    if (trHeight == null) return null;

    String? heightVal = trHeight.getAttribute('w:val');
    if (heightVal == null) return null;

    return double.tryParse(heightVal);
  }

  List<Widget> getRowsWList(double scaleFactor, List<double> gridColWidths) {
    List<XmlElement> rows = tblXml.childElements
        .where((n) => n.name.local == 'tr')
        .toList();

    List<Widget> rowsW = [];

    for (var row in rows) {
      List<XmlElement> rowCells = row.childElements
          .where((n) => n.name.local == 'tc')
          .toList();
      List<Widget> cellsW = [];
      int gridColIndex = 0;

      for (var cell in rowCells) {
        double cellTwips = 0;
        int span = _getGridSpan(cell);

        // 1. Try explicit width from w:tcW
        var tcW = cell.getElement('w:tcPr')?.getElement('w:tcW');
        double explicitW =
            double.tryParse(tcW?.getAttribute('w:w') ?? '0') ?? 0;
        String type = tcW?.getAttribute('w:type') ?? 'auto';

        // Word logic: if type is NOT auto, or if it is auto but has a value > 0 and no grid?
        // Usually if grid exists, we prefer grid for 'auto' or '0' widths.
        if (explicitW > 0 && type != 'auto') {
          cellTwips = explicitW;
        } else {
          // 2. Fallback to Grid Width
          if (gridColWidths.isNotEmpty) {
            for (int i = 0; i < span; i++) {
              if (gridColIndex + i < gridColWidths.length) {
                cellTwips += gridColWidths[gridColIndex + i];
              }
            }
          } else {
            // Backup backup: use explicit even if 0 (will trigger 10px min later)
            cellTwips = explicitW;
          }
        }

        // Advance grid index
        gridColIndex += span;

        // Calculate pixels
        double cellWidthPx = cellTwips * scaleFactor;

        cellsW.add(getCellWidget(cell, cellWidthPx));
      }

      double? rowHeightTwips = _getRowHeightTwips(row);
      double? rowHeightPx = rowHeightTwips != null
          ? rowHeightTwips * 0.0667
          : null;

      Widget rowWidget = Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cellsW,
      );

      if (rowHeightPx != null && rowHeightPx > 0) {
        rowsW.add(
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowHeightPx),
            child: rowWidget,
          ),
        );
      } else {
        rowsW.add(rowWidget);
      }
    }
    return rowsW;
  }

  Widget getCellWidget(XmlElement rowCell, double cellWidthPx) {
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

      // Skip fully empty paragraphs (no text, no br)
      if ((paragraph.text.trim().isEmpty) &&
          paragraph.runs.every(
            (r) =>
                (r.text ?? "").trim().isEmpty &&
                r.hasBrBefore == false &&
                r.hasBrAfter == false,
          )) {
        continue;
      }

      // Fix Helper Alignments
      if (paragraph.textAlign == TextAlign.justify) {
        paragraph.textAlign = TextAlign.center;
      }
      if (paragraph.textDirection != TextDirection.rtl) {
        paragraph.textDirection = TextDirection.rtl;
      }

      pWidgets.add(
        DefaultTextStyle.merge(
          style: const TextStyle(height: 0.9),
          child: paragraph.toWidget(),
        ),
      );
    }

    return Container(
      width: cellWidthPx,
      padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pWidgets,
      ),
    );
  }
}
