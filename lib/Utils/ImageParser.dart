import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml.dart';

import '../wordToHTML/ExtractWordImages.dart';
import 'json_converters.dart';

part 'ImageParser.g.dart';

ImageData _imageData = ImageData();
late XmlElement _drawingElement;

ImageData? parseImageData(runT run, {Map<String, RelId>? customRelIdList}) {
  xml.XmlElement document = run.xmlRun!;
  // docImages
  _imageData = ImageData();
  _imageData.customRelIdList = customRelIdList;
  _imageData.parent = run;
  var drawingElement = document.findAllElements('w:drawing').firstOrNull;
  if (drawingElement == null) return null;
  _drawingElement = drawingElement;

  // محاولة العثور على الصورة
  try {
    setRId();
  } catch (e) {
    // إذا لم نجد r:embed، قد يكون Text Box
    _imageData.rId = "";
  }

  if (_imageData.rId.isEmpty) {
    // Try to parse as Text Box
    parseTextBox();
  } else {
    _imageData.setImageMemory(run, customRelIdList: customRelIdList);
  }

  checkFromPage();
  checkRelativeFromV();
  // print("fromPage ${_imageData.fromPage}");
  setDemenisions();
  setOffsets();
  setRelativeHeight();
  checkWrapMode();
  return _imageData;
}

checkWrapMode() {
  var anchor = _drawingElement.getElement("wp:anchor");
  if (anchor == null) return;

  if (anchor.getElement("wp:wrapNone") != null)
    _imageData.wrapMode = "None";
  else if (anchor.getElement("wp:wrapSquare") != null)
    _imageData.wrapMode = "Square";
  else if (anchor.getElement("wp:wrapTight") != null)
    _imageData.wrapMode = "Tight";
  else if (anchor.getElement("wp:wrapThrough") != null)
    _imageData.wrapMode = "Through";
  else if (anchor.getElement("wp:wrapTopAndBottom") != null)
    _imageData.wrapMode = "TopAndBottom";
}

void parseTextBox() {
  // التحقق أولاً من وجود حقل PAGE داخل TextBox
  // البحث عن w:fldSimple أو w:instrText التي تحتوي على PAGE
  var fldSimpleElements = _drawingElement.findAllElements('w:fldSimple');
  for (var fldSimple in fldSimpleElements) {
    String? instr = fldSimple.getAttribute('w:instr');
    if (instr != null && instr.toUpperCase().contains('PAGE')) {
      _imageData.containsPageField = true;
      // debugPrint("🔢 TextBox contains PAGE field (fldSimple)");
      break;
    }
  }

  // التحقق من w:instrText داخل الحقول المعقدة
  if (!_imageData.containsPageField) {
    var instrTextElements = _drawingElement.findAllElements('w:instrText');
    for (var instrText in instrTextElements) {
      if (instrText.text.toUpperCase().contains('PAGE')) {
        _imageData.containsPageField = true;
        // debugPrint("🔢 TextBox contains PAGE field (instrText)");
        break;
      }
    }
  }

  // محاولة استخراج النص من Text Box
  var textElements = _drawingElement.findAllElements('w:t');
  if (textElements.isNotEmpty) {
    StringBuffer buffer = StringBuffer();
    for (var t in textElements) {
      buffer.write(t.text);
      buffer.write(" "); // مسافة بين النصوص
    }
    _imageData.textBoxText = buffer.toString().trim();

    // محاولة البحث عن خصائص التنسيق داخل w:txbxContent
    // نبحث عن الفقرة الأولى التي تحتوي على نص
    var textRun = _drawingElement
        .findAllElements('w:r')
        .firstWhere(
          (r) => r.findAllElements('w:t').isNotEmpty,
          orElse: () => _drawingElement.findAllElements('w:r').first,
        );

    // نحاول اختيار أفضل run يملك معلومات خطوط واضحة
    var rPrElement = textRun.findAllElements('w:rPr').firstOrNull;

    if (rPrElement != null) {
      // استخراج الخط (Font Family)
      var fontsElement = rPrElement.findAllElements('w:rFonts').firstOrNull;
      if (fontsElement != null) {
        // نفضّل hAnsi/ascii (غالباً الخط المستخدم في الوورد) ثم cs
        String? hAnsi = fontsElement.getAttribute('w:hAnsi');
        String? ascii = fontsElement.getAttribute('w:ascii');
        String? cs = fontsElement.getAttribute('w:cs');

        _imageData.fontFamily = hAnsi;
        if (_imageData.fontFamily == null || _imageData.fontFamily!.isEmpty) {
          _imageData.fontFamily = ascii;
        }
        if (_imageData.fontFamily == null || _imageData.fontFamily!.isEmpty) {
          _imageData.fontFamily = cs;
        }
      }

      // استخراج اللون
      var colorAttr = rPrElement
          .findAllElements('w:color')
          .firstOrNull
          ?.getAttribute('w:val');
      if (colorAttr != null) {
        _imageData.textColor = colorAttr;
      }

      // استخراج الحجم
      // نحاول w:szCs أولاً (للنصوص العربية/المعقدة) ثم w:sz
      var szCsAttr = rPrElement
          .findAllElements('w:szCs')
          .firstOrNull
          ?.getAttribute('w:val');
      var szAttr = rPrElement
          .findAllElements('w:sz')
          .firstOrNull
          ?.getAttribute('w:val');

      var sizeToUse = szCsAttr ?? szAttr;

      if (sizeToUse != null) {
        try {
          // الحجم في Word يكون بوحدات نصف نقطة (half-points)
          // غالباً ما تحتاج Flutter إلى تكبير الخط قليلاً ليطابق الوورد
          // سنستخدم عامل ضرب 1.0 مبدئياً، أو يمكن زيادته إذا لزم الأمر
          _imageData.textSize = double.parse(sizeToUse) / 2;
        } catch (e) {
          // ignore
        }
      }
    }
  }
}

void setDemenisions() {
  setWidth();
  setHeight();
  // fixMaxes();
}

// void fixMaxes() {
//   double maxH = (wordDocument.sectpr?.height ?? 1132);
//   // maxH = maxH*0.9;
//   double maxW = (wordDocument.sectpr?.width ?? 793);
//   // maxW = maxW*0.9;
//   if (_imageData.height > maxH) _imageData.height = maxH;
//   if (_imageData.width > maxW) _imageData.width = maxW;
// }

void setOffsets() {
  _imageData.posX = getPosOffset("H");
  _imageData.posY = getPosOffset("V");
  _imageData.alignH = setPosAlign("H") ?? "left";
  _imageData.alingV = setPosAlign("V") ?? "top";
}

setRelativeHeight() {
  String s =
      _drawingElement.getElement("wp:anchor")?.getAttribute("relativeHeight") ??
      "0";
  _imageData.relativeHeight = double.parse(s);

  // قراءة behindDoc: "1" أو "true" = خلف النص، "0" أو غير ذلك = أمام النص
  String? behindDocAttr = _drawingElement
      .getElement("wp:anchor")
      ?.getAttribute("behindDoc");
  _imageData.behindDoc = (behindDocAttr == "1" || behindDocAttr == "true");

  // Debug: طباعة قيمة behindDoc
  // debugPrint(
  //   "🖼️ IMAGE behindDoc: attr='$behindDocAttr' -> behindDoc=${_imageData.behindDoc}, rId=${_imageData.rId}",
  // );
}

setWidth() {
  _imageData.width = getExtent(_drawingElement, "cx");
}

setHeight() {
  _imageData.height = getExtent(_drawingElement, "cy");
}

double getExtent(xml.XmlElement drawingElement, String extent) {
  // قد لا يكون هناك wp:extent إذا كان رسمًا مضمنًا (inline) وليس anchor
  // لكن في حالة TextBox عادة يكون anchor
  try {
    xml.XmlElement extentElement = drawingElement
        .findAllElements('wp:extent')
        .firstWhere(
          (element) =>
              element.getAttribute('cx') != null &&
              element.getAttribute('cy') != null,
        );

    double e = double.parse(extentElement.getAttribute(extent)!);
    e = e.emuToPx();
    return e;
  } catch (e) {
    return 100; // Default if not found
  }
}

setRId() {
  // نستخدم orElse لتجنب الخطأ إذا لم تكن هناك صورة
  xml.XmlElement? blipElement = _drawingElement
      .findAllElements('a:blip')
      .firstWhere(
        (element) => element.getAttribute('r:embed') != null,
        orElse: () => throw Exception("No blip found"),
      );
  _imageData.rId = blipElement.getAttribute('r:embed')!;
}

checkFromPage() {
  _imageData.relativeFromH =
      _drawingElement
          .getElement("wp:anchor")
          ?.getElement("wp:positionH")
          ?.getAttribute("relativeFrom") ??
      "margin";
}

checkRelativeFromV() {
  _imageData.relativeFromV =
      _drawingElement
          .getElement("wp:anchor")
          ?.getElement("wp:positionV")
          ?.getAttribute("relativeFrom") ??
      "margin";
  // print("relativeFromV: ${_imageData.relativeFromV} ");
}

double getPosOffset(String orientation) {
  final posElement = _drawingElement
      .findAllElements('wp:position' + orientation)
      .firstOrNull;
  if (posElement == null) return 0;

  double pos = double.parse(
    posElement.findElements('wp:posOffset').firstOrNull?.text ?? "0",
  );
  pos = pos.emuToPx();
  return pos;
}

String? setPosAlign(String orientation) {
  final posElement = _drawingElement
      ?.findAllElements('wp:position' + orientation)
      .firstOrNull;
  // print("posElement ${posElement?.getElement("wp:align")?.text}");
  return posElement?.getElement("wp:align")?.text;
}

@JsonSerializable(explicitToJson: true)
class ImageData {
  String rId = "";
  double width = -1; // بالبيكسل أو الوحدة المناسبة
  double height = -1;
  double posX = -1;
  String alignH = "left";
  String alingV = "top";
  double relativeHeight = 0;
  @JsonKey(defaultValue: false)
  bool behindDoc = false; // false = أمام النص، true = خلف النص
  @JsonKey(ignore: true)
  runT? parent;
  double posY = -1;
  //String image64 = "";
  String relativeFromH = "margin";
  String relativeFromV = "margin";
  String? wrapMode;
  @JsonKey(fromJson: uint8ListFromJson, toJson: uint8ListToJson)
  Uint8List? imageMemory;
  @JsonKey(ignore: true)
  dynamic image; // Changed from ui.Image? to dynamic to avoid import

  String? textBoxText; // النص المستخرج من Text Box
  String? textColor; // لون النص (Hex String)
  double? textSize; // حجم النص
  String? fontFamily; // نوع الخط

  /// علامة تشير إلى أن TextBox يحتوي على حقل PAGE ويجب استبداله برقم الصفحة الفعلي
  @JsonKey(defaultValue: false)
  bool containsPageField = false;

  @JsonKey(ignore: true)
  Map<String, RelId>? customRelIdList;

  ImageData();

  factory ImageData.fromJson(Map<String, dynamic> json) =>
      _$ImageDataFromJson(json);
  Map<String, dynamic> toJson() => _$ImageDataToJson(this);

  static ImageData fromMap(Map<String, dynamic> json, runT parent) {
    final imageData = _$ImageDataFromJson(json);
    imageData.parent = parent;

    // If imageMemory is empty but we have an rId, reload from docImages
    // This handles the case when loading from cache where imageMemory wasn't saved
    if ((imageData.imageMemory == null || imageData.imageMemory!.isEmpty) &&
        imageData.rId.isNotEmpty) {
      imageData.setImageMemory(parent);
    }

    return imageData;
  }

  setImageMemory(runT run, {Map<String, RelId>? customRelIdList}) {
    if (rId.isEmpty) return;

    // Get WordDocument from the parent chain
    var wordDocument = run.parent?.parent?.parent;
    if (wordDocument == null) return;

    Map<String, Uint8List>? docImages = wordDocument.docImages;
    if (docImages == null || docImages.isEmpty) return;

    // Extract the number from rId (e.g., "rId8" -> "8")
    String rIdNum = rId.replaceAll(RegExp(r'[^0-9]'), '');

    // Strategy 1: Try direct lookup from relIdList first
    String? imgName;

    // Check custom list first (for headers/footers)
    if (customRelIdList != null && customRelIdList!.containsKey(rId)) {
      imgName = customRelIdList![rId]?.Target;
    }
    // Fallback to document list
    else {
      imgName = wordDocument.relIdList[rId]?.Target;
    }

    if (imgName != null) {
      // Handle explicit media paths
      imageMemory = docImages[imgName];
      if (imageMemory != null && imageMemory!.isNotEmpty) return;

      // Handle incomplete paths (sometimes target is just "image1.png" but key is "media/image1.png")
      if (!imgName.startsWith('media/') && !imgName.contains('/')) {
        String potentialKey = "media/$imgName";
        imageMemory = docImages[potentialKey];
        if (imageMemory != null && imageMemory!.isNotEmpty) return;
      }
    }

    // Strategy 3: Fallback - try global function (for backward compatibility)
    if (imgName == null || imgName.isEmpty) {
      imgName = getImageFrmRel(rId);
    }

    if (imgName.isNotEmpty && docImages.containsKey(imgName)) {
      imageMemory = docImages[imgName];
      return;
    }

    // If nothing found, set empty
    imageMemory = Uint8List(0);
  }
}

bool isImageRun(xml.XmlElement? xmlRun) {
  // نستخدم findAllElements للبحث في كل الأبناء بما في ذلك mc:AlternateContent
  return xmlRun?.findAllElements('w:drawing').isNotEmpty ?? false;
}

// مثال على ميثود لتحويل rId إلى URL (تحتاج إلى تنفيذ هذا بناءً على حالتك)
String getImageUrlFromId(String rId) {
  // هنا يجب أن تكون لديك طريقة لتحويل rId إلى URL للصورة
  return "path/to/image_$rId.png"; // هذه مجرد قيمة افتراضية
}
