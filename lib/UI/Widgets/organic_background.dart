import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';

class OrganicBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const OrganicBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _OrganicBackgroundPainter(),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _OrganicBackgroundPainter extends CustomPainter {
  const _OrganicBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topPaint = Paint()
      ..color = secondaryColor.withOpacity(0.16)
      ..style = PaintingStyle.fill;
    final greenPaint = Paint()
      ..color = actionColor.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final topPath = Path()
      ..moveTo(size.width * 0.58, 0)
      ..cubicTo(size.width * 0.78, size.height * 0.05, size.width * 0.82,
          size.height * 0.22, size.width, size.height * 0.18)
      ..lineTo(size.width, 0)
      ..close();

    final bottomPath = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(size.width * 0.18, size.height * 0.64, size.width * 0.28,
          size.height * 0.92, size.width * 0.48, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(topPath, topPaint);
    canvas.drawPath(bottomPath, greenPaint);

    final linePath = Path()
      ..moveTo(size.width * 0.04, size.height * 0.16)
      ..cubicTo(size.width * 0.18, size.height * 0.07, size.width * 0.26,
          size.height * 0.23, size.width * 0.42, size.height * 0.12);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
