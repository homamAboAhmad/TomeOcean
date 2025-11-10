
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
