import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'dart:typed_data';

getImageWidget(ImageData? imageData) {
  if (imageData == null)
    return Container(
      child: Text("Empty Pic"),
    );
  WordDocument? wordDocument  = imageData.parent?.parent?.parent?.parent;
  ImageData image = imageData;
  
  // NEW: Handle Text Box Content FIRST
  if (image.textBoxText != null && image.textBoxText!.isNotEmpty) {
      Color textColor = Colors.black;
      if (image.textColor != null) {
        try {
          String hex = image.textColor!;
          if (hex.length == 6) {
            hex = "FF" + hex; 
          }
          textColor = Color(int.parse(hex, radix: 16));
        } catch (e) {
          print("Error parsing color: ${image.textColor}");
        }
      }

      double fontSize = (image.textSize ?? 20.0); 
      String? fontFamily = image.fontFamily;

      // Return a simple container with the text. 
      // We do NOT apply absolute positioning offsets (left/top) here because
      // if this is being rendered as an InlineSpan, the offsets will mess up the flow 
      // or be ignored. The caller handles positioning if needed.
      return Container(
          width: image.width > 0 ? image.width : null,
          height: image.height > 0 ? image.height : null,
          child: Center(
              child: Text(
                  image.textBoxText!, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                      color: textColor, 
                      fontSize: fontSize, 
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily
                  )
              )
          )
      );
  }

  // الحصول على أبعاد الصفحة والهوامش
  double pageWidth = wordDocument?.getPageSectPr().width ?? 595;
  double pageHeight = wordDocument?.getPageSectPr().height ?? 842;
  double leftMargin = wordDocument?.getPageSectPr().leftMargin ?? 0;
  double rightMargin = wordDocument?.getPageSectPr().rightMargin ?? 0;
  double topMargin = wordDocument?.getPageSectPr().topMargin ?? 0;
  double bottomMargin = wordDocument?.getPageSectPr().bottomMargin ?? 0;
  
  // حساب منطقة الهامش (margin area)
  double marginAreaWidth = pageWidth - leftMargin - rightMargin;
  double marginAreaHeight = pageHeight - topMargin - bottomMargin;

  double posX = 0;
  double posY = 0;
  
  // التحقق من وجود align حقيقي أو posOffset
  // إذا كان posX != 0 أو posY != 0، فهذا يعني استخدام posOffset
  bool usesHAlign = image.posX == 0 && (image.alignH == "center" || image.alignH == "right");
  bool usesVAlign = image.posY == 0 && (image.alingV == "center" || image.alingV == "bottom");
  
  // حساب الموضع الأفقي
  if (usesHAlign && image.alignH == "center") {
    if (image.relativeFromH == "page") {
      posX = (pageWidth - image.width) / 2;
    } else {
      posX = leftMargin + (marginAreaWidth - image.width) / 2;
    }
  } else if (usesHAlign && image.alignH == "right") {
    if (image.relativeFromH == "page") {
      posX = pageWidth - image.width;
    } else {
      posX = pageWidth - rightMargin - image.width;
    }
  } else {
    // posOffset
    if (image.relativeFromH == "page") {
      posX = image.posX;
    } else {
      posX = image.posX + leftMargin;
    }
  }
  
  // حساب الموضع الرأسي
  if (usesVAlign && image.alingV == "center") {
    if (image.relativeFromV == "page") {
      posY = (pageHeight - image.height) / 2;
    } else {
      posY = topMargin + (marginAreaHeight - image.height) / 2;
    }
  } else if (usesVAlign && image.alingV == "bottom") {
    if (image.relativeFromV == "page") {
      posY = pageHeight - image.height;
    } else {
      posY = pageHeight - bottomMargin - image.height;
    }
  } else {
    // posOffset
    if (image.relativeFromV == "page" || image.relativeFromV == "paragraph") {
      posY = image.posY;
    } else {
      posY = image.posY + topMargin;
    }
  }

  // التأكد من أن القيم غير سالبة لأن EdgeInsets لا يقبل قيم سالبة
  double left = posX > 0 ? posX : 0;
  double top = posY > 0 ? posY : 0;

  if (image.imageMemory == null || image.imageMemory!.isEmpty) {
    print("🚫 IMAGE NO DATA - rId: ${image.rId}, docImages: ${image.parent?.parent?.parent?.parent?.docImages.keys.length ?? 0} images");
    return SizedBox(width: image.width, height: image.height, child: Center(child: Text("No Data")));
  }

  // التحقق من صحة البيانات (Magic Bytes)
  bool isValid = false;
  if (image.imageMemory!.length > 4) {
    // PNG: 89 50 4E 47
    if (image.imageMemory![0] == 0x89 && image.imageMemory![1] == 0x50 && image.imageMemory![2] == 0x4E && image.imageMemory![3] == 0x47) {
      isValid = true;
      // print("✅ Valid PNG detected for ${image.rId}");
    }
    // JPEG: FF D8 FF
    else if (image.imageMemory![0] == 0xFF && image.imageMemory![1] == 0xD8 && image.imageMemory![2] == 0xFF) {
      isValid = true;
      // print("✅ Valid JPEG detected for ${image.rId}");
    }
    // GIF: 47 49 46 38
    else if (image.imageMemory![0] == 0x47 && image.imageMemory![1] == 0x49 && image.imageMemory![2] == 0x46 && image.imageMemory![3] == 0x38) {
      isValid = true;
    }
    // WebP: 52 49 46 46 ... 57 45 42 50 (RIFF ... WEBP)
    else if (image.imageMemory![0] == 0x52 && image.imageMemory![1] == 0x49 && image.imageMemory![2] == 0x46 && image.imageMemory![3] == 0x46) {
        isValid = true;
    }
    // EMF: 01 00 00 00
    else if (image.imageMemory![0] == 0x01 && image.imageMemory![1] == 0x00 && image.imageMemory![2] == 0x00 && image.imageMemory![3] == 0x00) {
       print("⚠️ EMF Image detected (rId: ${image.rId}) - Not supported natively by Flutter");
       return Container(
          width: image.width,
          height: image.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue),
            color: Colors.blue.withOpacity(0.1),
          ),
          child: Center(child: Text("EMF Image\n(Not Supported)", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.blue))),
       );
    }
  }

  if (!isValid) {
      print("⚠️ Invalid Image Format for rId: ${image.rId} (First 4 bytes: ${image.imageMemory!.take(4).toList()})");
      return Container(
        width: image.width,
        height: image.height,
        color: Colors.orange.withOpacity(0.2),
        child: Center(child: Text("Invalid Format", style: TextStyle(fontSize: 10, color: Colors.orange))),
      );
  }
  
  // استخدام Transform.translate بدلاً من Padding للسماح بالقيم السالبة
  return Align(
    alignment: Alignment.topLeft,
    child: Transform.translate(
        offset: Offset(posX, posY), // نستخدم القيم الأصلية (بما في ذلك السالبة)
        child: GestureDetector(
          onTap: () {
            print("═══════════════════════════════════════════════════════════");
            print("IMAGE TAPPED: ${image.rId}");
            print("  Original posX=${image.posX}, posY=${image.posY}");
            print("  Size: width=${image.width}, height=${image.height}");
            print("═══════════════════════════════════════════════════════════");
          },
          child: Container(
            // لا حاجة لـ padding هنا لأننا استخدمنا translate
            width: image.width,
            height: image.height,
            child: Image.memory(
              image.imageMemory!,
              width: image.width,
              height: image.height,
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                 return Container(
                    width: image.width,
                    height: image.height,
                    color: Colors.red.withOpacity(0.2),
                    child: Center(child: Icon(Icons.broken_image, color: Colors.red)),
                  );
              },
            ),
          ),
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
