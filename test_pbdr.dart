import 'package:xml/xml.dart';

XmlElement? mergePPr(
  XmlElement? xmlpPr,
  XmlElement? pStyleXml,
  XmlElement? rStyleXml,
) {
  if (pStyleXml == null) return xmlpPr;

  Map<String, XmlElement> currentElementsMap = {};
  xmlpPr?.childElements.forEach((e) {
    currentElementsMap[e.name.local] = e.copy() as XmlElement;
  });
  
  pStyleXml.childElements.forEach((e) {
    if (currentElementsMap[e.name.local] == null)
      currentElementsMap[e.name.local] = e.copy() as XmlElement;
  });

  return XmlElement(
    XmlName.fromString(xmlpPr?.name.toXmlString() ?? "w:pPr"),
    xmlpPr?.attributes.map((a) => a.copy() as XmlAttribute).toList() ?? [],
    currentElementsMap.values,
  );
}

void main() {
  var pPr = XmlDocument.parse('''<w:pPr xmlns:w="w"><w:pBdr><w:top w:val="double" w:sz="4" w:space="1" w:color="auto"/><w:left w:val="double" w:sz="4" w:space="15" w:color="auto"/><w:bottom w:val="double" w:sz="4" w:space="10" w:color="auto"/><w:right w:val="double" w:sz="4" w:space="15" w:color="auto"/></w:pBdr></w:pPr>''').rootElement;
  var pStyle = XmlDocument.parse('''<w:pPr xmlns:w="w"><w:widowControl w:val="0"/></w:pPr>''').rootElement;

  var merged = mergePPr(pPr, pStyle, null);
  print(merged?.toXmlString());
}
