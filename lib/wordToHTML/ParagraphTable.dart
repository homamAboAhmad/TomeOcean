import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/XmlElementUtils.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/DocumentStyles.dart';

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

  /// Gets row height info: (heightTwips, hRule)
  /// hRule: 'exact', 'atLeast', or 'auto'
  (double?, String) _getRowHeightInfo(XmlElement row) {
    var trPr = row.getElement('w:trPr');
    if (trPr == null) return (null, 'auto');

    var trHeight = trPr.getElement('w:trHeight');
    if (trHeight == null) return (null, 'auto');

    String? heightVal = trHeight.getAttribute('w:val');
    String hRule = trHeight.getAttribute('w:hRule') ?? 'atLeast';

    if (heightVal == null) return (null, 'auto');

    return (double.tryParse(heightVal), hRule);
  }

  List<Widget> getRowsWList(double scaleFactor, List<double> gridColWidths) {
    List<XmlElement> rows = tblXml.childElements
        .where((n) => n.name.local == 'tr')
        .toList();

    List<Widget> rowsW = [];
    int totalRows = rows.length;

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      var row = rows[rowIndex];
      List<XmlElement> rowCells = row.childElements
          .where((n) => n.name.local == 'tc')
          .toList();
      List<Widget> cellsW = [];
      int gridColIndex = 0;
      int totalCols = rowCells.length;

      for (int colIndex = 0; colIndex < rowCells.length; colIndex++) {
        var cell = rowCells[colIndex];
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

        cellsW.add(
          getCellWidget(
            cell,
            cellWidthPx,
            rowIndex: rowIndex,
            colIndex: colIndex,
            totalRows: totalRows,
            totalCols: totalCols,
          ),
        );
      }

      // Get row height info
      var (rowHeightTwips, hRule) = _getRowHeightInfo(row);
      double? rowHeightPx = rowHeightTwips != null
          ? rowHeightTwips * 0.0667
          : null;

      // Use IntrinsicHeight to make all cells in a row the same height
      // CrossAxisAlignment.stretch makes cells expand to fill row height
      Widget rowWidget = IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cellsW,
        ),
      );

      // Apply row height constraints based on hRule
      if (rowHeightPx != null && rowHeightPx > 0) {
        if (hRule == 'exact') {
          // Exact height: fixed, content may be clipped
          rowsW.add(SizedBox(height: rowHeightPx, child: rowWidget));
        } else {
          // atLeast or default: minimum height, can grow
          rowsW.add(
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: rowHeightPx),
              child: rowWidget,
            ),
          );
        }
      } else {
        rowsW.add(rowWidget);
      }
    }
    return rowsW;
  }

  Widget getCellWidget(
    XmlElement rowCell,
    double cellWidthPx, {
    int rowIndex = 0,
    int colIndex = 0,
    int totalRows = 1,
    int totalCols = 1,
  }) {
    if (cellWidthPx <= 0) cellWidthPx = 10; // Minimal width fallback

    // --- Cell Decoration (Borders & Background) ---
    // This is purely visual and should not affect layout
    BoxDecoration? decoration = _getCellDecoration(
      rowCell,
      rowIndex: rowIndex,
      colIndex: colIndex,
      totalRows: totalRows,
      totalCols: totalCols,
    );

    // --- Cell Text Direction ---
    // Check for vertical text direction in the cell
    String? cellTextDirection = _getCellTextDirection(rowCell);
    bool isVerticalText =
        cellTextDirection != null &&
        (cellTextDirection == 'tbRl' ||
            cellTextDirection == 'tbRlV' ||
            cellTextDirection == 'btLr' ||
            cellTextDirection == 'tbLrV');

    var paragraphsXml = rowCell.findAllElements("w:p");

    if (paragraphsXml.isEmpty)
      return Container(
        width: cellWidthPx,
        decoration: decoration,
        constraints: BoxConstraints(minHeight: 20),
      );

    List<Widget> pWidgets = [];
    for (var pXml in paragraphsXml) {
      // Skip numbering counter for table cells to prevent counter increment on re-renders
      Paragraph paragraph = Paragraph(
        parent,
      ).fromXml(pXml, skipNumberingCounter: true);

      // For table cells with numbering, set paragraphNumber based on row index (1-based)
      // This ensures correct sequential numbering (1, 2, 3...) for table rows
      if (paragraph.pPr?.numId != null &&
          paragraph.pPr?.paragraphNumber == null) {
        paragraph.pPr!.paragraphNumber = rowIndex + 1;
      }

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

      // IMPORTANT: Reset numbering indentation for table cells
      // Word behavior: When a ListParagraph is inside a table cell,
      // indentation is applied RELATIVE to the cell boundaries, not the page.
      // The paragraph indentation values (from numbering levels) are designed
      // for full-page paragraphs. Inside narrow table cells, this causes
      // text wrapping. The cell itself provides the container boundaries.
      if (paragraph.pPr != null) {
        paragraph.pPr!.paddingLeft = 0;
        paragraph.pPr!.paddingRight = 0;
      }

      pWidgets.add(
        DefaultTextStyle.merge(
          style: const TextStyle(height: 0.9),
          child: paragraph.toWidget(),
        ),
      );
    }

    Widget cellContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pWidgets,
    );

    // Apply rotation for vertical text direction
    if (isVerticalText) {
      // tbRl = Top to Bottom, Right to Left (rotate 90 degrees clockwise)
      // btLr = Bottom to Top, Left to Right (rotate 90 degrees counter-clockwise)
      int quarterTurns =
          (cellTextDirection == 'btLr' || cellTextDirection == 'tbLrV')
          ? 3 // 270 degrees = -90 degrees
          : 1; // 90 degrees

      cellContent = RotatedBox(quarterTurns: quarterTurns, child: cellContent);
    }

    // --- Cell Vertical Alignment (vAlign) ---
    // Get vertical alignment from tcPr/vAlign
    Alignment verticalAlign = _getCellVerticalAlignment(rowCell);

    return Container(
      width: cellWidthPx,
      decoration: decoration,
      padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0), // UNCHANGED
      child: Align(alignment: verticalAlign, child: cellContent),
    );
  }

  /// Get cell text direction from tcPr/textDirection
  String? _getCellTextDirection(XmlElement cell) {
    var tcPr = cell.getElement('w:tcPr');
    var textDir = tcPr?.getElement('w:textDirection');
    return textDir?.getAttribute('w:val');
  }

  /// Returns Alignment for use in Align widget
  Alignment _getCellVerticalAlignment(XmlElement cell) {
    var tcPr = cell.getElement('w:tcPr');
    var vAlign = tcPr?.getElement('w:vAlign')?.getAttribute('w:val');

    switch (vAlign) {
      case 'top':
        return Alignment.topCenter;
      case 'center':
        return Alignment.center;
      case 'bottom':
        return Alignment.bottomCenter;
      default:
        return Alignment.topCenter; // Default to top
    }
  }

  // --- Helper Methods for Cell Decoration ---

  /// Get the table style ID if one is defined
  String? _getTableStyleId() {
    return tblXml
        .getElement('w:tblPr')
        ?.getElement('w:tblStyle')
        ?.getAttribute('w:val');
  }

  /// Creates BoxDecoration with borders and background color from XML
  BoxDecoration? _getCellDecoration(
    XmlElement cell, {
    int rowIndex = 0,
    int colIndex = 0,
    int totalRows = 1,
    int totalCols = 1,
  }) {
    Color? bgColor = _getCellColor(
      cell,
      rowIndex: rowIndex,
      colIndex: colIndex,
      totalRows: totalRows,
      totalCols: totalCols,
    );
    Border? border = _getCellBorder(cell);

    if (bgColor == null && border == null) return null;

    return BoxDecoration(color: bgColor, border: border);
  }

  /// Parses w:shd to get cell background color
  /// Checks: 1) Direct cell shd, 2) Table style conditional formatting
  Color? _getCellColor(
    XmlElement cell, {
    int rowIndex = 0,
    int colIndex = 0,
    int totalRows = 1,
    int totalCols = 1,
  }) {
    // Priority 1: Direct cell shading
    var tcPr = cell.getElement('w:tcPr');
    var shd = tcPr?.getElement('w:shd');
    if (shd != null) {
      String? fill = shd.getAttribute('w:fill');
      if (fill != null && fill != "auto" && fill.toLowerCase() != "ffffff") {
        return _parseHexColor(fill);
      }
    }

    // Priority 2: Table style conditional formatting
    String? styleId = _getTableStyleId();
    if (styleId != null) {
      // Determine which conditional type applies to this cell
      // Check firstRow, firstCol, lastRow, lastCol in order of priority
      List<String> conditionTypes = [];

      if (rowIndex == 0) conditionTypes.add('firstRow');
      if (rowIndex == totalRows - 1) conditionTypes.add('lastRow');
      if (colIndex == 0)
        conditionTypes.add('firstCol'); // RTL: first column is rightmost
      if (colIndex == totalCols - 1) conditionTypes.add('lastCol');

      // Try each condition type
      for (String condType in conditionTypes) {
        Color? styleColor = _getTableStyleCellShading(styleId, condType);
        if (styleColor != null) return styleColor;
      }

      // Try whole table tcPr shading as fallback
      Color? tableShading = _getTableStyleCellShading(styleId, null);
      if (tableShading != null) return tableShading;
    }

    return null;
  }

  /// Get cell shading from table style conditional formatting
  Color? _getTableStyleCellShading(String styleId, String? conditionType) {
    XmlElement? style = getDocumentStyle(styleId, parent.parent);
    if (style == null) return null;

    XmlElement? tcPr;

    if (conditionType != null) {
      // Look for tblStylePr with matching type
      for (var tblStylePr in style.findAllElements('w:tblStylePr')) {
        if (tblStylePr.getAttribute('w:type') == conditionType) {
          tcPr = tblStylePr.getElement('w:tcPr');
          break;
        }
      }
    } else {
      // Look for tcPr directly in style (whole table default)
      tcPr = style.getElement('w:tcPr');
    }

    if (tcPr == null) return null;

    var shd = tcPr.getElement('w:shd');
    if (shd != null) {
      String? fill = shd.getAttribute('w:fill');
      if (fill != null && fill != "auto" && fill.toLowerCase() != "ffffff") {
        return _parseHexColor(fill);
      }
    }

    return null;
  }

  /// Parses hex color string
  Color? _parseHexColor(String hex) {
    if (hex == "auto" || hex.toLowerCase() == "none") return null;
    try {
      hex = hex.replaceAll("#", "");
      if (hex.length == 6) {
        return Color(int.parse("0xFF$hex"));
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Parses cell borders from tcBorders, tblBorders, or table style
  Border? _getCellBorder(XmlElement cell) {
    var tcPr = cell.getElement('w:tcPr');
    var tcBorders = tcPr?.getElement('w:tcBorders');

    // Check table-level borders as fallback
    var tblPr = tblXml.getElement('w:tblPr');
    var tblBorders = tblPr?.getElement('w:tblBorders');

    // Priority 3: Get borders from table style (e.g., "PlainTable11", "TableGrid")
    XmlElement? styleBorders;
    if (tblBorders == null) {
      var tblStyleId = tblPr?.getElement('w:tblStyle')?.getAttribute('w:val');
      if (tblStyleId != null) {
        styleBorders = getTableStyleBorders(tblStyleId, parent.parent);
      }
    }

    BorderSide? getSide(String sideName) {
      XmlElement? borderEl;

      // Priority 1: Cell-level border
      if (tcBorders != null) {
        borderEl = tcBorders.getElement('w:$sideName');
      }

      // Priority 2: Table-level border (direct in document.xml)
      if (borderEl == null && tblBorders != null) {
        // Simple mapping: use table's insideH for top/bottom, insideV for left/right
        if (sideName == 'top' || sideName == 'bottom') {
          borderEl =
              tblBorders.getElement('w:insideH') ??
              tblBorders.getElement('w:$sideName');
        } else {
          borderEl =
              tblBorders.getElement('w:insideV') ??
              tblBorders.getElement('w:$sideName');
        }
      }

      // Priority 3: Table style borders (from styles.xml)
      if (borderEl == null && styleBorders != null) {
        if (sideName == 'top' || sideName == 'bottom') {
          borderEl =
              styleBorders.getElement('w:insideH') ??
              styleBorders.getElement('w:$sideName');
        } else {
          borderEl =
              styleBorders.getElement('w:insideV') ??
              styleBorders.getElement('w:$sideName');
        }
      }

      if (borderEl == null) return null;

      String val = borderEl.getAttribute('w:val') ?? 'none';
      if (val == 'none' || val == 'nil') return null;

      // Parse color
      String? colorHex = borderEl.getAttribute('w:color');
      Color color = Colors.black;
      if (colorHex != null && colorHex != "auto") {
        color = _parseHexColor(colorHex) ?? Colors.black;
      }

      // Parse width (w:sz is in 1/8 points)
      String? sz = borderEl.getAttribute('w:sz');
      double width = 0.5; // Thin default
      if (sz != null) {
        double? eighthPts = double.tryParse(sz);
        if (eighthPts != null) {
          // 1/8 point -> pixels: (sz/8) * 1.33
          width = (eighthPts / 8.0) * 1.33;
          if (width < 0.5) width = 0.5;
          if (width > 3.0) width = 3.0; // Cap to prevent oversized borders
        }
      }

      return BorderSide(color: color, width: width);
    }

    BorderSide top = getSide('top') ?? BorderSide.none;
    BorderSide bottom = getSide('bottom') ?? BorderSide.none;
    BorderSide left = getSide('left') ?? BorderSide.none;
    BorderSide right = getSide('right') ?? BorderSide.none;

    // If all sides are none, return null (no border)
    if (top == BorderSide.none &&
        bottom == BorderSide.none &&
        left == BorderSide.none &&
        right == BorderSide.none) {
      return null;
    }

    return Border(top: top, bottom: bottom, left: left, right: right);
  }
}
