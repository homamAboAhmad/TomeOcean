import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/Models/WordDocument.dart';

getImageWidget(ImageData? imageData) {
  if (imageData == null)
    return Container(
      child: Text("Empty Pic"),
    );
  WordDocument? wordDocument  = imageData.parent?.parent?.parent?.parent;
  ImageData image = imageData;

  // print("fromPage ${image.relativeFromH} ${image.relativeFromV} ${image.posY}");
  double posX = 0;
  double posY = 0;

  if(image.relativeFromH=="page"){
     posX = image.posX ;
  }else{
    posX = image.posX + (wordDocument?.getPageSectPr().leftMargin??0);
  }
  if(image.relativeFromV=="page"||image.relativeFromV=="paragraph"){
     posY = image.posY ;
  }else{
    posY = image.posY + (wordDocument?.getPageSectPr().topMargin??0);
  }





  double left = posX > 0 ? posX : 0;
  double top = posY > 0 ? posY : 0;
  if(image.alignH=="center") left =0;
  if(image.alingV =="center") top=0;
  // if(image.relativeFromV=="paragraph"){
  //   print("from paragraph ${image.alingV} ${image.posY}"+top.toString());
  // }

  print("image ${image.rId} $left $top ${image.relativeFromH} ${image.relativeFromV}");
  return Align(
    alignment: getImageALign(image),
    child: Container(
      padding: EdgeInsets.only(
          left: left,
          top: top,
          right: 0,
          bottom: 0),
      child: Image.memory(
        image.imageMemory,
        width: image.width,
        height: image.height,
        fit: BoxFit.contain,
      ),
    ),
  );
}

getImageALign(ImageData image) {
  // print("image ALign: ${image.alignH} - ${image.alingV}");
  if (image.alignH == "left") {
    if (image.alingV == "top")
      return Alignment.topLeft;
    else if (image.alingV == "center")
      return Alignment.centerLeft;
    else if (image.alingV == "bottom") return Alignment.bottomLeft;
  } else if (image.alignH == "center") {
    if (image.alingV == "top")
      return Alignment.topCenter;
    else if (image.alingV == "center")
      return Alignment.center;
    else if (image.alingV == "bottom") return Alignment.bottomCenter;
  } else if (image.alignH == "right") {
    if (image.alingV == "top")
      return Alignment.topRight;
    else if (image.alingV == "center")
      return Alignment.centerRight;
    else if (image.alingV == "bottom") return Alignment.bottomRight;
  } else if (image.relativeFromH == "column") return Alignment.center;
}
