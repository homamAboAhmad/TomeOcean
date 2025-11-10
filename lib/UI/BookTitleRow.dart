import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

import '../Utils/TxtUtils.dart';

class BookTitleRow extends StatefulWidget {
  String title;
  bool isChoosed;
  Function() onClose;
  Function() onTab;

  BookTitleRow(
      {required this.title,
        required this.isChoosed,
      required this.onClose,
      required this.onTab,
      super.key});

  @override
  State<BookTitleRow> createState() => _BookTitleRowState();
}

class _BookTitleRowState extends State<BookTitleRow> {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 96,maxWidth: 180),
      child: Opacity(
        opacity: widget.isChoosed?1.0:0.5,
        child: Material(
          elevation: widget.isChoosed?4:1,
            color: Colors.white,
            // border: Border(top: BorderSide(width: 0.5),left: BorderSide(width: 1),right: BorderSide(width: 1)),
            borderRadius: BorderRadius.only(topRight: Radius.circular(4),topLeft: Radius.circular(4)),

            child: InkWell(
              onTap: widget.onTab,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [bookIconW(),bookTitle(), removeBtn()],
              ),
            ),
        ),
      ),
    );
  }

  bookTitle() {
    String title = shortenTitle(widget.title);
    return Text(
      title,
      style: normalStyle(color: primaryColor),
    );
  }

  removeBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: widget.onClose,
        child: Icon(Icons.cancel,size: 20,color: Colors.redAccent,),
      ),
    );
  }

  bookIconW() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Image.asset("assets/icons/ic_book.png",width: 20,),
    );
    return  ImageIcon(
    AssetImage("assets/icons/ic_book.png",),
    size: 24,
      color: Colors.green,
    );
  }
}
