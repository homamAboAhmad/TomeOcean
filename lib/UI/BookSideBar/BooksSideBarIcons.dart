import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

bool showBookSideBar = false;

class BookSideBarController {
  Function setState;
  WordDocument wordDocument;
  int selecteSideBarP = 0;

  BookSideBarController(this.wordDocument, {required this.setState});

  booksSideBarIconsW() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          showBookSideBarW(),
          if (showBookSideBar) ...[
            indexIconW(),
            searchIconW(),
            sectionBooksIconW(),
            autherBooksIconW(),
          ],
        ],
      ),
    );
  }

  showBookSideBarW() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: showBookSideBar
            ? 'إخفاء الشريط الجانبي'
            : 'إظهار الشريط الجانبي',
        child: InkWell(
          onTap: () => setState(() => showBookSideBar = !showBookSideBar),
          child: Container(
            decoration: BoxDecoration(
              color: showBookSideBar ? organicHighlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: LibraryIcon.fromIcon(Icons.view_sidebar, size: showBookSideBar ? 20 : 24),
            ),
          ),
        ),
      ),
    );
  }

  indexIconW() {
    bool isSelected = selecteSideBarP == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: 'فهرس الكتاب',
        child: InkWell(
          onTap: () => setState(() => selecteSideBarP = 0),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? organicHighlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: LibraryIcon.fromIcon(
                Icons.collections_bookmark,
                size: isSelected ? 20 : 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  searchIconW() {
    bool isSelected = selecteSideBarP == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: 'البحث في الكتاب',
        child: InkWell(
          onTap: () => setState(() => selecteSideBarP = 1),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? organicHighlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: LibraryIcon.fromIcon(Icons.search, size: isSelected ? 20 : 24),
            ),
          ),
        ),
      ),
    );
  }

  sectionBooksIconW() {
    bool isSelected = selecteSideBarP == 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: 'كتب القسم',
        child: InkWell(
          onTap: () => setState(() => selecteSideBarP = 2),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? organicHighlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: LibraryIcon.fromIcon(Icons.category, size: isSelected ? 20 : 24),
            ),
          ),
        ),
      ),
    );
  }

  autherBooksIconW() {
    bool isSelected = selecteSideBarP == 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: 'كتب المؤلف',
        child: InkWell(
          onTap: () => setState(() => selecteSideBarP = 3),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? organicHighlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: LibraryIcon.fromIcon(Icons.edit_note_rounded, size: isSelected ? 20 : 24),
            ),
          ),
        ),
      ),
    );
  }
}
