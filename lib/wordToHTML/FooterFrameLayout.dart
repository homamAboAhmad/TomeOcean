import 'package:flutter/widgets.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';

class FooterFrameLayout {
  static List<Widget> build(List<Paragraph> paragraphs) {
    final widgets = <Widget>[];

    int i = 0;
    while (i < paragraphs.length) {
      final paragraph = paragraphs[i];

      if (_hasFramePr(paragraph)) {
        final framedParagraphs = <Paragraph>[paragraph];
        paragraph.shrinkTextLayerWidth = true;

        int j = i + 1;
        while (j < paragraphs.length && _sameFramePr(paragraphs[j - 1], paragraphs[j])) {
          paragraphs[j].shrinkTextLayerWidth = true;
          framedParagraphs.add(paragraphs[j]);
          j++;
        }

        if (j < paragraphs.length && !_hasFramePr(paragraphs[j])) {
          widgets.add(
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topLeft,
              children: [
                paragraphs[j].toWidget(),
                ...framedParagraphs.map((p) => p.toWidget()),
              ],
            ),
          );
          i = j + 1;
          continue;
        }

        widgets.addAll(framedParagraphs.map((p) => p.toWidget()));
        i = j;
        continue;
      }

      widgets.add(paragraph.toWidget());
      i++;
    }

    return widgets;
  }

  static bool _hasFramePr(Paragraph paragraph) {
    return paragraph.pPr?.xmlpPr?.getElement("w:framePr") != null;
  }

  static bool _sameFramePr(Paragraph a, Paragraph b) {
    final aFrame = a.pPr?.xmlpPr?.getElement("w:framePr");
    final bFrame = b.pPr?.xmlpPr?.getElement("w:framePr");
    if (aFrame == null || bFrame == null) return false;
    return aFrame.toXmlString(pretty: false) == bFrame.toXmlString(pretty: false);
  }
}
