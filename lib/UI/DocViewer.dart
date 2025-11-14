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
import '../database/search_database_helper.dart';
import '../main.dart';
import '../wordToHTML/AddDocData.dart';
import '../Models/WordDocument.dart';
import '../Models/WordPage.dart'; // Import WordPage

import 'BookSideBar/AuthorBookSideBar.dart';
import 'BookSideBar/BookIndexUI.dart';
import 'BookSideBar/BookSearchUI.dart';
import 'BookSideBar/BooksSideBarIcons.dart';
import 'BookSideBar/SectionBookSideBar.dart';
import 'BooksDrawer.dart';
import 'DocViewer/doc_viewer_bottom_toolbar.dart';
import 'DocViewer/doc_viewer_top_toolbar.dart';
import 'WordPageScreen.dart';

class DocViewer extends StatefulWidget {
  final WordDocument wordDocument;
  final Function(File book) onBookSelected;

  const DocViewer(this.wordDocument, {required this.onBookSelected, super.key});

  @override
  State<DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<DocViewer> with AutomaticKeepAliveClientMixin {
  late BookSideBarController _bookSideBarController;
  late List<Widget> _bookSideBarList;
  Future<WordPage>? _currentPageFuture;

  // New state variables for numerically sorted history
  final Set<int> _visitedPagesSet = {};
  late final TextEditingController _pageNumberController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageNumberController = TextEditingController();
    _initControllerAndSidebar();
    _jumpToPage(widget.wordDocument.currentPage);
  }

  @override
  void dispose() {
    _pageNumberController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordDocument != widget.wordDocument) {
      _initControllerAndSidebar();
      _visitedPagesSet.clear();
      _jumpToPage(widget.wordDocument.currentPage);
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

  void _jumpToPage(int pageIndex) {
    final int totalPages = widget.wordDocument.pageFilePaths.length;

    if (pageIndex < 0) {
      pageIndex = 0; // Clamp to first page
    } else if (pageIndex >= totalPages) {
      pageIndex = totalPages - 1; // Clamp to last page
    }

    widget.wordDocument.currentPage = pageIndex;
    _pageNumberController.text = (pageIndex + 1).toString();
    _visitedPagesSet.add(pageIndex);

    setState(() {
      _currentPageFuture = widget.wordDocument.getPage(pageIndex);
    });
  }

  int? _findPreviousVisited() {
    final sortedVisited = _visitedPagesSet.toList()..sort();
    return sortedVisited.lastWhere((p) => p < widget.wordDocument.currentPage, orElse: () => -1);
  }

  int? _findNextVisited() {
    final sortedVisited = _visitedPagesSet.toList()..sort();
    final nextPage = sortedVisited.firstWhere((p) => p > widget.wordDocument.currentPage, orElse: () => -1);
    return nextPage == -1 ? null : nextPage;
  }

  void _goToPreviousVisitedPage() {
    final page = _findPreviousVisited();
    if (page != null && page != -1) {
      _jumpToPage(page);
    }
  }

  void _goToNextVisitedPage() {
    final page = _findNextVisited();
    if (page != null) {
      _jumpToPage(page);
    }
  }

  void _goTo(int page) {
    _jumpToPage(page - 1);
  }

  void _goNext() {
    if (widget.wordDocument.currentPage < widget.wordDocument.pageFilePaths.length - 1) {
      _jumpToPage(widget.wordDocument.currentPage + 1);
    }
  }

  void _goPrevious() {
    if (widget.wordDocument.currentPage > 0) {
      _jumpToPage(widget.wordDocument.currentPage - 1);
    }
  }

  void _goStart() {
    _jumpToPage(0);
  }

  void _goEnd() {
    _jumpToPage(widget.wordDocument.pageFilePaths.length - 1);
  }

  Future<void> _copyPage() async {
    final WordPage page = await _currentPageFuture!;
    final text = page.text();
    await copyText(text);
    if (mounted) {
      ShowSnackBar(context, "تم النسخ");
    }
  }

  void _onToggleDiacritics() {
    setState(() {
      widget.wordDocument.withDiacritics = !widget.wordDocument.withDiacritics;
    });
  }

  void _onShowBookCard() async {
    final bks = BookCardStorage();
    final bookCard = bks.getBookCardByTitle(widget.wordDocument.title);
    final updated = await showBookCardDialog(context, bookCard);
    if (updated != null) {
      await bks.editBookCard(updated);
    }
  }

  void _onSearchResultTapped(SearchResult result) {
    // Check if the result is in the current book
    if (getFileName(result.bookPath) == widget.wordDocument.title) {
      _jumpToPage(result.pageNumber);
    } else {
      // TODO: Handle opening a different book from search results
      print("Need to switch to book: ${result.bookPath}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The original content structure
        DocViewerTopToolbar(
          wordDocument: widget.wordDocument,
          sideBarIcons: _bookSideBarController.booksSideBarIconsW(),
          onDuplicateBook: _duplicateBook,
          onGoStart: _goStart,
          onGoPrevious: _goPrevious,
          onGoNext: _goNext,
          onGoEnd: _goEnd,
          onCopyPage: _copyPage,
          onToggleDiacritics: _onToggleDiacritics,
          onShowBookCard: _onShowBookCard,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 30.0, bottom: 40.0),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              if (showBookSideBar)
                _bookSideBarList[_bookSideBarController.selecteSideBarP],
              Expanded(
                child: FutureBuilder<WordPage>(
                  future: _currentPageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      return WordPageScreen(
                        snapshot.data!,
                        wordDocument: widget.wordDocument,
                      );
                    } else {
                      return const Center(child: Text('No page selected'));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        DocViewerBottomToolbar(
          wordDocument: widget.wordDocument,
          pageNumberController: _pageNumberController,
          findPreviousVisited: _findPreviousVisited,
          findNextVisited: _findNextVisited,
          goToPreviousVisitedPage: _goToPreviousVisitedPage,
          goToNextVisitedPage: _goToNextVisitedPage,
          jumpToPage: _jumpToPage,
          onSliderChanged: () => setState(() {}),
        ),
      ],
    );
  }

  _duplicateBook() async {
    File? bookFile = await loadBookByName(widget.wordDocument.title);
    if (bookFile != null) widget.onBookSelected(bookFile);
  }
}
