import 'package:flutter/material.dart';
import 'AppResourses.dart';

const String appUiFont = 'IBMPlexSansArabic';

abstract final class AppTypography {
  static String? _fontFamilyOverride;

  static String? get fontFamilyOverride => _fontFamilyOverride;

  static void useFontFamily(String? fontFamily) {
    final next = fontFamily?.trim();
    _fontFamilyOverride = next == null || next.isEmpty ? null : next;
  }

  static TextTheme textTheme(TextTheme base) {
    final override = _fontFamilyOverride;
    if (override != null) return base.apply(fontFamily: override);
    return base.apply(fontFamily: appUiFont);
  }

  static TextStyle style({
    Color color = Colors.black87,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    double height = 1.6,
  }) {
    final override = _fontFamilyOverride;
    if (override != null) {
      return TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        fontFamily: override,
      );
    }
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontFamily: appUiFont,
    );
  }
}

TextStyle normalStyle({
  Color color = Colors.black87,
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w600,
  double height = 1.6,
}) {
  return AppTypography.style(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}

TextStyle bigStyle({
  Color color = primaryColor,
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.bold,
  double height = 1.4,
}) {
  return AppTypography.style(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}

TextStyle mediumStyle({
  Color color = Colors.black87,
  double fontSize = 18,
  FontWeight fontWeight = FontWeight.w700,
  double height = 1.5,
}) {
  return AppTypography.style(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}

TextStyle smallStyle({
  Color color = Colors.black54,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w600,
  double height = 1.4,
}) {
  return AppTypography.style(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}
