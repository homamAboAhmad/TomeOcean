
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';

import 'BookIndexUI.dart';

bool showBookSideBar = false;

class BookSideBarController{
Function setState;
WordDocument wordDocument;
int selecteSideBarP = 0;

BookSideBarController(this.wordDocument,{required this.setState});

  booksSideBarIconsW() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [showBookSideBarW(),
        if(showBookSideBar)
          ...[
            indexIconW(),
            searchIconW(),
            sectionBooksIconW(),
            autherBooksIconW(),
          ]

        ],
      ),
    );
  }

  showBookSideBarW() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
          onTap: () =>
              setState(() => showBookSideBar = !showBookSideBar),
          child: Container(
              color: showBookSideBar?Colors.grey:Colors.transparent,
              width: 24,
              height: 24,
              child: Center(child: Icon(Icons.view_sidebar,size:showBookSideBar?20:24 ,)))),
    );
  }

  indexIconW() {
    bool isSelected = selecteSideBarP==0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
          onTap: () =>
              setState(() => selecteSideBarP=0),
          child: Container(
              color: isSelected?Colors.grey:Colors.transparent,
              width: 24,
              height: 24,
              child: Center(child: Icon(Icons.collections_bookmark,size:isSelected?20:24 ,)))),
    );
  }

  searchIconW() {
    bool isSelected = selecteSideBarP==1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
          onTap: () =>
              setState(() => selecteSideBarP=1),
          child: Container(
              color: isSelected?Colors.grey:Colors.transparent,
              width: 24,
              height: 24,
              child: Center(child: Icon(Icons.search,size:isSelected?20:24 ,)))),
    );
  }

  sectionBooksIconW() {
    bool isSelected = selecteSideBarP==2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
          onTap: () =>
              setState(() => selecteSideBarP=2),
          child: Container(
              color: isSelected?Colors.grey:Colors.transparent,
              width: 24,
              height: 24,
              child: Center(child: Icon(Icons.category,size:isSelected?20:24 ,)))),
    );
  }

  autherBooksIconW() {
    bool isSelected = selecteSideBarP==3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
          onTap: () =>
              setState(() => selecteSideBarP=3),
          child: Container(
              color: isSelected?Colors.grey:Colors.transparent,
              width: 24,
              height: 24,
              child: Center(child: Icon(Icons.edit_note_rounded,size:isSelected?20:24 ,)))),
    );
  }

}

