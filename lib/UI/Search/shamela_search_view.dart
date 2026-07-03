import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/BookSideBar/BooksSideBarIcons.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'helpers/search_result_row_helpers.dart';
import 'widgets/no_results_widget.dart';
import 'widgets/save_search_results_bar.dart';
import 'widgets/search_results_table.dart';
import 'widgets/search_results_split_pane.dart';

part 'shamela_search_view_results.dart';

class ShamelaSearchView extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final String searchQuery;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final Function(String bookPath, int pageNumber)? onResultTapped;
  final Function(String query, bool morphologicalSearch) onNewSearch;
  final Function(String bookPath, int pageNumber)? onOpenBookFull;
  final Future<WordDocument?> Function(String bookPath, int pageNumber)?
      onLoadBook;
  final bool isSearching;
  final SearchStateSnapshot searchSnapshot;
  final VoidCallback? onStopSearch;
  final VoidCallback? onNewSearchDialog;
  const ShamelaSearchView({
    super.key,
    required this.results,
    this.totalCount = 0,
    this.searchQuery = '',
    this.searchQueries = const [],
    this.morphologicalSearch = false,
    this.onResultTapped,
    required this.onNewSearch,
    this.onOpenBookFull,
    this.onLoadBook,
    this.isSearching = false,
    this.searchSnapshot = const SearchStateSnapshot(),
    this.onStopSearch,
    this.onNewSearchDialog,
  });

  @override
  State<ShamelaSearchView> createState() => _ShamelaSearchViewState();
}

class _ShamelaSearchViewState extends State<ShamelaSearchView> {
  static const double _rowExtent = 32;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _resultsController = ScrollController();
  WordDocument? _currentDocument;
  String? _currentBookPath;
  int? _selectedIndex;
  bool _isLoadingBook = false;
  bool _resultsHidden = false;
  String? _autoOpenedResultKey;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    _openFirstResultAfterBuild();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _resultsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShamelaSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.results != widget.results && widget.results.isEmpty) {
      _selectedIndex = null;
      _currentDocument = null;
      _currentBookPath = null;
      _isLoadingBook = false;
      _resultsHidden = false;
      _autoOpenedResultKey = null;
      _loadError = null;
    } else if (_selectedIndex != null &&
        _selectedIndex! >= widget.results.length) {
      _selectedIndex = null;
    }
    _openFirstResultAfterBuild();
  }

  void _openFirstResultAfterBuild() {
    if (!AppOtherSettings.instance.draft().openSearchResultOnKeyboardSelection) return;
    final firstKey = _firstResultKey;
    if (widget.results.isEmpty ||
        _selectedIndex != null ||
        _currentDocument != null ||
        firstKey == null ||
        _autoOpenedResultKey == firstKey ||
        _isLoadingBook) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheduledKey = _firstResultKey;
      if (!mounted ||
          widget.results.isEmpty ||
          _selectedIndex != null ||
          _currentDocument != null ||
          scheduledKey == null ||
          _autoOpenedResultKey == scheduledKey ||
          _isLoadingBook) {
        return;
      }
      _autoOpenedResultKey = scheduledKey;
      _showResult(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              ShamelaResultsTopBar(
                count: widget.results.length,
                totalCount: widget.totalCount,
                isSearching: widget.isSearching,
                resultsHidden: _resultsHidden,
                onStopSearch: widget.onStopSearch,
                onNewSearchDialog: widget.onNewSearchDialog,
                onToggleResults: widget.results.isEmpty
                    ? null
                    : () => setState(() => _resultsHidden = !_resultsHidden),
              ),
              Expanded(
                child: SearchResultsSplitPane(
                  bookPane: _buildBookPane(),
                  resultsPanel: this._buildResultsPanel(),
                  resultsHidden: _resultsHidden,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookPane() {
    const paneBackground = Colors.white;
    if (_isLoadingBook) {
      return const ColoredBox(
        color: paneBackground,
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_loadError != null) {
      return ColoredBox(
        color: paneBackground,
        child: Center(
          child: Text(
            _loadError!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_currentDocument != null) {
      return ColoredBox(
        color: paneBackground,
        child: DocViewer(
          _currentDocument!,
          key: ValueKey('${_currentBookPath ?? ''}:${_currentDocument!.currentPage}'),
          onBookSelected: (file) => _showBook(file.path, 0),
        ),
      );
    }

    return ShamelaResultPreviewPane(
      queryLabel: _queryLabel,
      previewResult: _selectedIndex == null || _selectedIndex! >= widget.results.length
          ? (widget.results.isEmpty ? null : widget.results.first)
          : widget.results[_selectedIndex!],
      snippetBuilder: SearchResultRowHelpers.cleanSnippet,
      isSearching: widget.isSearching,
      hasResults: widget.results.isNotEmpty,
    );
  }

  Future<void> _showResult(int index, {bool hideResults = false}) async {
    if (index < 0 || index >= widget.results.length) return;
    final result = widget.results[index];
    final bookPath = (result['bookPath'] ?? result['book_path'])?.toString() ?? '';
    if (bookPath.isEmpty) return;

    final pageNumber =
        SearchResultRowHelpers.asInt(result['pageNumber'] ?? result['page_number']);
    await _showBook(
      bookPath,
      pageNumber,
      selectedIndex: index,
      hideResults: hideResults,
      openCommentPanel: SearchResultRowHelpers.isComment(result),
    );
  }

  void _openResultInFullTab(int index) {
    if (index < 0 || index >= widget.results.length) return;
    final result = widget.results[index];
    final bookPath = (result['bookPath'] ?? result['book_path'])?.toString() ?? '';
    if (bookPath.isEmpty) return;
    final pageNumber =
        SearchResultRowHelpers.asInt(result['pageNumber'] ?? result['page_number']);
    widget.onOpenBookFull?.call(bookPath, pageNumber);
    if (SearchResultRowHelpers.isComment(result)) {
      AppState().openCommentPanelForSearchTarget = true;
    }
  }

  Future<void> _showBook(
    String bookPath,
    int pageNumber, {
    int? selectedIndex,
    bool hideResults = false,
    bool openCommentPanel = false,
  }) async {
    _focusNode.requestFocus();
    if (AppOtherSettings.instance.draft().showSearchBookIndexByDefault) {
      showBookSideBar = true;
    }
    AppState().setSearchHighlight(widget.searchQueries);
    AppState().setSearchTarget(
      pageNumber,
      null,
      openCommentPanel: openCommentPanel,
    );

    if (_currentDocument != null && _currentBookPath == bookPath) {
      setState(() {
        _selectedIndex = selectedIndex;
        _currentDocument!.currentPage = pageNumber;
        _resultsHidden = _resultsHidden || hideResults;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _selectedIndex = selectedIndex;
      _isLoadingBook = true;
      _resultsHidden = _resultsHidden || hideResults;
      _loadError = null;
    });

    final loader = widget.onLoadBook;
    if (loader == null) {
      final open = widget.onOpenBookFull ?? widget.onResultTapped;
      open?.call(bookPath, pageNumber);
      setState(() => _isLoadingBook = false);
      return;
    }

    try {
      final document = await loader(bookPath, pageNumber);
      if (!mounted) return;
      if (document == null) {
        setState(() {
          _isLoadingBook = false;
          _loadError = 'تعذر فتح الكتاب من الكاش.';
        });
        return;
      }
      document.currentPage = pageNumber;
      setState(() {
        _currentDocument = document;
        _currentBookPath = bookPath;
        _isLoadingBook = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBook = false;
        _loadError = 'تعذر فتح الكتاب: $e';
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.results.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      _selectResultByKeyboard(_nextIndex());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      _selectResultByKeyboard(_previousIndex());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _selectedIndex != null) {
      _showResult(_selectedIndex!, hideResults: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectResultByKeyboard(int index) {
    if (_resultsController.hasClients) { final p = _resultsController.position; final top = index * _rowExtent; final bottom = top + _rowExtent; if (top < p.pixels) _resultsController.jumpTo(top); else if (bottom > p.pixels + p.viewportDimension) _resultsController.jumpTo((bottom - p.viewportDimension).clamp(0.0, p.maxScrollExtent)); }
    AppOtherSettings.instance.draft().openSearchResultOnKeyboardSelection
        ? _showResult(index)
        : setState(() => _selectedIndex = index);
  }

  int _nextIndex() => ((_selectedIndex ?? -1) + 1).clamp(0, widget.results.length - 1).toInt();
  int _previousIndex() => ((_selectedIndex ?? widget.results.length) - 1).clamp(0, widget.results.length - 1).toInt();

  void _newSearchFromNoResults() {
    final query = widget.searchQueries.isNotEmpty
        ? widget.searchQueries.first
        : widget.searchQuery;
    widget.onNewSearch(query, widget.morphologicalSearch);
  }

  String get _queryLabel => widget.searchQueries.isNotEmpty ? widget.searchQueries.join(' - ') : widget.searchQuery.trim();
  String? get _firstResultKey => SearchResultRowHelpers.firstKey(widget.results).isEmpty ? null : SearchResultRowHelpers.firstKey(widget.results);
}
