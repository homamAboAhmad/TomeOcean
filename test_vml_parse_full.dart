import "package:xml/xml.dart" as xml;

double _parseUnit(String value) {
  double val = 0;
  if (value.endsWith("pt")) {
    val = double.tryParse(value.replaceAll("pt", "")) ?? 0;
    val = val * 1.333;
  } else if (value.endsWith("px")) {
    val = double.tryParse(value.replaceAll("px", "")) ?? 0;
  } else if (value.endsWith("in")) {
    val = double.tryParse(value.replaceAll("in", "")) ?? 0;
    val = val * 96.0;
  } else {
    val = double.tryParse(value) ?? 0;
  }
  return val;
}

Map<String, String> _parseVmlStyleMap(String style) {
  final Map<String, String> styleMap = {};
  for (final part in style.split(";")) {
    final kv = part.split(":");
    if (kv.length == 2) {
      styleMap[kv[0].trim().toLowerCase()] = kv[1].trim().toLowerCase();
    }
  }
  return styleMap;
}

void main() {
  String xmlString = """
<w:p w14:paraId="4B644998" w14:textId="77777777" w:rsidR="004332DD" w:rsidRPr="000840F0" w:rsidRDefault="00BE371E" w:rsidP="00CE0D41" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:pPr><w:widowControl w:val="0"/><w:ind w:firstLine="284"/><w:jc w:val="lowKashida"/><w:rPr><w:rFonts w:cs="Traditional Arabic"/><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/><w:rtl/></w:rPr></w:pPr><w:r><w:rPr><w:vanish/></w:rPr><w:t>{{PG:41}}</w:t></w:r><w:bookmarkEnd w:id="50"/><w:r><w:rPr><w:rFonts w:cs="Traditional Arabic"/><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr><w:lastRenderedPageBreak/><w:pict w14:anchorId="124F4FEC"><v:shape id="_x0000_i1029" type="#_x0000_t75" style="width:6in;height:593.4pt"><v:imagedata r:id="rId15" o:title="img005"/></v:shape></w:pict></w:r></w:p>
  """;

  final document = xml.XmlDocument.parse(xmlString);
  var _drawingElement = document.findAllElements("w:pict").firstOrNull;
  
  var shape = _drawingElement?.descendants
      .whereType<xml.XmlElement>()
      .firstWhere(
        (e) => e.name.local == "shape",
        orElse: () => xml.XmlElement(xml.XmlName("null")),
      );

  if (shape == null || shape.name.local == "null") return;

  String? style = shape.getAttribute("style");
  print("Style: \$style");
  var map = _parseVmlStyleMap(style!);
  print("Map: \$map");
  if (map.containsKey("width")) {
     print("width: \${_parseUnit(map["width"]!)}");
  }
  if (map.containsKey("height")) {
     print("height: \${_parseUnit(map["height"]!)}");
  }

  var imageData = shape.descendants.whereType<xml.XmlElement>().firstWhere(
    (e) => e.name.local == "imagedata",
    orElse: () => xml.XmlElement(xml.XmlName("null")),
  );
  
  if (imageData.name.local != "null") {
    print("rId: \${imageData.getAttribute('r:id')}");
  }
}
