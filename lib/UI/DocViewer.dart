import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';

import '../Dialogs/BookCard/book_card_dialog.dart';
import '../Helpers/BookCardStorage.dart';
import '../Helpers/BookFilesHelper.dart';
import '../Services/AppStoragePaths.dart';
import '../Styles/AppResourses.dart';
import '../Utils/CopyPasteText.dart';
import '../Utils/FileToArchive.dart';
import '../main.dart';
import '../wordToHTML/AddDocData.dart';
import '../Models/WordDocument.dart';
import '../Models/WordPage.dart'; // Import WordPage
import '../Controllers/DocZoomController.dart';

import 'BookSideBar/AuthorBookSideBar.dart';
import 'BookSideBar/BookIndexUI.dart';
import 'BookSideBar/BookSearchUI.dart';
import 'BookSideBar/BooksSideBarIcons.dart';
import 'BookSideBar/SectionBookSideBar.dart';
import 'BooksDrawer.dart';
import 'DocViewer/doc_viewer_bottom_toolbar.dart';
import 'DocViewer/page_viewport_tracker.dart';
import 'DocViewer/doc_viewer_top_toolbar.dart';
import 'WordPageScreen.dart';
import 'clipboard_post_processor.dart';
import 'custom_context_menu.dart';
import '../Utils/Widgets/SelectionAutoScroller.dart';

class DocViewer extends StatefulWidget {
  final WordDocument wordDocument;
  final Function(File book) onBookSelected;
  final VoidCallback? onCloseBook;

  const DocViewer(
    this.wordDocument, {
    required this.onBookSelected,
    this.onCloseBook,
    super.key,
  });

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
  late final DocZoomController _zoomController;
  late final PageViewportTracker _pageViewportTracker;
  final FocusNode _searchFocusNode = FocusNode();
  final Map<int, GlobalKey> _pageItemKeys = {};
  final Map<String, GlobalKey> _paragraphItemKeys = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageNumberController = TextEditingController();
    _scrollController = ScrollController(); // Initialize ScrollController
    _currentPageNotifier = ValueNotifier(widget.wordDocument.currentPage);
    _zoomController = DocZoomController();
    _pageViewportTracker = PageViewportTracker(
      scrollController: _scrollController,
      totalPages: () => widget.wordDocument.pageFilePaths.length,
      zoomScale: () => _zoomController.value,
      basePageHeightFor: (pageIndex) =>
          widget.wordDocument.getSectPrForPage(pageIndex).height ?? 1000,
    );
    _zoomController.addListener(_handleZoomChanged);
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
    _zoomController.removeListener(_handleZoomChanged);
    _zoomController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleZoomChanged() {
    _pageViewportTracker.clearMeasurements();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageViewportTracker.capturePageMetrics(
        pageKeys: _pageItemKeys,
        pageIndex: widget.wordDocument.currentPage,
      );
    });
  }

  @override
  void didUpdateWidget(covariant DocViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordDocument != widget.wordDocument) {
      _initControllerAndSidebar();
      _visitedPagesSet.clear();
      _pageViewportTracker.clearMeasurements();
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
      BookSearchUI(
        wordDocument: widget.wordDocument,
        onNavigateToPage: _jumpToPage,
        searchFocusNode: _searchFocusNode,
      ),
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
    widget.wordDocument.prefetchPages(pageIndex);
    _pageNumberController.text = (pageIndex + 1).toString();
    _visitedPagesSet.add(pageIndex);
    _currentPageNotifier.value = pageIndex; // Ensure UI updates immediately
    _pageViewportTracker.beginProgrammaticJump();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageViewportTracker.jumpToPage(
        pageIndex: pageIndex,
        pageKeys: _pageItemKeys,
        onSettled: () => _scrollToSearchTargetWithinPage(pageIndex),
      );
    });
  }

  GlobalKey _getPageItemKey(int pageIndex) {
    return _pageItemKeys.putIfAbsent(pageIndex, () => GlobalKey());
  }

  GlobalKey _getParagraphItemKey(int pageIndex, int paragraphIndex) {
    final key = '$pageIndex:$paragraphIndex';
    return _paragraphItemKeys.putIfAbsent(key, () => GlobalKey());
  }

  void _handlePageReady(int pageIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageViewportTracker.capturePageMetrics(
        pageKeys: _pageItemKeys,
        pageIndex: pageIndex,
      );
      _scrollToSearchTargetWithinPage(pageIndex);
    });
  }

  void _scrollToSearchTargetWithinPage(int pageIndex) {
    if (!mounted || !_scrollController.hasClients) return;

    final appState = AppState();
    if (appState.searchTargetPageIndex != pageIndex) return;

    final paragraphIndex = appState.searchTargetParagraphIndex;
    if (paragraphIndex == null) return;

    final targetContext =
        _paragraphItemKeys['$pageIndex:$paragraphIndex']?.currentContext;
    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.18,
      duration: Duration.zero,
    );
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
    final text = page.text().trim();
    final int pageNum = widget.wordDocument.currentPage + 1;
    final String formatted =
        '«$text» [${widget.wordDocument.title} (ص $pageNum)]';
    await copyText(formatted);
    if (mounted) {
      ShowSnackBar(context, "تم النسخ");
    }
  }

  void _onToggleDiacritics() {
    setState(() {
      widget.wordDocument.withDiacritics = !widget.wordDocument.withDiacritics;
    });
  }

  void _onToggleNumerals() {
    setState(() {
      widget.wordDocument.useArabicNumerals =
          !widget.wordDocument.useArabicNumerals;
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
      bookPath ??= AppStoragePaths.bookSourcePath(widget.wordDocument.title);

      await bks.editBookCard(updated, bookPath);
    }
  }

  void _openInBookSearch() {
    setState(() {
      showBookSideBar = true;
      _bookSideBarController.selecteSideBarP = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeCurrentBook() {
    widget.onCloseBook?.call();
  }

  void _closeSearchPanel() {
    if (showBookSideBar && _bookSideBarController.selecteSideBarP == 1) {
      setState(() => showBookSideBar = false);
      AppState().clearSearchHighlight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.wordDocument.isLoading,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<String?>(
                  valueListenable: widget.wordDocument.loadingMessage,
                  builder: (context, msg, _) {
                    return Text(
                      msg ?? 'جاري التحميل...',
                      style: normalStyle(color: secondaryColor, fontSize: 18),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<double?>(
                  valueListenable: widget.wordDocument.loadingProgress,
                  builder: (context, progress, _) {
                    return Column(
                      children: [
                        SizedBox(
                          width: 250,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                secondaryColor,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: normalStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }

        return child!;
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.equal, control: true):
              _zoomController.zoomIn,
          const SingleActivator(LogicalKeyboardKey.add, control: true):
              _zoomController.zoomIn,
          const SingleActivator(LogicalKeyboardKey.minus, control: true):
              _zoomController.zoomOut,
          const SingleActivator(
            LogicalKeyboardKey.numpadSubtract,
            control: true,
          ): _zoomController.zoomOut,
          const SingleActivator(LogicalKeyboardKey.digit0, control: true):
              _zoomController.resetZoom,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _openInBookSearch,
          const SingleActivator(LogicalKeyboardKey.keyW, control: true):
              _closeCurrentBook,
          const SingleActivator(LogicalKeyboardKey.escape): _closeSearchPanel,
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              DocViewerTopToolbar(
                wordDocument: widget.wordDocument,
                sideBarIcons: _bookSideBarController.booksSideBarIconsW(),
                onZoomIn: _zoomController.zoomIn,
                onZoomOut: _zoomController.zoomOut,
                onDuplicateBook: _duplicateBook,
                onGoStart: _goStart,
                onGoPrevious: _goPrevious,
                onGoNext: _goNext,
                onGoEnd: _goEnd,
                onCopyPage: _copyPage,
                onToggleDiacritics: _onToggleDiacritics,
                onToggleNumerals: _onToggleNumerals,
                onShowBookCard: _onShowBookCard,
              ),
              ValueListenableBuilder<double>(
                valueListenable: _zoomController,
                builder: (context, currentZoom, child) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48.0, bottom: 52.0),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        if (showBookSideBar &&
                            _bookSideBarList.isNotEmpty &&
                            _bookSideBarController.selecteSideBarP <
                                _bookSideBarList.length)
                          _bookSideBarList[_bookSideBarController
                              .selecteSideBarP],
                        Expanded(
                          child: Listener(
                            onPointerPanZoomStart:
                                _zoomController.handlePanZoomStart,
                            onPointerPanZoomUpdate:
                                _zoomController.handlePanZoomUpdate,
                            onPointerSignal:
                                _zoomController.handlePointerSignal,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollUpdateNotification) {
                                  if (_pageViewportTracker
                                      .suppressScrollTracking) {
                                    return false;
                                  }

                                  int newPageIndex = _pageViewportTracker
                                      .resolveCurrentPageFromScroll(
                                        _scrollController.offset,
                                      );

                                  if (newPageIndex !=
                                          widget.wordDocument.currentPage &&
                                      newPageIndex >= 0 &&
                                      newPageIndex <
                                          widget
                                              .wordDocument
                                              .pageFilePaths
                                              .length) {
                                    widget.wordDocument.currentPage =
                                        newPageIndex;
                                    widget.wordDocument.prefetchPages(
                                      newPageIndex,
                                    );
                                    _pageNumberController.text =
                                        (newPageIndex + 1).toString();
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
                                        (pageBaseWidth * currentZoom) +
                                        40.0; // + padding

                                    // Determine the width of the ListView: max of screen width or content width
                                    double listViewWidth =
                                        constraints.maxWidth >
                                            scaledContentWidth
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
                                          child: SelectionAutoScroller(
                                            scrollController: _scrollController,
                                            child: Scrollbar(
                                              controller: _scrollController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              child: ListView.separated(
                                                controller: _scrollController,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 20,
                                                      horizontal: 10,
                                                    ),
                                                itemCount: widget
                                                    .wordDocument
                                                    .pageFilePaths
                                                    .length,
                                                separatorBuilder:
                                                    (context, index) =>
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                itemBuilder: (context, index) {
                                                  return KeyedSubtree(
                                                    key: _getPageItemKey(index),
                                                    child: PageItemLoader(
                                                      wordDocument: widget
                                                          .wordDocument,
                                                      pageIndex: index,
                                                      zoomScale: currentZoom,
                                                      paragraphKeyBuilder: (
                                                        paragraphIndex,
                                                      ) => _getParagraphItemKey(
                                                        index,
                                                        paragraphIndex,
                                                      ),
                                                      onPageReady:
                                                          _handlePageReady,
                                                    ),
                                                  );
                                                },
                                              ),
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
                      ],
                    ),
                  );
                },
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
  final GlobalKey? Function(int paragraphIndex)? paragraphKeyBuilder;
  final ValueChanged<int>? onPageReady;

  const PageItemLoader({
    super.key,
    required this.wordDocument,
    required this.pageIndex,
    required this.zoomScale,
    this.paragraphKeyBuilder,
    this.onPageReady,
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.onPageReady?.call(widget.pageIndex);
                }
              });
              return Container(
                width: baseW * widget.zoomScale,
                constraints: BoxConstraints(
                  minHeight: baseH * widget.zoomScale,
                ),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: baseW,
                    constraints: BoxConstraints(minHeight: baseH),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyC &&
                            HardwareKeyboard.instance.isControlPressed) {
                          // Let Flutter's default Ctrl+C happen first,
                          // then post-process clipboard to add paragraph breaks
                          final wp = snapshot.data!;
                          Future.delayed(
                            const Duration(milliseconds: 100),
                            () => ClipboardPostProcessor.postProcessClipboard(wp),
                          );
                        }
                        return KeyEventResult.ignored;
                      },
                      child: SelectionArea(
                        contextMenuBuilder:
                            (
                              context,
                              selectableRegionState,
                            ) {
                              return CustomContextMenu(
                                state: selectableRegionState,
                                bookTitle: widget.wordDocument.title,
                                pageNumber: widget.pageIndex + 1,
                                contextMenuAnchors:
                                    selectableRegionState.contextMenuAnchors,
                                wordPage: snapshot.data!,
                              );
                            },
                        child: WordPageScreen(
                          snapshot.data!,
                          wordDocument: widget.wordDocument,
                          paragraphKeyBuilder: widget.paragraphKeyBuilder,
                        ),
                      ),
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
