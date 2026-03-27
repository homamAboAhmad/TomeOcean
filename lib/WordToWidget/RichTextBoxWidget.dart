import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';

/// ودجت مسؤول عن استخراج الفقرات `w:p` من عنصر `w:txbxContent` الخاص بـ VML
/// وتمريرها لكلاس `Paragraph` لضمان الحفاظ على تنسيقات الجذور والألوان ونوع الخط.
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
    // 1. الحصول على قائمة الفقرات وتحديد آخر فقرة تحتوي على نص (استبعاد الفقرات الشبحية)
    final allParagraphs = textBoxElement.findAllElements('w:p').toList();
    final lastVisibleIdx = _findLastVisibleParagraphIndex(allParagraphs);

    if (lastVisibleIdx == -1) return const SizedBox.shrink();

    // 2. بناء قائمة العناصر الودجت
    final children = <Widget>[];
    for (int i = 0; i <= lastVisibleIdx; i++) {
      final paragraphWidget = _buildParagraphWidget(allParagraphs[i], isLast: i == lastVisibleIdx);
      if (paragraphWidget != null) {
        children.add(paragraphWidget);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// إيجاد مؤشر آخر فقرة غير فارغة لتمثيل نهاية المحتوى الفعلي
  int _findLastVisibleParagraphIndex(List<XmlElement> paragraphs) {
    for (int i = paragraphs.length - 1; i >= 0; i--) {
      if (paragraphs[i].innerText.trim().isNotEmpty) return i;
    }
    return -1;
  }

  /// بناء الودجت الخاص بالفقرة مع تطبيق قواعد الانهيار للفقرة الأخيرة
  Widget? _buildParagraphWidget(XmlElement element, {required bool isLast}) {
    try {
      final paragraph = Paragraph(wordPage).fromXml(element);

      // في المربعات النصية ذات الحجم الثابت، نلغي تباعد الفقرة الأخيرة لمحاكاة سلوك الوورد
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
