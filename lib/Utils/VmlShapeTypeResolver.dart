import 'package:xml/xml.dart' as xml;

class VmlShapeTypeResolver {
  const VmlShapeTypeResolver._();

  static String resolve(xml.XmlElement shape) {
    final localName = shape.name.local.toLowerCase();
    if (localName != 'shape') {
      return localName;
    }

    final typeRef = shape.getAttribute('type')?.trim();
    if (typeRef == null || typeRef.isEmpty) {
      return localName;
    }

    final normalizedId = typeRef.startsWith('#') ? typeRef.substring(1) : typeRef;
    final pict = shape.parentElement;
    final shapeTypeElement = pict?.childElements.firstWhere(
      (e) => e.name.local.toLowerCase() == 'shapetype' && e.getAttribute('id') == normalizedId,
      orElse: () => xml.XmlElement(xml.XmlName('null')),
    );

    if (shapeTypeElement == null || shapeTypeElement.name.local == 'null') {
      return localName;
    }

    final officeShapeType = shapeTypeElement.getAttribute(
      'spt',
      namespace: 'urn:schemas-microsoft-com:office:office',
    )?.trim();

    switch (officeShapeType) {
      case '110':
        return 'diamond';
      case '202':
        return 'textbox';
      case '75':
        return 'picture';
      default:
        return localName;
    }
  }
}
