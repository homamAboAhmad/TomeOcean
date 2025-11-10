import 'dart:io';

import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';

import '../Dialogs/BookCard/book_card_dialog.dart';
import '../Helpers/BookCardStorage.dart';
import '../Helpers/BookFilesHelper.dart';
import '../Styles/AppResourses.dart';
import '../Utils/CopyPasteText.dart';
import '../Utils/FileToArchive.dart';
import '../Utils/Widgets/ZoomableSecreen.dart';
import '../main.dart';
import '../wordToHTML/AddDocData.dart';
import '../Models/WordDocument.dart';
import 'BookSideBar/AuthorBookSideBar.dart';
import 'BookSideBar/BookIndexUI.dart';
import 'BookSideBar/BookSearchUI.dart';
import 'BookSideBar/BooksSideBarIcons.dart';
import 'BookSideBar/SectionBookSideBar.dart';
import 'BooksDrawer.dart';
import 'WordPageScreen.dart';

class DocViewer extends StatefulWidget {
  final WordDocument wordDocument;
  final Function(File book) onBookSelected;

  const DocViewer(this.wordDocument, {required this.onBookSelected, super.key});

  @override
  State<DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<DocViewer> {
  late BookSideBarController _bookSideBarController;
  late List<Widget> _bookSideBarList;

  @override
  void initState() {
    super.initState();
    _initControllerAndSidebar();
  }

  @override
  void didUpdateWidget(covariant DocViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordDocument != widget.wordDocument) {
      _initControllerAndSidebar();
    }
  }

  void _initControllerAndSidebar() {
    _bookSideBarController =
        BookSideBarController(widget.wordDocument, setState: setState);
    final bookCard =
        BookCardStorage().getBookCardByTitle(widget.wordDocument.title) ??
            BookCard();
    _bookSideBarList = [
      BookIndexUI(widget.wordDocument, goTo: _goTo),
      const BookSearchUI(),
      SectionBookSideBar(
        sectionId: bookCard.sectionId,
        onBookSelected: widget.onBookSelected,
      ),
      AuthorBooksSidebar(
        authorId: bookCard.authorId,
        onBookSelected: widget.onBookSelected,
      ),
    ];
  }

  void _goTo(int page) {
    widget.wordDocument.currentPage = page - 1;
    setState(() {});
  }

  void _goNext() => _updatePage(
      (current) => (current + 1) % widget.wordDocument.pages.length);

  void _goPrevious() => _updatePage((current) =>
      (current - 1 + widget.wordDocument.pages.length) %
      widget.wordDocument.pages.length);

  void _goStart() => _updatePage((_) => 0);

  void _goEnd() => _updatePage((_) => widget.wordDocument.pages.length - 1);

  void _updatePage(int Function(int) newPageCalculator) {
    widget.wordDocument.currentPage =
        newPageCalculator(widget.wordDocument.currentPage);
    setState(() {});
  }

  Future<void> _copyPage() async {
    final text = widget.wordDocument.getCurrentPage().text();
    await copyText(text);
    if (mounted) {
      ShowSnackBar(context, "تم النسخ");
    }
  }

  Widget _buildToolbarButton({
    required VoidCallback onTap,
    required IconData icon,
    bool isSpecial = false,
    Widget? specialWidget,
    Color color = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: isSpecial
          ? specialWidget
          : Icon(
              icon,
              color: color,
              textDirection: TextDirection.rtl,
              size: iconSize,
            ),
    );
  }

  Widget _buildDiacriticsButton() {
    return InkWell(
      onTap: () => setState(() {
        widget.wordDocument.withDiacritics =
            !widget.wordDocument.withDiacritics;
      }),
      child: Material(
        elevation: widget.wordDocument.withDiacritics ? 2 : 0,
        color: widget.wordDocument.withDiacritics ? Colors.grey : bgColor,
        child: Container(
          height: 36,
          width: 36,
          padding: EdgeInsets.all(widget.wordDocument.withDiacritics ? 4 : 0),
          child: Image.asset("assets/icons/ic_diacritics.png"),
        ),
      ),
    );
  }

  Widget _buildBookCardButton() {
    return InkWell(
      onTap: () async {
        final bks = BookCardStorage();
        final bookCard = bks.getBookCardByTitle(widget.wordDocument.title);
        final updated = await showBookCardDialog(context, bookCard);
        if (updated != null) {
          await bks.editBookCard(updated);
        }
      },
      child: const SizedBox(
        height: 36,
        width: 36,
        child: Icon(Icons.note, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildPageNumberCard() {
    return Card(
      child: SizedBox(
        width: 64,
        child: Center(
          child: Text(
            "${widget.wordDocument.currentPage + 1}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildBookTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(widget.wordDocument.title,
          style: normalStyle(color: Colors.black)),
    );
  }

  Widget _buildTopToolbar() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 30,
        width: double.infinity,
        color: bgColor,
        child: Stack(
          children: [
            _bookSideBarController.booksSideBarIconsW(),
            Center(
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarButton(
                      onTap: _duplicateBook, icon: Icons.new_label),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: _goStart, icon: Icons.skip_next),
                  const SizedBox(width: 8),
                  _buildToolbarButton(
                      onTap: _goPrevious, icon: Icons.navigate_before),
                  const SizedBox(width: 8),
                  _buildToolbarButton(
                      onTap: _goNext, icon: Icons.navigate_next),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: _goEnd, icon: Icons.skip_previous),
                  const SizedBox(width: 8),
                  _buildBookTitle(),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: _copyPage, icon: Icons.copy),
                  const SizedBox(width: 8),
                  _buildDiacriticsButton(),
                  const SizedBox(width: 8),
                  _buildBookCardButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: 30,
        color: bgColor,
        child: Center(
          child: _buildPageNumberCard(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildTopToolbar(),
        Padding(
          padding: const EdgeInsets.only(top: 30.0, bottom: 30),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              if (showBookSideBar)
                _bookSideBarList[_bookSideBarController.selecteSideBarP],
              Expanded(
                child: WordPageScreen(
                  widget.wordDocument.getCurrentPage(),
                  wordDocument: widget.wordDocument,
                ),
              ),
            ],
          ),
        ),
        _buildBottomToolbar(),
      ],
    );
  }

  _duplicateBook() async {
    File? bookFile = await loadBookByName(widget.wordDocument.title);
    if (bookFile != null) widget.onBookSelected(bookFile);
  }
}
