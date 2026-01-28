import 'dart:typed_data';
import 'dart:ui';

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
import 'VectorPathParser.dart';

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

  // Check for VML (w:pict) if drawing is not found
  bool isVml = false;
  if (drawingElement == null) {
    drawingElement = document.findAllElements('w:pict').firstOrNull;
    if (drawingElement != null) {
      isVml = true;
    }
  }

  if (drawingElement == null) return null;
  _drawingElement = drawingElement;

  // --- NEW: Check for Group (wpg:wgp) ---
  var groupElement = drawingElement.findAllElements('wpg:wgp').firstOrNull;
  if (groupElement != null) {
    _imageData.isGroup = true;
    _imageData.rId = "GROUP"; // Placeholder

    // Find all pictures inside the group
    var pictures = groupElement.findAllElements('pic:pic');
    for (var pic in pictures) {
      // Create a child ImageData for each picture
      ImageData childImage = ImageData();
      childImage.parent = run;
      childImage.customRelIdList = customRelIdList;

      // 1. Extract rId from blipFill
      var blip = pic.findAllElements('a:blip').firstOrNull;
      if (blip != null) {
        childImage.rId = blip.getAttribute('r:embed') ?? "";
      }

      // 2. Load Image Memory
      // IMPORTANT: Only load if customRelIdList is provided.
      // Groups appear in headers/footers which require customRelIdList.
      // If null, skip loading - it will be loaded correctly on subsequent call with customRelIdList.
      if (childImage.rId.isNotEmpty && customRelIdList != null) {
        childImage.setImageMemory(run, customRelIdList: customRelIdList);
      } else if (childImage.rId.isNotEmpty && customRelIdList == null) {
        // Will load later
      }

      // 3. Parse Dimensions & Transforms (from pic:spPr -> a:xfrm)
      var spPr = pic.findAllElements('pic:spPr').firstOrNull;
      if (spPr != null) {
        var xfrm = spPr.findAllElements('a:xfrm').firstOrNull;
        if (xfrm != null) {
          // Offsets (relative to group)
          var off = xfrm.findAllElements('a:off').firstOrNull;
          if (off != null) {
            String x = off.getAttribute('x') ?? "0";
            String y = off.getAttribute('y') ?? "0";
            // Convert EMU to Pixels? Or treat as relative pixels if already converted?
            // Usually internal units are EMUs. 1 inch = 914400 EMUs. 1 inch = 96 px.
            // 1 px = 9525 EMUs.
            childImage.posX = (int.tryParse(x) ?? 0) / 9525.0;
            childImage.posY = (int.tryParse(y) ?? 0) / 9525.0;
          }

          // Extents (Size)
          var ext = xfrm.findAllElements('a:ext').firstOrNull;
          if (ext != null) {
            String cx = ext.getAttribute('cx') ?? "0";
            String cy = ext.getAttribute('cy') ?? "0";
            childImage.width = (int.tryParse(cx) ?? 0) / 9525.0;
            childImage.height = (int.tryParse(cy) ?? 0) / 9525.0;
          }

          // Rotation
          String rot = xfrm.getAttribute('rot') ?? "0";
          childImage.rotation = (int.tryParse(rot) ?? 0) / 60000.0;

          // Flips
          childImage.flipH = xfrm.getAttribute('flipH') == '1';
          childImage.flipV = xfrm.getAttribute('flipV') == '1';
        }
      }

      _imageData.groupImages.add(childImage);
    }

    // Also set group dimensions if needed (from wpg:grpSpPr)
    var grpSpPr = groupElement.findAllElements('wpg:grpSpPr').firstOrNull;
    if (grpSpPr != null) {
      var xfrm = grpSpPr.findAllElements('a:xfrm').firstOrNull;
      if (xfrm != null) {
        var ext = xfrm.findAllElements('a:ext').firstOrNull;
        if (ext != null) {
          String cx = ext.getAttribute('cx') ?? "0";
          String cy = ext.getAttribute('cy') ?? "0";
          _imageData.width = (int.tryParse(cx) ?? 0) / 9525.0;
          _imageData.height = (int.tryParse(cy) ?? 0) / 9525.0;
        }
        // Group position
        var off = xfrm.findAllElements('a:off').firstOrNull;
        if (off != null) {
          String x = off.getAttribute('x') ?? "0";
          String y = off.getAttribute('y') ?? "0";
          _imageData.posX = (int.tryParse(x) ?? 0) / 9525.0;
          _imageData.posY = (int.tryParse(y) ?? 0) / 9525.0;
        }
      }
    }

    // Process standard positioning for the group container itself
    checkFromPage();
    checkRelativeFromV();
    setOffsets(); // Will use wp:anchor info for the group
    // Actually, setDemenisions checks wp:extent which is correct for the container
    setDemenisions();
    checkWrapMode();

    return _imageData;
  }

  // --- NEW: Check for Vector Shape (wps:wsp with a:custGeom) ---
  // هذا يتعامل مع الأشكال المخصصة مثل الخط الزخرفي (Freeform) في الهيدر
  var wspElement = drawingElement.findAllElements('wps:wsp').firstOrNull;
  if (wspElement != null) {
    var custGeom = wspElement.findAllElements('a:custGeom').firstOrNull;
    if (custGeom != null) {
      // هذا شكل Vector مخصص - نحاول تحليله
      _imageData.isVectorShape = true;
      _imageData.rId = "VECTOR"; // Placeholder

      // استخراج الأبعاد من wp:extent
      setDemenisions();

      // استخراج الموقع
      checkFromPage();
      checkRelativeFromV();
      setOffsets();
      checkWrapMode();

      // تحليل المسار
      _parseVectorPath(custGeom, wspElement);

      // استخراج لون التعبئة والحدود
      _parseVectorColors(wspElement);

      return _imageData;
    }
  }

  if (isVml) {
    _parseVmlData();
    return _imageData;
  }

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
  checkHyperlink(); // Check for a:hlinkClick on the image
  checkBlipFill(); // Check for stretch/tile
  return _imageData;
}

void checkBlipFill() {
  // البحث عن pic:blipFill ثم a:stretch
  // المسار: pic:pic -> pic:blipFill -> a:stretch
  // نستخدم descendants للبحث العميق لأن الهيكلية قد تختلف قليلاً
  try {
    var blipFill = _drawingElement.descendants
        .whereType<xml.XmlElement>()
        .firstWhere(
          (e) => e.name.local == 'blipFill',
          orElse: () => xml.XmlElement(xml.XmlName('null')),
        );

    if (blipFill.name.local != 'null') {
      var stretch = blipFill.descendants
          .whereType<xml.XmlElement>()
          .where((e) => e.name.local == 'stretch')
          .firstOrNull;

      if (stretch != null) {
        // إذا وجدنا stretch، نتأكد من وجود fillRect داخله
        var fillRect = stretch.descendants
            .whereType<xml.XmlElement>()
            .where((e) => e.name.local == 'fillRect')
            .firstOrNull;

        // مجرد وجود stretch يكفي عادة، ولكن fillRect يؤكد ذلك
        if (fillRect != null || stretch.children.isEmpty) {
          // stretch فارغ أحياناً يعني الافتراضي؟ لا، عادة يحوي fillRect
          // لكن لنتساهل، وجود stretch بحد ذاته إشارة قوية
          _imageData.isStretched = true;
        }
      }
    }
  } catch (e) {
    // ignore
  }
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

/// Check for hyperlink on the image (a:hlinkClick)
void checkHyperlink() {
  // Look for a:hlinkClick in the drawing properties
  // It can be in wp:docPr (non-visual properties) or inside the picture
  var docPr = _drawingElement.findAllElements('wp:docPr').firstOrNull;
  var hlinkClick = docPr?.findAllElements('a:hlinkClick').firstOrNull;

  // Also check inside pic:nvPicPr -> pic:cNvPr
  if (hlinkClick == null) {
    var cNvPr = _drawingElement.findAllElements('pic:cNvPr').firstOrNull;
    hlinkClick = cNvPr?.findAllElements('a:hlinkClick').firstOrNull;
  }

  // Also look in the anchor/inline non-visual properties
  if (hlinkClick == null) {
    hlinkClick = _drawingElement.findAllElements('a:hlinkClick').firstOrNull;
  }

  if (hlinkClick != null) {
    String? rId = hlinkClick.getAttribute('r:id');
    if (rId != null && rId.isNotEmpty) {
      var wordDocument = _imageData.parent?.parent?.parent?.parent;
      if (wordDocument != null) {
        var relId = wordDocument.relIdList[rId];
        if (relId != null) {
          _imageData.hyperlinkUrl = relId.Target;
        }
      }

      // Also check custom relationships (for headers/footers)
      if (_imageData.hyperlinkUrl == null &&
          _imageData.customRelIdList != null) {
        var relId = _imageData.customRelIdList![rId];
        if (relId != null) {
          _imageData.hyperlinkUrl = relId.Target;
        }
      }
    }
  }
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

void _parseVmlData() {
  // 1. Find v:shape
  var shape = _drawingElement.descendants
      .whereType<xml.XmlElement>()
      .firstWhere(
        (e) => e.name.local == 'shape',
        orElse: () => xml.XmlElement(xml.XmlName('null')),
      );

  if (shape.name.local == 'null') return;

  // 2. Extract Dimensions from style attribute
  // style="...width:261.35pt;height:42.3pt..."
  String? style = shape.getAttribute('style');
  if (style != null) {
    _parseVmlStyle(style);
  }

  // 3. Extract r:id from v:imagedata
  var imageData = shape.descendants.whereType<xml.XmlElement>().firstWhere(
    (e) => e.name.local == 'imagedata',
    orElse: () => xml.XmlElement(xml.XmlName('null')),
  );

  if (imageData.name.local != 'null') {
    String? rId = imageData.getAttribute('r:id');
    if (rId != null) {
      _imageData.rId = rId;
      _imageData.setImageMemory(
        _imageData.parent!,
        customRelIdList: _imageData.customRelIdList,
      );
    }
  }
}

void _parseVmlStyle(String style) {
  // Simple CSS style parser for width and height
  List<String> parts = style.split(';');
  for (String part in parts) {
    List<String> kv = part.split(':');
    if (kv.length == 2) {
      String key = kv[0].trim().toLowerCase();
      String value = kv[1].trim().toLowerCase();

      if (key == 'width') {
        _imageData.width = _parseUnit(value);
      } else if (key == 'height') {
        _imageData.height = _parseUnit(value);
      }
    }
  }
}

double _parseUnit(String value) {
  double val = 0;
  if (value.endsWith('pt')) {
    val = double.tryParse(value.replaceAll('pt', '')) ?? 0;
    // points to pixels (approximate, context dependent but typically 1.33x)
    // Flutter logical pixels are usually approx 96dpi, points are 72dpi. 96/72 = 1.333
    val = val * 1.333;
  } else if (value.endsWith('px')) {
    val = double.tryParse(value.replaceAll('px', '')) ?? 0;
  } else {
    // Try parse raw number
    val = double.tryParse(value) ?? 0;
  }
  return val;
}

void setDemenisions() {
  setWidth();
  setHeight();
  setRotation();
  // fixMaxes();
}

void setRotation() {
  // Use descendants to find any element with 'rot' attribute to be safe
  // and avoid issues with findAllElements naming or specific parent filtering
  var elementWithRot = _drawingElement.descendants
      .whereType<xml.XmlElement>()
      .firstWhere(
        (e) => e.getAttribute('rot') != null,
        orElse: () => _drawingElement, // Fallback to avoid null, check later
      );

  String? rotAttr = elementWithRot.getAttribute('rot');

  // Debug print
  // print(
  //   "🔍 Rotation Search: Found rot='$rotAttr' in element '${elementWithRot.name.local}'",
  // );

  if (rotAttr != null) {
    try {
      // Rotation is in 60000ths of a degree
      double val = double.parse(rotAttr);
      _imageData.rotation = val / 60000;
      // print("   -> Parsed Rotation: ${_imageData.rotation} degrees");

      // Parse flipH and flipV
      String? flipHAttr = elementWithRot.getAttribute('flipH');
      String? flipVAttr = elementWithRot.getAttribute('flipV');
      if (flipHAttr == "1" || flipHAttr == "true") _imageData.flipH = true;
      if (flipVAttr == "1" || flipVAttr == "true") _imageData.flipV = true;

      double? xfrmWidth;
      double? xfrmHeight;
      String? xfrmCx = elementWithRot.getElement('a:ext')?.getAttribute('cx');
      String? xfrmCy = elementWithRot.getElement('a:ext')?.getAttribute('cy');
      if (xfrmCx != null) xfrmWidth = double.tryParse(xfrmCx);
      if (xfrmCy != null) xfrmHeight = double.tryParse(xfrmCy);

      // Parse effectExtent to check for compensation
      // wp:effectExtent l="1588" t="0" r="4762" b="4763"
      bool hasEffectCompensation = false;
      var effectExtent = _drawingElement.descendants
          .whereType<XmlElement>()
          .firstWhere(
            (e) => e.name.local == 'effectExtent',
            orElse: () => XmlElement(XmlName('null')),
          );
      if (effectExtent.name.local != 'null') {
        double r = double.tryParse(effectExtent.getAttribute('r') ?? '0') ?? 0;
        double b = double.tryParse(effectExtent.getAttribute('b') ?? '0') ?? 0;
        if (r > 0 || b > 0) hasEffectCompensation = true;
      }

      // Logic:
      // 1. Calculate Aspect Ratios
      // 2. If Rotation implies inversion (90, 270)
      // 3. AND wp:extent AR matches a:xfrm AR (Mismatch between layout and rotation)
      // -> SWAP (To enforce correct bounding box).

      // Special Handling for EXIF conflict:
      // If 'hasEffectCompensation' is true, it suggests the image might validly be "Rotated" in XML
      // but its content is ALREADY upright (EXIF).
      // In this case, we SWAP dimensions (for layout) but RESET rotation to 0 (for content).

      bool isRotated90or270 =
          (_imageData.rotation.abs() - 90).abs() < 1.0 ||
          (_imageData.rotation.abs() - 270).abs() < 1.0;

      if (isRotated90or270 && xfrmWidth != null && xfrmHeight != null) {
        double arExtent = _imageData.width / _imageData.height;
        double arXfrm = xfrmWidth / xfrmHeight;

        // Check if aspect ratios are similar (indicating extent is NOT rotated yet)
        bool arMatches =
            (arExtent - arXfrm).abs() < 0.1 ||
            (arExtent - arXfrm).abs() / arExtent < 0.1;

        if (arMatches) {
          // print("   -> 🔄 Aspect Ratio Mismatch detected. Swapping W/H.");
          double temp = _imageData.width;
          _imageData.width = _imageData.height;
          _imageData.height = temp;

          if (hasEffectCompensation) {
            // print("   -> 🛑 EffectExtent detected. Resetting rotation to 0 to avoid double-rotation.");
            _imageData.rotation = 0;
          }
        }
      }
    } catch (e) {
      print("Error parsing rotation: $e");
    }
  } else {
    // print("⚠️ No xfrm found/rot attribute for rId=${_imageData.rId}");
  }
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

/// تحليل مسار Vector من a:custGeom باستخدام VectorPathParser
/// يستخدم VectorPathParser.dart للتحليل الفعلي
void _parseVectorPath(xml.XmlElement custGeom, xml.XmlElement wspElement) {
  // استخدام VectorPathParser للتحليل
  final results = VectorPathParser.parseCustomGeometry(
    custGeom,
    targetWidth: _imageData.width > 0 ? _imageData.width : null,
    targetHeight: _imageData.height > 0 ? _imageData.height : null,
  );

  // نأخذ أول مسار فقط (عادة يكون هناك مسار واحد)
  if (results.isNotEmpty) {
    _imageData.vectorPath = results.first.path;
  }
}

/// استخراج ألوان التعبئة والحدود من wps:wsp
void _parseVectorColors(xml.XmlElement wspElement) {
  // البحث عن wps:spPr (Shape Properties)
  final spPr = wspElement.findAllElements('wps:spPr').firstOrNull;
  if (spPr == null) return;

  // استخراج لون التعبئة من a:solidFill
  final solidFill = spPr.findAllElements('a:solidFill').firstOrNull;
  if (solidFill != null) {
    _imageData.vectorFillColor = _parseDrawingColor(solidFill);
  }

  // استخراج لون الحدود من a:ln > a:solidFill
  final ln = spPr.findAllElements('a:ln').firstOrNull;
  if (ln != null) {
    final lnFill = ln.findAllElements('a:solidFill').firstOrNull;
    if (lnFill != null) {
      _imageData.vectorStrokeColor = _parseDrawingColor(lnFill);
    }

    // استخراج سمك الحدود
    final wAttr = ln.getAttribute('w');
    if (wAttr != null) {
      // عرض الخط بـ EMUs، نحوله إلى pixels
      final widthEmu = double.tryParse(wAttr) ?? 0;
      _imageData.vectorStrokeWidth = widthEmu / 9525.0;
      if (_imageData.vectorStrokeWidth < 0.5) {
        _imageData.vectorStrokeWidth = 1.0; // الحد الأدنى
      }
    }
  }

  // إذا لم يكن هناك تعبئة ولا حدود، استخدم الأسود كافتراضي للحدود
  if (_imageData.vectorFillColor == null &&
      _imageData.vectorStrokeColor == null) {
    _imageData.vectorStrokeColor = const Color(0xFF000000);
  }
}

/// تحليل لون من عنصر a:solidFill
Color? _parseDrawingColor(xml.XmlElement solidFill) {
  // البحث عن a:srgbClr (لون RGB مباشر)
  final srgbClr = solidFill.findAllElements('a:srgbClr').firstOrNull;
  if (srgbClr != null) {
    final val = srgbClr.getAttribute('val');
    if (val != null && val.length == 6) {
      try {
        return Color(int.parse('FF$val', radix: 16));
      } catch (e) {
        // تجاهل الخطأ
      }
    }
  }

  // البحث عن a:schemeClr (لون من الثيم)
  final schemeClr = solidFill.findAllElements('a:schemeClr').firstOrNull;
  if (schemeClr != null) {
    final val = schemeClr.getAttribute('val');
    // تحويل بسيط لبعض الألوان الشائعة
    switch (val) {
      case 'tx1':
      case 'dk1':
        return const Color(0xFF000000); // أسود
      case 'bg1':
      case 'lt1':
        return const Color(0xFFFFFFFF); // أبيض
      case 'accent1':
        return const Color(0xFF4472C4); // أزرق
      case 'accent2':
        return const Color(0xFFED7D31); // برتقالي
      default:
        return const Color(0xFF000000); // افتراضي أسود
    }
  }

  return null;
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
  // البحث عن anchor أو inline أولاً
  var container =
      _drawingElement.findElements('wp:anchor').firstOrNull ??
      _drawingElement.findElements('wp:inline').firstOrNull;

  if (container == null) {
    // Fallback: search anywhere (old behavior, just in case)
    container = _drawingElement;
  }

  final posElement = container
      .findElements('wp:position' + orientation)
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
  @JsonKey(defaultValue: 0)
  double rotation = 0; // زاوية الدوران بالدرجات
  @JsonKey(defaultValue: false)
  bool behindDoc = false; // false = أمام النص، true = خلف النص
  @JsonKey(defaultValue: false)
  bool flipH = false;
  @JsonKey(defaultValue: false)
  bool flipV = false;
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

  /// رابط على الصورة (a:hlinkClick)
  String? hyperlinkUrl;

  /// هل الصورة ممتدة (BoxFit.fill) بناءً على blipFill > stretch
  @JsonKey(defaultValue: false)
  bool isStretched = false;

  @JsonKey(ignore: true)
  Map<String, RelId>? customRelIdList;

  // Group Support
  @JsonKey(defaultValue: false)
  bool isGroup = false;
  @JsonKey(ignore: true)
  List<ImageData> groupImages = [];

  // Vector Shape Support (for wps:wsp with a:custGeom)
  @JsonKey(defaultValue: false)
  bool isVectorShape = false;
  @JsonKey(ignore: true)
  Path? vectorPath;
  @JsonKey(ignore: true)
  Color? vectorFillColor;
  @JsonKey(ignore: true)
  Color? vectorStrokeColor;
  @JsonKey(ignore: true)
  double vectorStrokeWidth = 1.0;

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
    if (customRelIdList != null) {
      if (customRelIdList!.containsKey(rId)) {
        imgName = customRelIdList![rId]?.Target;
        // print("DEBUG_IMAGE: Found rId=$rId in customRelIdList -> $imgName");
      } else {
        print(
          "DEBUG_IMAGE: ⚠️ rId=$rId NOT FOUND in customRelIdList. Keys: ${customRelIdList!.keys.join(',')}",
        );
      }
    }

    // Fallback to document list
    if (imgName == null) {
      // print("DEBUG_IMAGE: Checking global relIdList for rId=$rId");
      imgName = wordDocument.relIdList[rId]?.Target;
      if (imgName != null) {
        print(
          "DEBUG_IMAGE: Found rId=$rId in GLOBAL relIdList -> $imgName (Fallback triggered!)",
        );
      }
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
  if (xmlRun == null) return false;
  return xmlRun.findAllElements('w:drawing').isNotEmpty ||
      xmlRun.findAllElements('w:pict').isNotEmpty;
}

// مثال على ميثود لتحويل rId إلى URL (تحتاج إلى تنفيذ هذا بناءً على حالتك)
String getImageUrlFromId(String rId) {
  // هنا يجب أن تكون لديك طريقة لتحويل rId إلى URL للصورة
  return "path/to/image_$rId.png"; // هذه مجرد قيمة افتراضية
}
