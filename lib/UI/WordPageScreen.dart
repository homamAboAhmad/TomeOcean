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
        '[${wordPage.parent.title}، صفحة ${wordPage.parent.currentPage+1}]';

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
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyC): const CopyWithReferenceIntent(),
        },
        child: Focus(
          autofocus: true,
          child: Center(
            child: CustomInteractiveViewer(
              child: SizedBox(
                height: wordDocument.getPageSectPr().height ?? 1000,
                width: wordDocument.getPageSectPr().width ?? 800,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Stack(
                    children: [
                      pageHeaderW(),
                      widget.wordPage.getPageIamgesWiLi(),
                      Container(
                        margin: getSectionMargins(),
                        child: SingleChildScrollView(
                          child: Column(
                            textDirection: TextDirection.rtl,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              pageContentW(),
                              getSeperator(widget.wordPage.fns.isNotEmpty),
                              footerW()
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          child: Container(
            color: Colors.black,
            height: 1,
            width: 250,
          ),
        ));
  }

  getSectionMargins() {
    return EdgeInsets.only(
      left: wordDocument.getPageSectPr().leftMargin ?? 8.0,
      right: wordDocument.getPageSectPr().rightMargin ?? 8.0,
      top: wordDocument.getPageSectPr().topMargin ?? 8.0,
      bottom: wordDocument.getPageSectPr().bottomMargin ?? 8.0,
    );
  }

  footerW() {
    return Visibility(visible: true, child: widget.wordPage.footerW());
  }

  Widget pageHeaderW() {
    return Padding(
      padding: EdgeInsets.only(
        left: wordDocument.getPageSectPr().leftMargin ?? 8.0,
        right: wordDocument.getPageSectPr().rightMargin ?? 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              child: wordDocument
                  .getPageSectPr()
                  .getSectHeaderWidget(widget.wordPage)),
        ],
      ),
    );
  }

  pageContentW() {
    return widget.wordPage.toWidget();
  }
}
