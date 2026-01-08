import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'AppResourses.dart';

TextStyle normalStyle({
  Color color = Colors.black87,
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w600,
  double height = 1.6,
}) {
  return GoogleFonts.amiri(
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
  return GoogleFonts.amiri(
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
  return GoogleFonts.amiri(
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
  return GoogleFonts.amiri(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}
