import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';

import '../Dialogs/BookCard/book_card_dialog.dart';
import '../Helpers/BookCardStorage.dart';
import '../Helpers/BookFilesHelper.dart';
import '../Controllers/PathController.dart';
import '../Styles/AppResourses.dart';
import '../Utils/CopyPasteText.dart';
import '../Utils/FileToArchive.dart';
import '../Utils/Widgets/ZoomableSecreen.dart';
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

class _DocViewerState extends State<DocViewer>
    with AutomaticKeepAliveClientMixin {
  late BookSideBarController _bookSideBarController;
  List<Widget> _bookSideBarList =
      []; // Initialize to empty list to avoid LateInitializationError

  // New state variables for numerically sorted history
  final Set<int> _visitedPagesSet = {};
  late final TextEditingController _pageNumberController;
  late final ScrollController _scrollController;
  late final ValueNotifier<int> _currentPageNotifier;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageNumberController = TextEditingController();
    _scrollController = ScrollController(); // Initialize ScrollController
    _currentPageNotifier = ValueNotifier(widget.wordDocument.currentPage);
    _initControllerAndSidebar();

    // Register TOC navigation callback
    AppState().onTocNavigate = (pageIndex) {
      _jumpToPage(pageIndex);
    };

    // Initial jump if needed (but usually start at 0)
    if (widget.wordDocument.currentPage > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToPage(widget.wordDocument.currentPage);
      });
    }
  }

  @override
  void dispose() {
    _pageNumberController.dispose();
    _scrollController.dispose(); // Dispose ScrollController
    _currentPageNotifier.dispose();
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

  Future<void> _initControllerAndSidebar() async {
    _bookSideBarController = BookSideBarController(
      widget.wordDocument,
      setState: setState,
    );
    final bookCard =
        await BookCardStorage().getBookCardByTitle(widget.wordDocument.title) ??
        BookCard(title: widget.wordDocument.title);
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
    _currentPageNotifier.value = pageIndex; // Ensure UI updates immediately

    // Update internal state if needed
    // if (mounted) setState(() {}); // interactuall scroll handles this properly via notification
    if (_scrollController.hasClients) {
      // Calculation must match the ListView setup:
      // height = pageHeight + separator(20).
      // We assume uniform page height for now based on the first page.
      double pageHeight =
          (widget.wordDocument.getSectPrForPage(0).height ?? 1000);
      // Ensure uniform behavior with _zoomScale
      double offset = pageIndex * ((pageHeight * _zoomScale) + 20.0);
      _scrollController.jumpTo(offset);
    }
  }

  int? _findPreviousVisited() {
    final sortedVisited = _visitedPagesSet.toList()..sort();
    return sortedVisited.lastWhere(
      (p) => p < widget.wordDocument.currentPage,
      orElse: () => -1,
    );
  }

  int? _findNextVisited() {
    final sortedVisited = _visitedPagesSet.toList()..sort();
    final nextPage = sortedVisited.firstWhere(
      (p) => p > widget.wordDocument.currentPage,
      orElse: () => -1,
    );
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
    if (widget.wordDocument.currentPage <
        widget.wordDocument.pageFilePaths.length - 1) {
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
    final WordPage page = await widget.wordDocument.getPage(
      widget.wordDocument.currentPage,
    );
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
    final bookCard =
        await bks.getBookCardByTitle(widget.wordDocument.title) ??
        BookCard(title: widget.wordDocument.title);

    final updated = await showBookCardDialog(context, bookCard);
    if (updated != null) {
      // Get book path from title (try to find the actual file)
      String? bookPath;
      try {
        final bookFile = await loadBookByName(widget.wordDocument.title);
        bookPath = bookFile?.path;
      } catch (e) {
        print("Error getting book path: $e");
      }

      // If bookPath not found, use title as placeholder (will be updated when book is indexed)
      bookPath ??= '${BOOKS_FOLDER_PATH}\\${widget.wordDocument.title}.docx';

      await bks.editBookCard(updated, bookPath);
    }
  }

  double _zoomScale = 0.75;

  void _handleZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlLeft,
        )) {
      setState(() {
        if (event.scrollDelta.dy < 0) {
          _zoomScale += 0.1;
        } else {
          _zoomScale -= 0.1;
        }
        _zoomScale = _zoomScale.clamp(0.5, 3.0); // Limits: 50% to 300%
      });
    }
  }

  double _baseScale = 1.0;

  void _zoomIn() {
    setState(() {
      _zoomScale += 0.1;
      _zoomScale = _zoomScale.clamp(0.5, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale -= 0.1;
      _zoomScale = _zoomScale.clamp(0.5, 3.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.equal, control: true): _zoomIn,
        const SingleActivator(LogicalKeyboardKey.add, control: true): _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
            _zoomOut,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            DocViewerTopToolbar(
              wordDocument: widget.wordDocument,
              sideBarIcons: _bookSideBarController.booksSideBarIconsW(),
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
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
              padding: const EdgeInsets.only(top: 48.0, bottom: 52.0),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  if (showBookSideBar &&
                      _bookSideBarList.isNotEmpty &&
                      _bookSideBarController.selecteSideBarP <
                          _bookSideBarList.length)
                    _bookSideBarList[_bookSideBarController.selecteSideBarP],
                  Expanded(
                    child: GestureDetector(
                      onScaleStart: (details) {
                        _baseScale = _zoomScale;
                      },
                      onScaleUpdate: (details) {
                        setState(() {
                          _zoomScale = (_baseScale * details.scale).clamp(
                            0.5,
                            3.0,
                          );
                        });
                      },
                      child: Listener(
                        onPointerSignal: _handleZoom,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              // Calculate current page based on scroll offset
                              double pageBaseHeight =
                                  (widget.wordDocument
                                      .getSectPrForPage(0)
                                      .height ??
                                  1000);
                              double pageTotalHeight =
                                  (pageBaseHeight * _zoomScale) +
                                  20.0; // Scaled height + spacing

                              int newPageIndex =
                                  (_scrollController.offset / pageTotalHeight)
                                      .round();

                              if (newPageIndex !=
                                      widget.wordDocument.currentPage &&
                                  newPageIndex >= 0 &&
                                  newPageIndex <
                                      widget
                                          .wordDocument
                                          .pageFilePaths
                                          .length) {
                                widget.wordDocument.currentPage = newPageIndex;
                                _pageNumberController.text = (newPageIndex + 1)
                                    .toString();
                                _visitedPagesSet.add(newPageIndex);
                                _currentPageNotifier.value =
                                    newPageIndex; // Notify toolbar to update
                              }
                            }
                            return false;
                          },
                          child: Container(
                            color: Colors.grey.shade200,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate base page width (using first page or default)
                                double pageBaseWidth =
                                    (widget.wordDocument
                                        .getSectPrForPage(0)
                                        .width ??
                                    800);
                                double scaledContentWidth =
                                    (pageBaseWidth * _zoomScale) +
                                    40.0; // + padding

                                // Determine the width of the ListView: max of screen width or content width
                                double listViewWidth =
                                    constraints.maxWidth > scaledContentWidth
                                    ? constraints.maxWidth
                                    : scaledContentWidth;

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const ClampingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: SizedBox(
                                      width: listViewWidth,
                                      child: Scrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: true,
                                        trackVisibility: true,
                                        child: ListView.separated(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                            horizontal: 10,
                                          ),
                                          itemCount: widget
                                              .wordDocument
                                              .pageFilePaths
                                              .length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(height: 20),
                                          itemBuilder: (context, index) {
                                            return PageItemLoader(
                                              wordDocument: widget.wordDocument,
                                              pageIndex: index,
                                              zoomScale: _zoomScale,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, value, child) {
                return DocViewerBottomToolbar(
                  wordDocument: widget.wordDocument,
                  pageNumberController: _pageNumberController,
                  findPreviousVisited: _findPreviousVisited,
                  findNextVisited: _findNextVisited,
                  goToPreviousVisitedPage: _goToPreviousVisitedPage,
                  goToNextVisitedPage: _goToNextVisitedPage,
                  jumpToPage: _jumpToPage,
                  // Force UI update on slider change as we now rely on scroll offset
                  onSliderChanged: (value) => _jumpToPage(value.round() - 1),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  _duplicateBook() async {
    File? bookFile = await loadBookByName(widget.wordDocument.title);
    if (bookFile != null) widget.onBookSelected(bookFile);
  }
}

class PageItemLoader extends StatefulWidget {
  final WordDocument wordDocument;
  final int pageIndex;
  final double zoomScale;

  const PageItemLoader({
    super.key,
    required this.wordDocument,
    required this.pageIndex,
    required this.zoomScale,
  });

  @override
  State<PageItemLoader> createState() => _PageItemLoaderState();
}

class _PageItemLoaderState extends State<PageItemLoader>
    with AutomaticKeepAliveClientMixin {
  late Future<WordPage> _pageFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageFuture = widget.wordDocument.getPage(widget.pageIndex);
  }

  @override
  void didUpdateWidget(covariant PageItemLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.wordDocument != widget.wordDocument) {
      _pageFuture = widget.wordDocument.getPage(widget.pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for KeepAlive

    // Determine if horizontal scrolling is needed
    var sectPr = widget.wordDocument.getSectPrForPage(widget.pageIndex);
    double width = sectPr.width ?? 800;
    double contentWidth = width * widget.zoomScale;
    double screenWidth = MediaQuery.of(context).size.width;
    double baseW = width;
    double baseH = sectPr.height ?? 1000;

    ScrollPhysics horizontalPhysics = contentWidth > screenWidth
        ? const ClampingScrollPhysics()
        : const NeverScrollableScrollPhysics();

    return Container(
      constraints: BoxConstraints(minWidth: screenWidth),
      child: Center(
        child: FutureBuilder<WordPage>(
          future: _pageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: baseW * widget.zoomScale,
                height: baseH * widget.zoomScale,
                color: Colors.white,
                child: const Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return Container(
                width: baseW * widget.zoomScale,
                height: baseH * widget.zoomScale,
                color: Colors.white,
                child: Center(child: Text('Error: ${snapshot.error}')),
              );
            } else if (snapshot.hasData) {
              return Container(
                width: baseW * widget.zoomScale,
                height: baseH * widget.zoomScale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: baseW,
                    height: baseH,
                    child: WordPageScreen(
                      snapshot.data!,
                      wordDocument: widget.wordDocument,
                    ),
                  ),
                ),
              );
            } else {
              return SizedBox(
                height: baseH * widget.zoomScale,
                width: baseW * widget.zoomScale,
              );
            }
          },
        ),
      ),
    );
  }
}
