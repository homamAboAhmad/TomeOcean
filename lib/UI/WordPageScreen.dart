import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';

import '../main.dart';

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
    return Stack(
      children: [
        Builder(
          builder: (context) {
            var sectPr = wordDocument.getSectPrForPage(
              widget.wordPage.pageIndex,
            );
            var margins = getSectionMargins();
            double flowClearance = widget.wordPage.computeFlowClearance(margins.top);
            double pageHeight = sectPr.height ?? 1000;
            double pageWidth = sectPr.width ?? 800;

            return Center(
                    child: Container(
                      width: pageWidth,
                      constraints: BoxConstraints(
                        minHeight: pageHeight, // الحد الأدنى هو حجم الصفحة
                      ),
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
                      child: ClipRect(
                        child: Stack(
                          children: [
                            // 1. الهيدر (ثابت في الأعلى)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: margins.top,
                                padding: EdgeInsets.symmetric(
                                  horizontal: margins.left,
                                ),
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: sectPr.hasVmlFrameInHeader(widget.wordPage.pageIndex) 
                                        ? (sectPr.headerMargin ?? 0) 
                                        : 0,
                                  ),
                                  child: OverflowBox(
                                    maxHeight: double.infinity,
                                    alignment: Alignment.topCenter,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: pageHeaderW(),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 2. الصور الخلفية (behindDoc=true) - يجب أن تلتزم بحجم الصفحة الأصلي ولا تتأثر بالتمطيط
                            Positioned(
                              top: 0,
                              left: 0,
                              width: pageWidth,
                              height: pageHeight,
                              child: IgnorePointer(
                                child: widget.wordPage.getBackgroundImages(),
                              ),
                            ),

                            // 3. المحتوى + الحواشي (يتحكم في ارتفاع الصفحة)
                            Padding(
                              padding: margins,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Calculate minimum content height (Page Height - Margins)
                                  double minContentHeight =
                                      pageHeight - margins.top - margins.bottom;
                                  // Handle potential negative values
                                  if (minContentHeight < 0)
                                    minContentHeight = 0;

                                  // CASE 1: No footnotes - Return simple layout to avoid IntrinsicHeight overhead/errors
                                  if (widget.wordPage.fns.isEmpty) {
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: minContentHeight,
                                      ),
                                      child: Column(
                                        textDirection: TextDirection.rtl,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [pageContentW(flowClearance)],
                                      ),
                                    );
                                  }

                                  // CASE 2: Has footnotes - Use IntrinsicHeight + Expanded for sticky footer
                                  return ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: minContentHeight,
                                    ),
                                    child: IntrinsicHeight(
                                      child: Column(
                                        textDirection: TextDirection.rtl,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: pageContentW(flowClearance)),
                                          getSeperator(
                                            true,
                                          ), // ✅ فوق الحواشي مباشرة
                                          const SizedBox(height: 5),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight:
                                                  100, // الحد الأدنى المعتدل للحفاظ على التناسق
                                            ),
                                            child: widget.wordPage.footnotesW(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // 4. الفوتر (ثابت في الأسفل)
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
                                child: OverflowBox(
                                  maxHeight: double.infinity,
                                  alignment: Alignment.topCenter,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: footerW(),
                                  ),
                                ),
                              ),
                            ),

                            // 5. الصور الأمامية (behindDoc=false) - يجب أن تلتزم بحجم الصفحة الأصلي
                            Positioned(
                              top: 0,
                              left: 0,
                              width: pageWidth,
                              height: pageHeight,
                              child: IgnorePointer(
                                child: widget.wordPage.getForegroundImages(),
                              ),
                            ),
                          ],
                        ),
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
                  tooltip: 'طباعة فقرات الصفحة',
                ),
              ),
            ],
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
        .getSectPrForPage(widget.wordPage.pageIndex)
        .getHeaderHeight(widget.wordPage);
    double baseTopMargin =
        wordDocument
            .getSectPrForPage(widget.wordPage.pageIndex)
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
              .getSectPrForPage(widget.wordPage.pageIndex)
              .leftMargin ??
          8.0,
      right:
          wordDocument
              .getSectPrForPage(widget.wordPage.pageIndex)
              .rightMargin ??
          8.0,
      top: effectiveTopMargin,
      bottom:
          wordDocument
              .getSectPrForPage(widget.wordPage.pageIndex)
              .bottomMargin ??
          8.0,
    );
  }

  Widget footerW() {
    return widget.wordPage.footerW();
  }

  Widget pageHeaderW() {
    var sectPr = wordDocument.getSectPrForPage(widget.wordPage.pageIndex);
    String pageNumStr = sectPr.calculatePageNumber(
      widget.wordPage.pageIndex,
    );
    return sectPr.getSectHeaderWidget(widget.wordPage, pageNumStr);
  }

  pageContentW(double flowClearance) {
    return widget.wordPage.toWidget(topFlowClearance: flowClearance);
  }
}
