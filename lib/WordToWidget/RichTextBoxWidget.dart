import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/ParagraphTable.dart';

/// ودجت مسؤول عن عرض محتوى `w:txbxContent` الخاص بـ VML.
/// هذا المحتوى ليس مقتصراً على الفقرات فقط؛ حسب OOXML فهو يقبل
/// أي عناصر block-level مثل `w:p` و `w:tbl`.
class RichTextBoxWidget extends StatelessWidget {
  final XmlElement textBoxElement;
  final WordPage wordPage;

  const RichTextBoxWidget({
    Key? key,
    required this.textBoxElement,
    required this.wordPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blocks = textBoxElement.childElements
        .where((e) => e.name.local == 'p' || e.name.local == 'tbl')
        .toList();
    final lastVisibleIdx = _findLastVisibleBlockIndex(blocks);

    if (lastVisibleIdx == -1) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i <= lastVisibleIdx; i++) {
      final blockWidget = _buildBlockWidget(
        blocks[i],
        isLast: i == lastVisibleIdx,
      );
      if (blockWidget != null) {
        children.add(blockWidget);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  int _findLastVisibleBlockIndex(List<XmlElement> blocks) {
    for (int i = blocks.length - 1; i >= 0; i--) {
      if (_isVisibleBlock(blocks[i])) return i;
    }
    return -1;
  }

  bool _isVisibleBlock(XmlElement element) {
    if (element.name.local == 'tbl') {
      return element.findAllElements('w:tr').isNotEmpty ||
          element.findAllElements('w:pict').isNotEmpty ||
          element.findAllElements('w:drawing').isNotEmpty ||
          element.innerText.trim().isNotEmpty;
    }

    if (element.name.local == 'p') {
      return element.findAllElements('w:pict').isNotEmpty ||
          element.findAllElements('w:drawing').isNotEmpty ||
          element.innerText.trim().isNotEmpty;
    }

    return false;
  }

  Widget? _buildBlockWidget(XmlElement element, {required bool isLast}) {
    try {
      if (element.name.local == 'tbl') {
        final tableParagraph = ParagraphTable(wordPage);
        tableParagraph.pXml = element;
        tableParagraph.xmlString = element.toXmlString(pretty: false);
        tableParagraph.disableUrlAutoDetection = true;
        tableParagraph.trimTrailingStructuralEmptyCellParagraphs = true;
        return tableParagraph.toWidget(spacingAfterOverride: isLast ? 0 : null);
      }

      final paragraph = Paragraph(wordPage).fromXml(element);
      paragraph.disableUrlAutoDetection = true;

      // داخل text boxes ثابتة الارتفاع، نجنب آخر فقرة توليد فراغ سفلي زائد.
      if (isLast) {
        paragraph.pPr?.spacingAfter = 0;
        paragraph.pPr?.spacingBefore = 0;
      }

      return paragraph.toWidget(suppressParagraphBorder: true);
    } catch (e) {
      return null;
    }
  }
}
