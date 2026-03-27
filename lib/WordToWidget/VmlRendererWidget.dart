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
    debugPrint("VmlRendererWidget: Starting build");
    debugPrint(
      "VmlRendererWidget: vmlShapeData=${imageData.vmlShapeData?.shapeType}, width=${imageData.width}, height=${imageData.height}",
    );

    if (imageData.vmlShapeData == null) {
      debugPrint(
        "VmlRendererWidget: vmlShapeData is null, returning SizedBox.shrink()",
      );
      return const SizedBox.shrink();
    }

    final vml = imageData.vmlShapeData!;
    Widget contentWidget = const SizedBox.shrink();

    debugPrint(
      "VmlRendererWidget: textBoxElement=${vml.textBoxElement != null ? 'exists' : 'null'}",
    );

    if (vml.textBoxElement != null) {
      // استخراج قيمة inset من v:textbox إن وجدت، أو استخدام قيمة افتراضية
      // inset format: "top,left,bottom,right" أو "top,left,bottom,right" مثل "2.5mm,0,,0"
      double paddingInset = 2.5; // القيمة الافتراضية من XML (2.5mm)

      contentWidget = Padding(
        padding: EdgeInsets.all(paddingInset), // تطبيق الإزاحة من كل الجهات
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
        shapeWidget = SizedBox(width: imageData.width, child: contentWidget);
    }

    debugPrint(
      "VmlRendererWidget: Final shapeWidget - type=${vml.shapeType}, returning widget",
    );
    return shapeWidget;
  }
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
