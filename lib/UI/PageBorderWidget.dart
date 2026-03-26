import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

class PageBorderSpec {
  final String offsetFrom;
  final PageBorderSide? top;
  final PageBorderSide? bottom;
  final PageBorderSide? left;
  final PageBorderSide? right;

  PageBorderSpec({
    required this.offsetFrom,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  String toString() => 'Spec($offsetFrom, T:$top, B:$bottom, L:$left, R:$right)';

  static PageBorderSpec? fromXml(XmlElement sectPr) {
    final pgBorders = sectPr.findElements('w:pgBorders').firstOrNull;
    if (pgBorders == null) return null;

    final offsetFrom = pgBorders.getAttribute('w:offsetFrom') ?? 'page';

    PageBorderSide? parseSide(String name) {
      final side = pgBorders.findElements('w:$name').firstOrNull;
      if (side == null) return null;

      final style = side.getAttribute('w:val') ?? 'single';
      final sz = double.tryParse(side.getAttribute('w:sz') ?? '4') ?? 4;
      final space = double.tryParse(side.getAttribute('w:space') ?? '0') ?? 0;
      final colorStr = side.getAttribute('w:color') ?? '000000';

      return PageBorderSide(
        style: style,
        width: (sz / 8.0) * 1.333, // Pt to Px approx (96 DPI)
        space: space,
        color: _parseColor(colorStr),
      );
    }

    return PageBorderSpec(
      offsetFrom: offsetFrom,
      top: parseSide('top'),
      bottom: parseSide('bottom'),
      left: parseSide('left'),
      right: parseSide('right'),
    );
  }

  static Color _parseColor(String colorStr) {
    if (colorStr == 'auto') return Colors.black;
    try {
      return Color(int.parse('0xFF${colorStr.replaceAll('#', '')}'));
    } catch (_) {
      return Colors.black;
    }
  }
}

class PageBorderSide {
  final String style;
  final double width;
  final double space;
  final Color color;

  PageBorderSide({
    required this.style,
    required this.width,
    required this.space,
    required this.color,
  });

  @override
  String toString() => '$style|W:$width|S:$space|C:$color';
}

class PageBorderPainter extends CustomPainter {
  final PageBorderSpec borders;
  final double pageWidth;
  final double pageHeight;

  PageBorderPainter({
    required this.borders,
    required this.pageWidth,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double ptToPx = 1.333;
    
    _drawBorders(canvas, size, ptToPx);
  }

  void _drawBorders(Canvas canvas, Size size, double ptToPx) {
    // نأخذ خصائص أحد الجوانب كمرجع (غالباً ما تكون متطابقة في إطارات الصفحات)
    final topSide = borders.top;
    if (topSide == null) return;

    final double baseWidth = topSide.width;
    final double space = topSide.space * ptToPx;
    final List<double> ratios = _getStyleRatios(topSide.style);
    
    // معامل بصري مرتفع (3.0) لضمان حدة الخطوط ووضوح الفراغات الشاسعة
    double visualScale = 3.0; 
    double totalW = baseWidth * visualScale;

    final paint = Paint()
      ..color = topSide.color
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    double currentInward = space; 
    for (int i = 0; i < ratios.length; i++) {
      double segmentW = ratios[i] * totalW;
      
      if (i % 2 == 0) { // Line segment (Outer, Middle, Inner)
        double distFromEdge = currentInward + (segmentW / 2);
        
        // رسم مستطيل متصل بدلاً من 4 خطوط منفصلة للحصول على زوايا نظيفة
        Rect edgeRect = Rect.fromLTRB(
          distFromEdge, 
          distFromEdge, 
          size.width - distFromEdge, 
          size.height - distFromEdge
        );
        
        canvas.drawRect(edgeRect, paint..strokeWidth = segmentW);
      }
      currentInward += segmentW;
    }
  }

  List<double> _getStyleRatios(String style) {
    String s = style.toLowerCase();
    // نسبة موزونة بدقة 1:4.5:2:4.5:1 (فراغات شاسعة 69%، وخط أوسط بوزن 15%)
    if (s.contains('thinthickthinlargegap')) return [0.077, 0.346, 0.154, 0.346, 0.077];
    if (s.contains('thinthickthinmediumgap')) return [0.1, 0.2, 0.4, 0.2, 0.1];
    if (s.contains('thinthickthinsmallgap')) return [0.1, 0.1, 0.6, 0.1, 0.1];
    
    if (s.contains('double')) return [0.33, 0.34, 0.33];
    return [1.0];
  }

  @override
  bool shouldRepaint(covariant PageBorderPainter oldDelegate) {
    return oldDelegate.borders.toString() != borders.toString() ||
           oldDelegate.pageWidth != pageWidth ||
           oldDelegate.pageHeight != pageHeight;
  }
}
