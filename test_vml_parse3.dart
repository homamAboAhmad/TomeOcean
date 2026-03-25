import "package:xml/xml.dart" as xml;

void main() {
  String xmlString = """
<w:pict xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<v:shape id="_x0000_i1029" type="#_x0000_t75" style="width:6in;height:593.4pt">
<v:imagedata r:id="rId15" o:title="img005"/>
</v:shape>
</w:pict>
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

  var wrapElement = shape.childElements.where((e) => e.name.local == "wrap").firstOrNull ?? xml.XmlElement(xml.XmlName("null"));
  print("wrapElement local name: \${wrapElement.name.local}");
  
  var lockElement = shape.childElements.where((e) => e.name.local == "lock").firstOrNull ?? xml.XmlElement(xml.XmlName("null"));
  print("lockElement local name: \${lockElement.name.local}");
}
