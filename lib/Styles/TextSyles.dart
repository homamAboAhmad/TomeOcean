import 'package:flutter/material.dart';

import 'AppResourses.dart';

TextStyle normalStyle(
    {color = Colors.black,
    double fontSize = 16,
    fontWeight = FontWeight.w700,
    fontFamily = appFont}) {
  return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight);
}

TextStyle bigStyle(
    {color = Colors.black,
    double fontSize = 24,
    fontWeight = FontWeight.w700,
    fontFamily = appFont}) {
  return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight);
}

TextStyle mediumStyle(
    {color = Colors.black,
    double fontSize = 20,
    fontWeight = FontWeight.w700,
    fontFamily = appFont}) {
  return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight);
}

TextStyle smallStyle(
    {color = Colors.black,
    double fontSize = 12,
    fontWeight = FontWeight.w700,
    fontFamily = appFont}) {
  return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight);
}