import 'package:flutter/material.dart';
import 'library_design_tokens.dart';

enum LibraryIconType {
  books,
  categories,
  authors,
  star,
  clock,
  bookCard,
  addBook,
  bookRow,
}

class LibraryIcon extends StatelessWidget {
  final LibraryIconType type;
  final double size;
  final Color color;

  const LibraryIcon(
    this.type, {
    super.key,
    this.size = 24,
    this.color = LibraryDesignTokens.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LibraryIconPainter(type: type, color: color),
    );
  }
}

class _LibraryIconPainter extends CustomPainter {
  final LibraryIconType type;
  final Color color;

  const _LibraryIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case LibraryIconType.books:
        _books(canvas, paint);
        break;
      case LibraryIconType.categories:
        _categories(canvas, paint);
        break;
      case LibraryIconType.authors:
        _authors(canvas, paint);
        break;
      case LibraryIconType.star:
        _star(canvas, paint);
        break;
      case LibraryIconType.clock:
        _clock(canvas, paint);
        break;
      case LibraryIconType.bookCard:
        _bookCard(canvas, paint);
        break;
      case LibraryIconType.addBook:
        _addBook(canvas, paint);
        break;
      case LibraryIconType.bookRow:
        _bookRow(canvas, paint);
        break;
    }
  }

  void _books(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(4, 5.5)
        ..quadraticBezierTo(4, 3, 6.5, 3)
        ..lineTo(11, 3)
        ..lineTo(11, 19)
        ..lineTo(6.5, 19)
        ..quadraticBezierTo(4, 19, 4, 21.5)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 5.5)
        ..quadraticBezierTo(20, 3, 17.5, 3)
        ..lineTo(13, 3)
        ..lineTo(13, 19)
        ..lineTo(17.5, 19)
        ..quadraticBezierTo(20, 19, 20, 21.5)
        ..close(),
      paint,
    );
  }

  void _categories(Canvas canvas, Paint paint) {
    for (final rect in const [
      Rect.fromLTWH(5, 3, 5, 5),
      Rect.fromLTWH(14, 3, 5, 5),
      Rect.fromLTWH(5, 12, 5, 5),
      Rect.fromLTWH(14, 12, 5, 5),
    ]) {
      canvas.drawRect(rect, paint);
    }
  }

  void _authors(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(12, 7), 3.2, paint);
    canvas.drawPath(
      Path()
        ..moveTo(5.5, 19)
        ..quadraticBezierTo(6.5, 13, 12, 13)
        ..quadraticBezierTo(17.5, 13, 18.5, 19),
      paint,
    );
    canvas.drawLine(const Offset(4, 5.5), const Offset(7, 5.5), paint);
    canvas.drawLine(const Offset(17, 5.5), const Offset(20, 5.5), paint);
    canvas.drawLine(const Offset(3, 9), const Offset(7, 9), paint);
    canvas.drawLine(const Offset(17, 9), const Offset(21, 9), paint);
  }

  void _bookCard(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 3, 14, 18),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawLine(const Offset(8, 3), const Offset(8, 21), paint);
    canvas.drawLine(const Offset(11, 8), const Offset(16, 8), paint);
    canvas.drawLine(const Offset(11, 12), const Offset(16, 12), paint);
  }

  void _star(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(12, 3)
        ..lineTo(14.8, 8.7)
        ..lineTo(21, 9.6)
        ..lineTo(16.5, 14)
        ..lineTo(17.6, 20.2)
        ..lineTo(12, 17.2)
        ..lineTo(6.4, 20.2)
        ..lineTo(7.5, 14)
        ..lineTo(3, 9.6)
        ..lineTo(9.2, 8.7)
        ..close(),
      paint,
    );
  }

  void _clock(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(12, 12), 9, paint);
    canvas.drawLine(const Offset(12, 7), const Offset(12, 12), paint);
    canvas.drawLine(const Offset(12, 12), const Offset(16, 14), paint);
  }

  void _addBook(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 12, 17),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawLine(const Offset(8, 4), const Offset(8, 21), paint);
    canvas.drawLine(const Offset(18, 9), const Offset(18, 17), paint);
    canvas.drawLine(const Offset(14, 13), const Offset(22, 13), paint);
  }

  void _bookRow(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 3, 14, 18),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.drawLine(const Offset(8.5, 3), const Offset(8.5, 21), paint);
    canvas.drawLine(const Offset(11, 7), const Offset(16, 7), paint);
    canvas.drawLine(const Offset(11, 10), const Offset(16, 10), paint);
  }

  @override
  bool shouldRepaint(covariant _LibraryIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
