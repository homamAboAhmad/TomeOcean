

import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:xml/xml.dart';
class IndexController{
  WordDocument _wordDocument;

  IndexController(this._wordDocument);

  addIndexIfExisted(XmlElement element,int pageNum){
    final styleEl = element.findAllElements('w:pStyle').firstOrNull;
    if (styleEl != null) {
      final styleVal = styleEl.getAttribute('w:val');
      if (styleVal != element && styleVal!.toLowerCase().startsWith('heading')) {
        final text = element.findAllElements('w:t').map((e) => e.text).join('').trim();
        if (text.isNotEmpty) {
          IndexItem item = IndexItem(title: text, page: pageNum, type: styleVal);
          _wordDocument.index.add(item);
          // print(item.title+"${item.page}");
        }
      }
    }
  }
}
