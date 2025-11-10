import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Models/WordDocument.dart';

import '../../Utils/NumberUtils.dart';
import '../../Utils/Widgets/DoubleScrollView.dart';

const HEADING1 = "Heading1";

class BookIndexUI extends StatefulWidget {
  Function(int) goTo;
  WordDocument wordDocument;

  BookIndexUI(this.wordDocument, {super.key,required this.goTo});

  @override
  State<BookIndexUI> createState() => _BookIndexUIState();
}

class _BookIndexUIState extends State<BookIndexUI> {
  Map<IndexItem, List<IndexItem>> subItems = {};
  IndexItem? lastHeading;


  @override
  Widget build(BuildContext context) {
   setIndexMap();
    return SizedBox(
      width: 224,
      height: double.infinity,
      child: DoubleScrollView(
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0, left: 12,top: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...subItems.keys.map((e) => HeadingIndexRow(e)).toList()
            ],
          ),
        ),
      ),
    );
  }

  Widget IndexRow(IndexItem e) {
    bool isSelected = widget.wordDocument.selectedIndexItem ==e.id;
    return InkWell(
        onTap: () {
          widget.wordDocument.selectedIndexItem =e.id;
          goToPage(e.page);
        },
        child: Container(
          color: isSelected?Colors.teal.shade100:Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                getHeadingPadding(e),
                if (isHeading(e)) expandBtn(e),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isHeading(e) ? Icons.folder : Icons.note,
                    size: 20,
                    color: isHeading(e)
                        ? Colors.greenAccent.shade700
                        : Colors.greenAccent.shade400,
                  ),
                ),
                SizedBox(
                  width: 8,
                ),
                Text(
                  e.title /*+ "-" + e.type*/,
                  style: normalStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ));
  }

  goToPage(int page) {
    widget.goTo(page);
    print(page);
  }

  getHeadingPadding(IndexItem e) {
    double width = 0;
    if (isHeading(e))
      width = 0;
    else
      width = 36;

    return SizedBox(
      width: width,
    );
  }

  expandBtn(IndexItem e) {
    bool isExpanded = expandedHeadings.contains(e.title);
    bool canExpand = subItems[e] != null && subItems[e]!.isNotEmpty;
    return SizedBox(
      width: 24,
      child: Visibility(
        visible: canExpand,
        child: InkWell(
            onTap: () => setState(() => isExpanded
                ? expandedHeadings.remove(e.title)
                : expandedHeadings.add(e.title)),
            child: Icon(isExpanded ? Icons.expand_more : Icons.expand_less)),
      ),
    );
  }

  List<String> expandedHeadings = [];

  Widget HeadingIndexRow(IndexItem e) {
    bool isExpanded = expandedHeadings.contains(e.title);
    bool canExpand = subItems[e] != null && subItems[e]!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        IndexRow(e),
        if (isExpanded && canExpand)
          ...subItems[e]!.map((e) => IndexRow(e)).toList()
      ],
    );
  }

  bool isHeading(IndexItem e) {
    bool canExpand = subItems[e] != null && subItems[e]!.isNotEmpty;
    return e.type == HEADING1 && canExpand;
  }

  void setIndexMap() {
    List<IndexItem> index = widget.wordDocument.index;
    subItems.clear();
    for (int i = 0; i < index.length; i++) {
      IndexItem item = index[i];
      if (item.type == HEADING1) {
        lastHeading = item;
        subItems[lastHeading!] = [];
      } else {
        if (lastHeading == null) continue;
        List<IndexItem> l = subItems[lastHeading] ?? [];
        l.add(item);
        subItems[lastHeading!] = l;
      }
    }
  }
}
