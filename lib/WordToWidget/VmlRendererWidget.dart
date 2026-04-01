import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/VmlShapeData.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/WordToWidget/RichTextBoxWidget.dart';

/// ودجت مسؤول عن تجميع ورسم أشكال VML المختلفة مع النص الغني بداخلها
class VmlRendererWidget extends StatelessWidget {
  final ImageData imageData;
  final WordPage wordPage;

  const VmlRendererWidget({
    Key? key,
    required this.imageData,
    required this.wordPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageData.vmlShapeData == null) {
      return const SizedBox.shrink();
    }

    final vml = imageData.vmlShapeData!;
    Widget contentWidget = const SizedBox.shrink();

    if (imageData.imageMemory != null &&
        imageData.imageMemory!.isNotEmpty &&
        vml.textBoxElement == null) {
      contentWidget = Image.memory(
        imageData.imageMemory!,
        width: imageData.width > 0 ? imageData.width : null,
        height: imageData.height > 0 ? imageData.height : null,
        fit: imageData.isStretched ? BoxFit.fill : BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    if (vml.textBoxElement != null) {
      contentWidget = Padding(
        padding: _resolveTextBoxPadding(vml),
        child: RichTextBoxWidget(
          textBoxElement: vml.textBoxElement!,
          wordPage: wordPage,
        ),
      );
    }

    // 2. تجميع بناء الشكل المراد رسمه (خلفية وحدود)
    Widget shapeWidget;
    switch (vml.shapeType.toLowerCase()) {
      case 'roundrect':
      case 'rect':
        // بناء صندوق مستطيل أو بحواف دائرية
        BorderRadius? borderRadius;
        if (vml.shapeType.toLowerCase() == 'roundrect') {
          // حساب الزاوية الدائرية (تعتمد على القيمة الكسرية arcSize، الافتراضي 20%)
          final double minDim = imageData.width < imageData.height
              ? imageData.width
              : imageData.height;
          borderRadius = BorderRadius.circular(minDim * vml.arcSize);
        }

        BoxDecoration decor = BoxDecoration(
          color:
              vml.fillColor ??
              Colors
                  .white, // إذا لم يكن هناك fillcolor، استخدم white (كما في الوورد)
          borderRadius: borderRadius,
          border: vml.strokeColor != null
              ? Border.all(color: vml.strokeColor!, width: vml.strokeWidth)
              : null,
        );

        shapeWidget = Container(
          width: imageData.width > 0 ? imageData.width : null,
          height: imageData.height > 0 ? imageData.height : null,
          decoration: decor,
          clipBehavior: Clip.hardEdge,
          child: contentWidget,
        );
        break;

      case 'line':
        // رسم خط يمر من عبر الإحداثيات (بسيط أفقياً أو قطرياً)
        // يتم التعامل معه كخلفية لـ CustomPaint
        shapeWidget = SizedBox(
          width: imageData.width,
          height: imageData.height < 2
              ? 8.0
              : imageData.height, // زيادة الارتفاع ليتسع للخط ظاهرياً
          child: CustomPaint(
            painter: _VmlLinePainter(
              color: vml.strokeColor ?? Colors.black,
              strokeWidth: vml.strokeWidth,
            ),
            child: contentWidget,
          ),
        );
        break;

      default:
        // أشكال أخرى (مسارات معقدة) يمكن إدراجها لاحقاً
        shapeWidget = SizedBox(
          width: imageData.width > 0 ? imageData.width : null,
          height: imageData.height > 0 ? imageData.height : null,
          child: contentWidget,
        );
    }

    return shapeWidget;
  }
}

EdgeInsets _resolveTextBoxPadding(VmlShapeData vml) {
  // Microsoft VML inset order is left, top, right, bottom.
  // Missing values fall back to 0.1in, 0.05in, 0.1in, 0.05in.
  const defaults = ['0.1in', '0.05in', '0.1in', '0.05in'];
  final raw = vml.textBoxInset;
  if (raw == null || raw.trim().isEmpty) {
    return EdgeInsets.fromLTRB(
      _parseInsetUnit(defaults[0]),
      _parseInsetUnit(defaults[1]),
      _parseInsetUnit(defaults[2]),
      _parseInsetUnit(defaults[3]),
    );
  }

  final parts = raw
      .split(RegExp(r'[,\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String valueAt(int index) => index < parts.length ? parts[index] : defaults[index];

  return EdgeInsets.fromLTRB(
    _parseInsetUnit(valueAt(0)),
    _parseInsetUnit(valueAt(1)),
    _parseInsetUnit(valueAt(2)),
    _parseInsetUnit(valueAt(3)),
  );
}

double _parseInsetUnit(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return 0;
  if (normalized.endsWith('pt')) {
    return (double.tryParse(normalized.replaceAll('pt', '')) ?? 0) * 1.333;
  }
  if (normalized.endsWith('px')) {
    return double.tryParse(normalized.replaceAll('px', '')) ?? 0;
  }
  if (normalized.endsWith('in')) {
    return (double.tryParse(normalized.replaceAll('in', '')) ?? 0) * 96.0;
  }
  if (normalized.endsWith('cm')) {
    return (double.tryParse(normalized.replaceAll('cm', '')) ?? 0) * (96.0 / 2.54);
  }
  if (normalized.endsWith('mm')) {
    return (double.tryParse(normalized.replaceAll('mm', '')) ?? 0) * (96.0 / 25.4);
  }
  return double.tryParse(normalized) ?? 0;
}

class _VmlLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _VmlLinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // خط يبدأ من أعلى اليسار إلى أسفل اليمين (بناءً على افتراض الإحداثيات المنظمة)
    // العرض والارتفاع المستخرجين يمثلان حدود الخط
    canvas.drawLine(
      const Offset(0, 0),
      Offset(
        size.width,
        size.height == 8.0 ? 0 : size.height,
      ), // إذا كان 8.0 يعني خط أفقي صِرف
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
