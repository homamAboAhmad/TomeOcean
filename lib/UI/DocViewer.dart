import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Helpers/PageCommentsRepository.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookPositionStore.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';

import '../Helpers/BookCardStorage.dart';
import '../Helpers/BookFilesHelper.dart';
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
import 'DocViewer/page_comment_panel.dart';
import 'DocViewer/page_viewport_tracker.dart';
import 'DocViewer/doc_viewer_top_toolbar.dart';
import 'LibraryCommon/library_book_card_dialog.dart';
import 'Settings/app_citation_settings.dart';
import 'WordPageScreen.dart';
import 'clipboard_post_processor.dart';
import 'custom_context_menu.dart';
import '../Utils/Widgets/SelectionAutoScroller.dart';

class DocViewer extends StatefulWidget {
  final WordDocument wordDocument;
  final Function(File book) onBookSelected;
  final VoidCallback? onCloseBook;
  final VoidCallback? onPageChanged;

  const DocViewer(
    this.wordDocument, {
    required this.onBookSelected,
    this.onCloseBook,
    this.onPageChanged,
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
  late final TextEditingController _commentController;
  late final ScrollController _scrollController;
  late final ValueNotifier<int> _currentPageNotifier;
  late final DocZoomController _zoomController;
  late final PageViewportTracker _pageViewportTracker;
  final PageCommentsRepository _commentsRepository =
      PageCommentsRepository.instance;
  final FocusNode _searchFocusNode = FocusNode();
  final Map<int, GlobalKey> _pageItemKeys = {};
  final Map<String, GlobalKey> _paragraphItemKeys = {};
  bool _commentPanelOpen = false;
  bool _commentPinned = false;
  bool _commentDirty = false;
  bool _commentSaving = false;
  bool _handlingScrolledPage = false;
  double _commentPanelFraction = 0.25;
  int _commentPageIndex = 0;
  String _savedCommentText = '';
  final List<String> _commentUndoStack = [];
  final List<String> _commentRedoStack = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageNumberController = TextEditingController();
    _pageNumberController.text = widget.wordDocument
        .displayPageNumberForPage(widget.wordDocument.currentPage)
        .toString();
    _commentController = TextEditingController();
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
      unawaited(_jumpToPage(pageIndex));
    };

    // Initial jump if needed (but usually start at 0)
    if (widget.wordDocument.currentPage > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_jumpToPage(widget.wordDocument.currentPage));
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCommentForPage(widget.wordDocument.currentPage);
      });
    }
  }

  @override
  void dispose() {
    _pageNumberController.dispose();
    _commentController.dispose();
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
      _resetCommentState();
      unawaited(_jumpToPage(widget.wordDocument.currentPage));
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
        onNavigateToPage: (page) => unawaited(_jumpToPage(page)),
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

  Future<void> _jumpToPage(int pageIndex) async {
    final int totalPages = widget.wordDocument.pageFilePaths.length;

    if (pageIndex < 0) {
      pageIndex = 0; // Clamp to first page
    } else if (pageIndex >= totalPages) {
      pageIndex = totalPages - 1; // Clamp to last page
    }

    if (!await _canLeaveComment()) return;
    _applyPageChange(pageIndex);
    await _loadCommentForPage(pageIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageViewportTracker.jumpToPage(
        pageIndex: pageIndex,
        pageKeys: _pageItemKeys,
        onSettled: () => _scrollToSearchTargetWithinPage(pageIndex),
      );
    });
  }

  void _applyPageChange(int pageIndex, {bool programmatic = true}) {
    widget.wordDocument.currentPage = pageIndex;
    widget.wordDocument.prefetchPages(pageIndex);
    _pageNumberController.text =
        widget.wordDocument.displayPageNumberForPage(pageIndex).toString();
    _visitedPagesSet.add(pageIndex);
    _currentPageNotifier.value = pageIndex; // Ensure UI updates immediately
    unawaited(BookPositionStore.instance.save(
      _commentBookPath,
      widget.wordDocument.openSource,
      pageIndex,
    ));
    widget.onPageChanged?.call();
    if (programmatic) {
      _pageViewportTracker.beginProgrammaticJump();
    }
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
      unawaited(_jumpToPage(page));
    }
  }

  void _goToNextVisitedPage() {
    final page = _findNextVisited();
    if (page != null) {
      unawaited(_jumpToPage(page));
    }
  }

  void _goTo(int page) {
    unawaited(_jumpToPage(page - 1));
  }

  void _goNext() {
    if (widget.wordDocument.currentPage <
        widget.wordDocument.pageFilePaths.length - 1) {
      unawaited(_jumpToPage(widget.wordDocument.currentPage + 1));
    }
  }

  void _goPrevious() {
    if (widget.wordDocument.currentPage > 0) {
      unawaited(_jumpToPage(widget.wordDocument.currentPage - 1));
    }
  }

  void _goStart() {
    unawaited(_jumpToPage(0));
  }

  void _goEnd() {
    unawaited(_jumpToPage(widget.wordDocument.pageFilePaths.length - 1));
  }

  void _goToCurrentPageEdge(double alignment) {
    final context = _pageItemKeys[widget.wordDocument.currentPage]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<void> _copyPage() async {
    final WordPage page = await widget.wordDocument.getPage(
      widget.wordDocument.currentPage,
    );
    final text = page.text().trim();
    final int pageNum = widget.wordDocument.displayPageNumberForPage(
      widget.wordDocument.currentPage,
    );
    final String formatted = CitationFormatter.format(
      text: text,
      bookTitle: widget.wordDocument.title,
      pageNumber: pageNum,
    );
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
    await showLibraryBookCardDialog(
      context,
      title: widget.wordDocument.title,
    );
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

  String get _commentBookPath {
    return widget.wordDocument.sourcePath ??
        AppStoragePaths.bookSourcePath(
          AppStoragePaths.bookIdFromTitle(widget.wordDocument.title),
        );
  }

  Future<void> _loadCommentForPage(int pageIndex) async {
    final forceOpen = _consumeCommentSearchTarget(pageIndex);
    final comment = await _commentsRepository.load(_commentBookPath, pageIndex);
    if (!mounted || pageIndex != widget.wordDocument.currentPage) return;
    final text = comment?.content ?? '';
    setState(() {
      _commentPageIndex = pageIndex;
      _savedCommentText = text;
      _commentController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _commentDirty = false;
      _commentUndoStack
        ..clear()
        ..add(text);
      _commentRedoStack.clear();
      _commentPanelOpen = forceOpen || _commentPinned || text.trim().isNotEmpty;
    });
  }

  bool _consumeCommentSearchTarget(int pageIndex) {
    final appState = AppState();
    final open = appState.openCommentPanelForSearchTarget &&
        appState.searchTargetPageIndex == pageIndex;
    if (open) appState.openCommentPanelForSearchTarget = false;
    return open;
  }

  void _resetCommentState() {
    _commentPanelOpen = false;
    _commentPinned = false;
    _commentDirty = false;
    _commentSaving = false;
    _commentPageIndex = widget.wordDocument.currentPage;
    _savedCommentText = '';
    _commentController.clear();
    _commentUndoStack.clear();
    _commentRedoStack.clear();
  }

  Future<bool> _canLeaveComment() async {
    if (!_commentDirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعليق غير محفوظ'),
        content: const Text('احفظ التعليق قبل الانتقال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('تجاهل'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _saveComment();
      return !_commentDirty;
    }
    return action == 'discard';
  }

  Future<void> _saveComment() async {
    if (_commentSaving) return;
    setState(() => _commentSaving = true);
    final text = _commentController.text;
    try {
      await _commentsRepository.save(
        bookPath: _commentBookPath,
        bookName: widget.wordDocument.title,
        pageIndex: _commentPageIndex,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _savedCommentText = text.trimRight();
        _commentDirty = false;
        if (!_commentPinned && _savedCommentText.trim().isEmpty) {
          _commentPanelOpen = false;
        }
      });
    } catch (e) {
      if (mounted) ShowSnackBar(context, 'تعذر حفظ التعليق: $e');
    } finally {
      if (mounted) setState(() => _commentSaving = false);
    }
  }

  Future<void> _toggleCommentPanel() async {
    if (_commentPanelOpen) {
      if (!await _canLeaveComment()) return;
      setState(() {
        _commentPinned = false;
        _commentPanelOpen = false;
      });
      return;
    }
    setState(() => _commentPanelOpen = true);
  }

  void _onCommentChanged(String value) {
    if (_commentUndoStack.isEmpty || _commentUndoStack.last != value) {
      _commentUndoStack.add(value);
      _commentRedoStack.clear();
    }
    setState(() => _commentDirty = value.trimRight() != _savedCommentText);
  }

  void _undoComment() {
    if (_commentUndoStack.length < 2) return;
    _commentRedoStack.add(_commentUndoStack.removeLast());
    _setCommentTextFromHistory(_commentUndoStack.last);
  }

  void _redoComment() {
    if (_commentRedoStack.isEmpty) return;
    final text = _commentRedoStack.removeLast();
    _commentUndoStack.add(text);
    _setCommentTextFromHistory(text);
  }

  void _setCommentTextFromHistory(String text) {
    setState(() {
      _commentController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _commentDirty = text.trimRight() != _savedCommentText;
    });
  }

  void _resizeCommentPanel(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    setState(() {
      _commentPanelFraction =
          (_commentPanelFraction - details.delta.dy / screenHeight)
              .clamp(0.15, 0.50)
              .toDouble();
    });
  }

  void _handleScrolledToPage(int newPageIndex) {
    if (_handlingScrolledPage) return;
    _handlingScrolledPage = true;
    final oldPageIndex = widget.wordDocument.currentPage;
    () async {
      if (!await _canLeaveComment()) {
        await _jumpToPage(oldPageIndex);
        _handlingScrolledPage = false;
        return;
      }
      _applyPageChange(newPageIndex, programmatic: false);
      await _loadCommentForPage(newPageIndex);
      _handlingScrolledPage = false;
    }();
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
          const SingleActivator(LogicalKeyboardKey.home, control: true):
              () => _goToCurrentPageEdge(0),
          const SingleActivator(LogicalKeyboardKey.end, control: true):
              () => _goToCurrentPageEdge(1),
          const SingleActivator(LogicalKeyboardKey.escape): _closeCurrentBook,
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
                  final commentHeight = _commentPanelOpen
                      ? MediaQuery.of(context).size.height *
                          _commentPanelFraction
                      : 0.0;
                  return Padding(
                    padding: EdgeInsets.only(
                      top: 48.0,
                      bottom: 52.0 + commentHeight,
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
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
                                    _handleScrolledToPage(newPageIndex);
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
                        if (showBookSideBar &&
                            _bookSideBarList.isNotEmpty &&
                            _bookSideBarController.selecteSideBarP <
                                _bookSideBarList.length)
                          _bookSideBarList[_bookSideBarController
                              .selecteSideBarP],
                      ],
                    ),
                  );
                },
              ),
              if (_commentPanelOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 52),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height *
                          _commentPanelFraction,
                      width: double.infinity,
                      child: Column(
                        children: [
                          GestureDetector(
                            onVerticalDragUpdate: _resizeCommentPanel,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeUpDown,
                              child: Container(
                                height: 6,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Expanded(
                            child: PageCommentPanel(
                              controller: _commentController,
                              pinned: _commentPinned,
                              dirty: _commentDirty,
                              canUndo: _commentUndoStack.length > 1,
                              canRedo: _commentRedoStack.isNotEmpty,
                              isSaving: _commentSaving,
                              onUndo: _undoComment,
                              onRedo: _redoComment,
                              onTogglePinned: () => setState(
                                () => _commentPinned = !_commentPinned,
                              ),
                              onSave: _saveComment,
                              onClose: () => unawaited(_toggleCommentPanel()),
                              onChanged: _onCommentChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    jumpToPage: (page) => unawaited(_jumpToPage(page)),
                    // Force UI update on slider change as we now rely on scroll offset
                    onSliderChanged: (value) =>
                        unawaited(_jumpToPage(value.round() - 1)),
                    commentPanelOpen: _commentPanelOpen,
                    onToggleCommentPanel: () =>
                        unawaited(_toggleCommentPanel()),
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
    final renderDocument = widget.wordDocument.documentForPage(widget.pageIndex);
    final localPageIndex = widget.wordDocument.localPageIndexForPage(
      widget.pageIndex,
    );
    var sectPr = renderDocument.getSectPrForPage(localPageIndex);
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
                            () async {
                              final text = await ClipboardPostProcessor
                                  .postProcessClipboard(wp);
                              if (text.isNotEmpty) {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: CitationFormatter.formatCopiedText(text),
                                  ),
                                );
                              }
                            },
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
                                pageNumber: widget.wordDocument
                                    .displayPageNumberForPage(widget.pageIndex),
                                contextMenuAnchors:
                                    selectableRegionState.contextMenuAnchors,
                                wordPage: snapshot.data!,
                              );
                            },
                        child: WordPageScreen(
                          snapshot.data!,
                          wordDocument: renderDocument,
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
