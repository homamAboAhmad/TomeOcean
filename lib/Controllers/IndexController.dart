import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:xml/xml.dart';

class IndexController {
  final WordDocument _wordDocument;

  IndexController(this._wordDocument);

  void addIndexIfExisted(XmlElement element, int pageNum) {
    final styleEl = element.findAllElements('w:pStyle').firstOrNull;
    if (styleEl == null) return;

    final styleId = styleEl.getAttribute('w:val');
    if (styleId == null || styleId.isEmpty) return;

    final styleName = _resolveStyleName(styleId);
    final headingType = _detectHeadingType(styleName.toLowerCase());
    if (headingType == null) return;

    final rawText = element
        .findAllElements('w:t')
        .map((e) => e.text)
        .join('');
    final text = rawText.replaceAll(_pgMarkerRegex, '').trim();
    if (text.isEmpty) return;

    _wordDocument.index.add(IndexItem(
      title: text,
      page: pageNum,
      type: headingType,
      id: '${pageNum}_${_wordDocument.index.length}',
    ));
  }

  String _resolveStyleName(String styleId) {
    final styleDef = _wordDocument.documentStyles[styleId];
    if (styleDef == null) return styleId;
    final nameEl = styleDef.findAllElements('w:name').firstOrNull;
    if (nameEl == null) return styleId;
    return nameEl.getAttribute('w:val') ?? styleId;
  }

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');
  static final RegExp _headingNumRegex = RegExp(r'heading\s*(\d)');

  String? _detectHeadingType(String styleLower) {
    if (!styleLower.startsWith('heading')) return null;
    final match = _headingNumRegex.firstMatch(styleLower);
    return match != null ? 'Heading${match.group(1)}' : 'Heading1';
  }
}

