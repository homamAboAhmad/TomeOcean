


import 'dart:ui';

import 'package:flutter/cupertino.dart';

extension converter on TextAlign {


  Alignment toAlignment(bool? isRtl) {
    TextAlign textAlign = this;
    switch (textAlign) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.justify:
        return isRtl==false? Alignment.centerLeft:Alignment.centerRight; // لا يوجد معادل مباشر للمحاذاة المبررة
      case TextAlign.start:
        return Alignment.centerRight;
      case TextAlign.end:
        return Alignment.centerLeft;

    }
  }
}
