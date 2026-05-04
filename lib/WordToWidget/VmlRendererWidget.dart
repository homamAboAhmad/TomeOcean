import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/VmlShapeData.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/WordToWidget/VmlDiamondShapeWidget.dart';
import 'package:golden_shamela/WordToWidget/RichTextBoxWidget.dart';
import 'package:golden_shamela/WordToWidget/VmlShapeFillResolver.dart';
import 'package:golden_shamela/WordToWidget/VmlLinePainter.dart';
import 'package:golden_shamela/WordToWidget/VmlTextBoxInsetResolver.dart';

/// ودجت مسؤول عن تجميع ورسم أشكال VML المختلفة مع النص الغني بداخلها.
///
/// يدعم الأشكال التالية:
/// - `roundrect` / `rect`: مستطيل عادي أو بزوايا دائرية
/// - `diamond`: شكل معيّن (يُفوَّض إلى `VmlDiamondShapeWidget`)
/// - `line`: خط مستقيم (يُفوَّض الرسم إلى `VmlLinePainter`)
/// - أي شكل آخر: حاوية بسيطة مع خلفية وحدود
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

    // محتوى صورة إن وُجدت وليس هناك textbox
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

    // محتوى نصي غني إن وُجد textbox
    if (vml.textBoxElement != null) {
      contentWidget = Padding(
        padding: VmlTextBoxInsetResolver.resolve(vml.textBoxInset),
        child: RichTextBoxWidget(
          textBoxElement: vml.textBoxElement!,
          wordPage: wordPage,
          customPageNumber: imageData.parent?.parent.customPageNumber,
          textBoxFillColor: vml.fillColor,
        ),
      );
    }

    // بناء الشكل المراد رسمه (خلفية وحدود)
    final fillDecoration = _buildShapeFillDecoration(vml, imageData);
    final borderDecoration = _buildShapeBorderDecoration(vml);
    Widget shapeWidget;
    switch (vml.shapeType.toLowerCase()) {
      case 'roundrect':
      case 'rect':
        BorderRadius? borderRadius;
        if (vml.shapeType.toLowerCase() == 'roundrect') {
          final double minDim = imageData.width < imageData.height
              ? imageData.width
              : imageData.height;
          borderRadius = BorderRadius.circular(minDim * vml.arcSize);
        }

        shapeWidget = Container(
          width: imageData.width > 0 ? imageData.width : null,
          height: imageData.height > 0 ? imageData.height : null,
          decoration: fillDecoration?.copyWith(borderRadius: borderRadius),
          foregroundDecoration: borderDecoration?.copyWith(
            borderRadius: borderRadius,
          ),
          clipBehavior:
              (fillDecoration != null || borderDecoration != null)
              ? Clip.hardEdge
              : Clip.none,
          child: contentWidget,
        );
        break;

      case 'diamond':
        shapeWidget = VmlDiamondShapeWidget(
          width: imageData.width,
          height: imageData.height,
          fillColor: VmlShapeFillResolver.resolveFillColor(
            vml: vml,
            imageData: imageData,
          ),
          fillStyle: vml.fillStyle,
          strokeColor: vml.isStroked ? vml.strokeColor : null,
          strokeWidth: vml.strokeWidth,
          shadowStyle: vml.shadowStyle,
          child: contentWidget,
        );
        break;

      case 'line':
        shapeWidget = SizedBox(
          width: imageData.width,
          height: imageData.height < 2
              ? 8.0
              : imageData.height,
          child: CustomPaint(
            painter: VmlLinePainter(
              color: vml.strokeColor ?? Colors.black,
              strokeWidth: vml.strokeWidth,
              dashStyle: vml.strokeDashStyle,
              endCap: vml.strokeEndCap,
            ),
            child: contentWidget,
          ),
        );
        break;

      default:
        shapeWidget = Container(
          width: imageData.width > 0 ? imageData.width : null,
          height: imageData.height > 0 ? imageData.height : null,
          decoration: fillDecoration,
          foregroundDecoration: borderDecoration,
          child: contentWidget,
        );
    }

    return shapeWidget;
  }
}

/// بناء زخرفة الخلفية للشكل
BoxDecoration? _buildShapeFillDecoration(VmlShapeData vml, ImageData imageData) {
  final color = VmlShapeFillResolver.resolveFillColor(
    vml: vml,
    imageData: imageData,
  );
  if (color == null) return null;
  return BoxDecoration(color: color);
}

/// بناء زخرفة الحدود للشكل
BoxDecoration? _buildShapeBorderDecoration(VmlShapeData vml) {
  final border = vml.isStroked && vml.strokeColor != null
      ? Border.all(color: vml.strokeColor!, width: vml.strokeWidth)
      : null;
  if (border == null) return null;
  return BoxDecoration(border: border);
}
