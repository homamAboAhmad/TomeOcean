import 'dart:typed_data';

import 'package:golden_shamela/main.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';
import 'package:golden_shamela/wordToHTML/MyInt.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml.dart';

import '../wordToHTML/ExtractWordImages.dart';

ImageData _imageData = ImageData();
late XmlElement _drawingElement;

ImageData? parseImageData(runT run ) {
  xml.XmlElement document = run.xmlRun!;
  // docImages
  _imageData = ImageData();
  _imageData.parent = run;
  var drawingElement = document.findAllElements('w:drawing').firstOrNull;
  if (drawingElement == null) return null;
  _drawingElement = drawingElement;
  setRId();
  _imageData.setImageMemory(run);
  checkFromPage();
  checkRelativeFromV();
  // print("fromPage ${_imageData.fromPage}");
  setDemenisions();
  setOffsets();
  setRelativeHeight();
  return _imageData;
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
  _imageData.posX = getPosOffset( "H");
  _imageData.posY = getPosOffset( "V");
  _imageData.alignH = setPosAlign( "H") ?? "left";
  _imageData.alingV = setPosAlign( "V") ?? "top";
}

setRelativeHeight() {
  String s =
      _drawingElement.getElement("wp:anchor")?.getAttribute("relativeHeight") ??
          "0";
  bool aboveDoc =_drawingElement.getElement("wp:anchor")?.getAttribute("behindDoc") =="0";
  _imageData.relativeHeight = double.parse(s);

  if(aboveDoc) {
    _imageData.relativeHeight= _imageData.relativeHeight*2;
  }
}

setWidth() {
  _imageData.width = getExtent(_drawingElement, "cx");
}

setHeight() {
  _imageData.height = getExtent(_drawingElement, "cy");
}

double getExtent(xml.XmlElement drawingElement, String extent) {
  xml.XmlElement extentElement =
      drawingElement.findAllElements('wp:extent').firstWhere(
            (element) =>
                element.getAttribute('cx') != null &&
                element.getAttribute('cy') != null,
          );

  double e = double.parse(extentElement.getAttribute(extent)!);
  e = e.emuToPx();
  return e;
}

setRId() {
  xml.XmlElement? blipElement =
      _drawingElement.findAllElements('a:blip').firstWhere(
            (element) => element.getAttribute('r:embed') != null,
          );
  _imageData.rId = blipElement.getAttribute('r:embed')!;

}

checkFromPage() {
  _imageData.relativeFromH = _drawingElement
          .getElement("wp:anchor")
          ?.getElement("wp:positionH")
          ?.getAttribute("relativeFrom")??"margin";
}
checkRelativeFromV(){
  _imageData.relativeFromV = _drawingElement
      .getElement("wp:anchor")
      ?.getElement("wp:positionV")
      ?.getAttribute("relativeFrom")??"margin";
  // print("relativeFromV: ${_imageData.relativeFromV} ");
}

double getPosOffset( String orientation) {
  final posElement =
      _drawingElement.findAllElements('wp:position' + orientation).firstOrNull;
  if (posElement == null) return 0;

  double pos = double.parse(
      posElement.findElements('wp:posOffset').firstOrNull?.text ?? "0");
  pos = pos.emuToPx();
  return pos;
}

String? setPosAlign(String orientation) {
  final posElement =
      _drawingElement?.findAllElements('wp:position' + orientation).firstOrNull;
  // print("posElement ${posElement?.getElement("wp:align")?.text}");
  return posElement?.getElement("wp:align")?.text;
}

class ImageData {
  String rId = "";
  double width = -1; // بالبيكسل أو الوحدة المناسبة
  double height = -1;
  double posX = -1;
  String alignH = "left";
  String alingV = "top";
  double relativeHeight = 0;
  runT? parent;
  double posY = -1;
  //String image64 = "";
  String relativeFromH = "margin";
  String relativeFromV = "margin";
  Uint8List imageMemory = Uint8List(0);

  ImageData();
  setImageMemory(runT run){
    String imgName = getImageFrmRel(rId);
   // image64 = getImageByName(imgName);
    Map<String, Uint8List>? docImages2 = run.parent?.parent?.parent?.docImages;
    imageMemory = docImages2?[imgName]??Uint8List(0);

  }



}

bool isImageRun(xml.XmlElement? xmlRun) {
  return xmlRun?.findElements('w:drawing').isNotEmpty ?? false;
}

// مثال على ميثود لتحويل rId إلى URL (تحتاج إلى تنفيذ هذا بناءً على حالتك)
String getImageUrlFromId(String rId) {
  // هنا يجب أن تكون لديك طريقة لتحويل rId إلى URL للصورة
  return "path/to/image_$rId.png"; // هذه مجرد قيمة افتراضية
}
