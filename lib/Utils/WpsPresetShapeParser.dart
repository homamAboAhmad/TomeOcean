import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/VmlShapeData.dart';
import 'package:xml/xml.dart' as xml;

/// يحول subset محافظ من wps:wsp + a:prstGeom إلى VmlShapeData قابلة للرسم.
/// هذا مخصص للأشكال DrawingML preset التي لا تحمل blip image data.
class WpsPresetShapeParser {
  static VmlShapeData? tryParse(xml.XmlElement wspElement) {
    final spPr = wspElement.findAllElements('wps:spPr').firstOrNull;
    if (spPr == null) return null;

    final prstGeom = spPr.findAllElements('a:prstGeom').firstOrNull;
    final prst = prstGeom?.getAttribute('prst')?.trim();
    if (prst == null || prst.isEmpty) return null;

    final shapeType = _mapPresetShapeType(prst);
    if (shapeType == null) return null;

    final shape = VmlShapeData(shapeType: shapeType);

    final solidFill = spPr.findAllElements('a:solidFill').firstOrNull;
    final noFill = spPr.findAllElements('a:noFill').isNotEmpty;
    if (solidFill != null) {
      shape.fillColor = _parseDrawingColor(solidFill);
    } else if (noFill) {
      shape.isFilled = false;
    }

    final line = spPr.findAllElements('a:ln').firstOrNull;
    if (line != null) {
      final lineNoFill = line.findAllElements('a:noFill').isNotEmpty;
      if (lineNoFill) {
        shape.isStroked = false;
      } else {
        final lineFill = line.findAllElements('a:solidFill').firstOrNull;
        if (lineFill != null) {
          shape.strokeColor = _parseDrawingColor(lineFill);
        }
        final widthAttr = line.getAttribute('w');
        if (widthAttr != null) {
          final widthEmu = double.tryParse(widthAttr) ?? 0;
          if (widthEmu > 0) {
            shape.strokeWidth = widthEmu / 9525.0;
          }
        }
      }
    }

    return shape;
  }

  static String? _mapPresetShapeType(String prst) {
    switch (prst) {
      case 'rect':
        return 'rect';
      case 'roundRect':
        return 'roundrect';
      case 'diamond':
        return 'diamond';
      case 'ellipse':
        return 'oval';
    }
    return null;
  }

  static Color? _parseDrawingColor(xml.XmlElement solidFill) {
    final srgbClr = solidFill.findAllElements('a:srgbClr').firstOrNull;
    if (srgbClr != null) {
      final val = srgbClr.getAttribute('val');
      if (val != null && val.length == 6) {
        try {
          return Color(int.parse('FF$val', radix: 16));
        } catch (_) {}
      }
    }

    final schemeClr = solidFill.findAllElements('a:schemeClr').firstOrNull;
    final schemeVal = schemeClr?.getAttribute('val');
    if (schemeVal == 'bg1' || schemeVal == 'lt1') {
      return Colors.white;
    }
    if (schemeVal == 'tx1' || schemeVal == 'dk1') {
      return Colors.black;
    }

    return null;
  }
}
