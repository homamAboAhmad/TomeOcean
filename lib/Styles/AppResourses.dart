import 'package:flutter/material.dart';

// Organic Biophilic UI palette from ui-ux-pro-max.
const Color primaryColor = Color(0xFF0891B2);
const Color secondaryColor = Color(0xFF22D3EE);
const Color bgColor = Color(0xFFECFEFF);
const Color accentColor = Color(0xFF164E63);
const Color surfaceColor = Color(0xFFFFFFFF);
const Color actionColor = Color(0xFF059669);
const Color mutedColor = Color(0xFFE8F1F6);
const Color borderColor = Color(0xFFA5F3FC);
const Color destructiveColor = Color(0xFFDC2626);
const Color organicHighlightColor = Color(0xFFD7FAF4);
const Color organicHoverColor = Color(0xFFE0F7FB);

// Use local font that exists in the project
const String appFont = 'jreg';
const double iconSize = 22;

abstract final class AppChrome {
  static const double radiusSmall = 10;
  static const double radius = 16;
  static const double radiusLarge = 22;

  static BorderSide borderSide({double opacity = 1}) {
    return BorderSide(color: borderColor.withOpacity(opacity));
  }

  static BoxDecoration surfaceDecoration({
    Color color = surfaceColor,
    double radius = AppChrome.radius,
    bool shadow = true,
    Color? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? borderColor.withOpacity(0.75)),
      boxShadow: shadow ? softShadow : null,
    );
  }

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primaryColor.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get topShadow => [
        BoxShadow(
          color: accentColor.withOpacity(0.12),
          blurRadius: 18,
          offset: const Offset(0, 2),
        ),
      ];

  static LinearGradient get headerGradient => const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [primaryColor, secondaryColor],
      );
}
