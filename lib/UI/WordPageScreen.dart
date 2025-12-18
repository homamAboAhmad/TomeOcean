import 'dart:typed_data';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';

import '../Constants.dart';
import '../Utils/DirectionWidgetSpan.dart';
import '../Utils/Widgets/ZoomableSecreen.dart';
import '../Utils/colorMap.dart';
import '../main.dart';
import '../wordToHTML/ParagraphHyperLink.dart';

class CopyWithReferenceIntent extends Intent {
  const CopyWithReferenceIntent();
}

class CopyWithReferenceAction extends Action<CopyWithReferenceIntent> {
  final WordPage wordPage;

  CopyWithReferenceAction(this.wordPage);

  @override
  Object? invoke(CopyWithReferenceIntent intent) async {
    // 1. Invoke the standard copy action to get the selected text onto the clipboard.
    // This is a bit of a workaround because there's no direct way to get the
    // selection from an arbitrary SelectableText widget from outside.
    final primaryContext = primaryFocus?.context;
    if (primaryContext == null) return null;

    Actions.invoke(primaryContext, CopySelectionTextIntent.copy);
    // Give the clipboard operation a moment to complete.
    await Future.delayed(const Duration(milliseconds: 50));

    // 2. Read the selected text from the clipboard.
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final selectedText = clipboardData?.text;

    if (selectedText == null || selectedText.isEmpty) {
      return null; // Nothing was selected or copied.
    }

    // 3. Construct the reference string.
    final String reference =
        '[${wordPage.parent.title}، صفحة ${wordPage.parent.currentPage + 1}]';

    // 4. Combine the text and the reference, and update the clipboard.
    final String textWithReference = '$selectedText\n$reference';
    await Clipboard.setData(ClipboardData(text: textWithReference));

    return null;
  }
}

class WordPageScreen extends StatefulWidget {
  WordPage wordPage;
  WordDocument wordDocument;

  WordPageScreen(this.wordPage, {required this.wordDocument, super.key});

  @override
  State<WordPageScreen> createState() => _WordPageScreenState();
}

var widgetSpanKeys;

class _WordPageScreenState extends State<WordPageScreen> {
  late WordDocument wordDocument;
  @override
  Widget build(BuildContext context) {
    wordDocument = widget.wordDocument;
    return Actions(
      actions: <Type, Action<Intent>>{
        CopyWithReferenceIntent: CopyWithReferenceAction(widget.wordPage),
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyC,
          ): const CopyWithReferenceIntent(),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Builder(
                builder: (context) {
                  var sectPr = wordDocument.getSectPrForPage(
                    widget.wordPage.pageIndex - 1,
                  );
                  var margins = getSectionMargins();

                  return Center(
                    child: Container(
                      width: sectPr.width ?? 800,
                      height: sectPr.height ?? 1000, // حجم الصفحة من Word
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 1. الصور الخلفية (behindDoc=true) - خلف كل شيء
                          widget.wordPage.getBackgroundImages(),

                          // 2. الهيدر
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: margins.top,
                              // color: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: margins.left,
                              ),
                              alignment: Alignment
                                  .bottomCenter, // محتوى الهيدر في أسفل الهامش العلوي
                              child: pageHeaderW(),
                            ),
                          ),

                          // 3. المحتوى + الحواشي
                          Positioned(
                            top: margins.top,
                            left: margins.left,
                            right: margins.right,
                            bottom: margins.bottom,
                            child: FittedBox(
                              fit: BoxFit
                                  .scaleDown, // يقلص المحتوى تلقائياً إذا كان أكبر من المساحة
                              alignment: Alignment.topRight, // RTL alignment
                              child: SizedBox(
                                width:
                                    (sectPr.width ?? 800) -
                                    margins.left -
                                    margins.right,
                                child: Column(
                                  textDirection: TextDirection.rtl,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    pageContentW(),
                                    getSeperator(
                                      widget.wordPage.fns.isNotEmpty,
                                    ),
                                    const SizedBox(height: 5),
                                    widget.wordPage.footnotesW(),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 4. رقم الصفحة (الفوتر)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: margins.bottom,
                              padding: EdgeInsets.symmetric(
                                horizontal: margins.left,
                              ),
                              alignment: Alignment.topCenter,
                              child: footerW(),
                            ),
                          ),

                          // 5. الصور الأمامية (behindDoc=false) - فوق كل شيء (تغطي الهيدر والمحتوى)
                          widget.wordPage.getForegroundImages(),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // زر طباعة XML الصفحة
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    widget.wordPage.printPageXml();
                  },
                  backgroundColor: Colors.blue.shade700,
                  child: Icon(Icons.code, color: Colors.white, size: 20),
                  tooltip: 'طباعة XML الصفحة',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getSeperator(bool isVisible) {
    return Visibility(
      visible: isVisible,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(color: Colors.black, height: 1, width: 250),
      ),
    );
  }

  getSectionMargins() {
    // حساب ارتفاع الهيدر (من ملفات الهيدر المنفصلة)
    double headerHeight = wordDocument
        .getSectPrForPage(widget.wordPage.pageIndex - 1)
        .getHeaderHeight(widget.wordPage);
    double baseTopMargin =
        wordDocument
            .getSectPrForPage(widget.wordPage.pageIndex - 1)
            .topMargin ??
        8.0;

    // فحص وجود صور "إطارات" داخل محتوى الصفحة نفسها
    // (صور كبيرة، خلف النص، في بداية الصفحة)
    double framePadding = 0;
    for (var p in widget.wordPage.ps.take(3)) {
      // نفحص أول 3 فقرات فقط
      for (var run in p.runs) {
        if (run.image != null && run.image!.behindDoc) {
          // إذا وجدنا صورة كبيرة (يفترض أنها إطار)، نزيد الهامش العلوي
          // القيمة 80 هي تقدير لسمك الزخرفة العلوية للإطار المعتاد
          if (run.image!.height > 400) {
            framePadding = 60.0;
          }
        }
      }
    }

    // الهامش العلوي الفعال = الأكبر بين (ارتفاع الهيدر) و (الهامش الأصلي) + هامش الإطار إن وجد
    double effectiveTopMargin =
        (headerHeight > baseTopMargin ? headerHeight : baseTopMargin) +
        framePadding;

    // تصحيح إضافي: إذا كان الهامش صغيراً جداً (< 20) ووجدنا إطاراً، نرفعه أكثر
    if (effectiveTopMargin < 40 && framePadding > 0) {
      effectiveTopMargin = 70.0;
    }

    return EdgeInsets.only(
      left:
          wordDocument
              .getSectPrForPage(widget.wordPage.pageIndex - 1)
              .leftMargin ??
          8.0,
      right:
          wordDocument
              .getSectPrForPage(widget.wordPage.pageIndex - 1)
              .rightMargin ??
          8.0,
      top: effectiveTopMargin,
      bottom:
          wordDocument
              .getSectPrForPage(widget.wordPage.pageIndex - 1)
              .bottomMargin ??
          8.0,
    );
  }

  Widget footerW() {
    return widget.wordPage.footerW();
  }

  Widget pageHeaderW() {
    var sectPr = wordDocument.getSectPrForPage(widget.wordPage.pageIndex - 1);
    String pageNumStr = sectPr.calculatePageNumber(
      widget.wordPage.pageIndex - 1,
    );
    return sectPr.getSectHeaderWidget(widget.wordPage, pageNumStr);
  }

  pageContentW() {
    return widget.wordPage.toWidget();
  }
}
