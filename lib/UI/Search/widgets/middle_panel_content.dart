import 'dart:async';

import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_details_loader.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_toolbar.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_full_book_search.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_lazy_book_card_panel.dart';
import 'package:golden_shamela/UI/Search/helpers/indexed_book_library_adapter.dart';
import 'package:golden_shamela/UI/Search/helpers/search_book_subset_builder.dart';
import 'package:golden_shamela/UI/Search/helpers/search_book_collections_loader.dart';
import 'package:golden_shamela/UI/Search/helpers/search_period_range.dart';
import 'package:golden_shamela/UI/Search/models/search_history_record.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';
import 'package:golden_shamela/UI/Search/widgets/authors_table_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/books_list_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/period_filter_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/search_history_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/saved_scopes_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/search_books_pane_chrome.dart';
import 'package:golden_shamela/UI/Search/widgets/sections_list_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/search_select_all_shortcut.dart';
import 'package:path/path.dart' as p;

class MiddlePanelContent extends StatefulWidget {
  final String selectedTab;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final TextEditingController booksSearchController;
  final Set<String> selectedAuthorIds, selectedSectionIds;
  final List<SearchPeriodRange> selectedPeriods;
  final List<Author> authors;
  final List<Section> sections;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final List<Map<String, dynamic>> selectedBooksForSearch;
  final SearchStateSnapshot searchSnapshot;
  final bool isLoadingFilters;
  final Function(String) onAuthorToggled, onAuthorClicked, onSectionClicked;
  final Function() onClearSections, onClearAuthors, onClearBooks;
  final Function(List<String>) onAuthorsAdded, onAuthorsRemoved;
  final Function(List<String>) onBooksAdded, onBooksRemoved;
  final Function(List<String>) onSectionsAdded, onSectionsRemoved;
  final Function(List<SearchPeriodRange>) onPeriodsAdded, onPeriodsRemoved;
  final Function(List<Map<String, dynamic>>) onScopeItemsAdded;
  final void Function(SearchHistoryRecord record, {required bool runSearch})
      onHistoryRecordSelected;
  final String? viewedAuthorId, viewedSectionId;
  final Map<String, String> bookAuthorMap;

  const MiddlePanelContent({
    super.key,
    required this.selectedTab,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.booksSearchController,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    required this.selectedPeriods,
    required this.authors,
    required this.sections,
    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.selectedBooksForSearch,
    required this.searchSnapshot,
    required this.isLoadingFilters,
    required this.onAuthorToggled,
    required this.onClearSections,
    required this.onClearAuthors,
    required this.onClearBooks,
    required this.onAuthorClicked,
    required this.onSectionClicked,
    required this.onAuthorsAdded,
    required this.onAuthorsRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    required this.onSectionsAdded,
    required this.onSectionsRemoved,
    required this.onPeriodsAdded,
    required this.onPeriodsRemoved,
    required this.onScopeItemsAdded,
    required this.onHistoryRecordSelected,
    this.viewedAuthorId,
    this.viewedSectionId,
    this.bookAuthorMap = const {},
  });

  @override
  State<MiddlePanelContent> createState() => _MiddlePanelContentState();
}

class _MiddlePanelContentState extends State<MiddlePanelContent> {
  final _detailsLoader = LibraryBookDetailsLoader();
  final _fullSearch = LibraryFullBookSearch();
  final _collectionsLoader = SearchBookCollectionsLoader();
  final _selectedDetails = ValueNotifier<Future<LibraryBookItem?>?>(null);
  Set<String> _favoritePaths = {};
  List<String> _recentPaths = [];
  Set<String> _fullSearchPaths = {};
  List<String> _visibleBookPaths = const [];
  Set<String> _checkedBookPaths = {};
  LibraryBookItem? _focusedBook;
  Timer? _searchTimer;
  int _searchRevision = 0;
  int _selectAllRequest = 0;
  String _searchScope = 'title_author';
  bool _showCard = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void didUpdateWidget(covariant MiddlePanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTab != oldWidget.selectedTab ||
        widget.viewedAuthorId != oldWidget.viewedAuthorId ||
        widget.viewedSectionId != oldWidget.viewedSectionId) {
      _resetBookSelectionToolbarState();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _selectedDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _tabContent();
    if (!_usesFullWidthBooksToolbar) return content;
    return SearchBooksPaneChrome(
      toolbar: _booksToolbar(),
      showCard: _showCard,
      card: _bookCardPanel(),
      child: content,
    );
  }

  bool get _usesFullWidthBooksToolbar => const {
        'الكتب',
        'المفضلة',
        'مؤخرا',
      }.contains(widget.selectedTab);

  Widget _booksToolbar() {
    return LibraryBooksToolbar(
      searchController: widget.booksSearchController,
      searchScope: _searchScope,
      showCard: _showCard,
      allBooksSelected: _allVisibleBooksSelected,
      visibleBookCount: _visibleBookPaths.length,
      onToggleAllBooks: _requestToggleAllVisibleBooks,
      onToggleCard: _toggleCard,
      onSearchScopeChanged: _setSearchScope,
      onSearchChanged: _onSearchChanged,
    );
  }

  Widget _bookCardPanel() => LibraryLazyBookCardPanel(
        details: _selectedDetails,
      );

  Widget _tabContent() {
    switch (widget.selectedTab) {
      case 'الكتب':
        return SearchSelectAllShortcut(
          onSelectAll: _requestToggleAllVisibleBooks,
          child: _booksPanel(widget.allIndexedBooks),
        );
      case 'المفضلة':
        return _booksPanel(_favoriteBooks);
      case 'مؤخرا':
        return _booksPanel(_recentBooks);
      case 'المؤلفون':
        return AuthorsTablePanel(
          authors: widget.authors,
          selectedAuthorIds: widget.selectedAuthorIds,
          viewedAuthorId: widget.viewedAuthorId,
          onAuthorClicked: widget.onAuthorClicked,
          authorBookCounts: widget.authorBookCounts,
          authorDeathYears: widget.authorDeathYears,
          bookAuthorMap: widget.bookAuthorMap,
          isLoading: widget.isLoadingFilters,
          allIndexedBooks: widget.allIndexedBooks,
          selectedBooks: widget.selectedBooks,
          onAuthorsAdded: widget.onAuthorsAdded,
          onAuthorsRemoved: widget.onAuthorsRemoved,
          onBooksAdded: widget.onBooksAdded,
          onBooksRemoved: widget.onBooksRemoved,
          bookSearchQuery: widget.booksSearchController.text,
          bookSearchScope: _searchScope,
          fullSearchPaths: _fullSearchPaths,
          focusedBookPath: _focusedBook?.bookPath,
          onBookFocused: _focusBook,
          onBookSelectionStateChanged: _setBookSelectionToolbarState,
          selectAllRequest: _selectAllRequest,
          booksToolbar: _booksToolbar(),
          showBookCard: _showCard,
          bookCard: _bookCardPanel(),
        );
      case 'التصنيف':
        return SectionsListPanel(
          sections: widget.sections,
          selectedSectionIds: widget.selectedSectionIds,
          viewedSectionId: widget.viewedSectionId,
          onSectionClicked: widget.onSectionClicked,
          isLoading: widget.isLoadingFilters,
          authors: widget.authors,
          authorDeathYears: widget.authorDeathYears,
          bookAuthorMap: widget.bookAuthorMap,
          allIndexedBooks: widget.allIndexedBooks,
          selectedBooks: widget.selectedBooks,
          onSectionsAdded: widget.onSectionsAdded,
          onSectionsRemoved: widget.onSectionsRemoved,
          onBooksAdded: widget.onBooksAdded,
          onBooksRemoved: widget.onBooksRemoved,
          bookSearchQuery: widget.booksSearchController.text,
          bookSearchScope: _searchScope,
          fullSearchPaths: _fullSearchPaths,
          focusedBookPath: _focusedBook?.bookPath,
          onBookFocused: _focusBook,
          onBookSelectionStateChanged: _setBookSelectionToolbarState,
          selectAllRequest: _selectAllRequest,
          booksToolbar: _booksToolbar(),
          showBookCard: _showCard,
          bookCard: _bookCardPanel(),
        );
      case 'فترة':
        return PeriodFilterPanel(
          selectedPeriods: widget.selectedPeriods,
          onPeriodsAdded: widget.onPeriodsAdded,
          onPeriodsRemoved: widget.onPeriodsRemoved,
        );
      case 'المجالات':
        return SavedScopesPanel(
          currentItems: widget.selectedBooksForSearch,
          currentSnapshot: widget.searchSnapshot,
          onScopeApplied: widget.onScopeItemsAdded,
        );
      case 'السجلات':
        return SearchHistoryPanel(
          onRecordSelected: widget.onHistoryRecordSelected,
        );
      default:
        return Center(
          child: Text(
            'قريباً: ${widget.selectedTab}',
            style: normalStyle(color: Colors.grey),
          ),
        );
    }
  }

  Widget _booksPanel(List<Map<String, dynamic>> books) {
    return BooksListPanel(
      key: ValueKey(widget.selectedTab),
      filteredIndexedBooks: books,
      selectedBooks: widget.selectedBooks,
      searchController: widget.booksSearchController,
      authors: widget.authors,
      authorDeathYears: widget.authorDeathYears,
      bookAuthorMap: widget.bookAuthorMap,
      searchScope: _searchScope,
      fullSearchPaths: _fullSearchPaths,
      focusedBookPath: _focusedBook?.bookPath,
      onBookFocused: _focusBook,
      onSelectionStateChanged: _setBookSelectionToolbarState,
      selectAllRequest: _selectAllRequest,
      onBooksAdded: widget.onBooksAdded,
      onBooksRemoved: widget.onBooksRemoved,
    );
  }

  List<Map<String, dynamic>> get _favoriteBooks =>
      SearchBookSubsetBuilder.favoriteBooks(
        widget.allIndexedBooks,
        _favoritePaths,
      );

  List<Map<String, dynamic>> get _recentBooks =>
      SearchBookSubsetBuilder.recentBooks(widget.allIndexedBooks, _recentPaths);

  Future<void> _loadCollections() async {
    SearchBookCollections collections;
    try {
      collections = await _collectionsLoader.load();
    } catch (_) {
      collections = const SearchBookCollections(favoritePaths: {}, recentPaths: []);
    }
    if (!mounted) return;
    setState(() {
      _favoritePaths = collections.favoritePaths;
      _recentPaths = collections.recentPaths;
    });
  }

  void _focusBook(LibraryBookItem book) {
    if (_focusedBook?.bookPath != book.bookPath) {
      setState(() => _focusedBook = book);
    }
    if (_showCard) _selectedDetails.value = _detailsLoader.load(book);
  }

  void _resetBookSelectionToolbarState() {
    _visibleBookPaths = const [];
    _checkedBookPaths = {};
  }

  bool get _allVisibleBooksSelected =>
      _visibleBookPaths.isNotEmpty &&
      _visibleBookPaths.every(_checkedBookPaths.contains);

  void _setBookSelectionToolbarState({
    required List<String> visibleBookPaths,
    required Set<String> checkedBookPaths,
    required VoidCallback onToggleAll,
  }) {
    if (_sameBookSelectionState(visibleBookPaths, checkedBookPaths)) return;
    setState(() {
      _visibleBookPaths = List.unmodifiable(visibleBookPaths);
      _checkedBookPaths = Set.unmodifiable(checkedBookPaths);
    });
  }

  bool _sameBookSelectionState(List<String> paths, Set<String> checked) =>
      _visibleBookPaths.length == paths.length &&
      _checkedBookPaths.length == checked.length &&
      _checkedBookPaths.containsAll(checked) &&
      List.generate(paths.length, (i) => _visibleBookPaths[i] == paths[i])
          .every((same) => same);

  void _requestToggleAllVisibleBooks() => setState(() => _selectAllRequest++);

  void _toggleCard() {
    setState(() => _showCard = !_showCard);
    if (_showCard) {
      _focusedBook ??= _firstBookForActiveTab();
      final book = _focusedBook;
      _selectedDetails.value = book == null ? null : _detailsLoader.load(book);
    }
  }

  LibraryBookItem? _firstBookForActiveTab() {
    final books = switch (widget.selectedTab) {
      'المفضلة' => _favoriteBooks,
      'مؤخرا' => _recentBooks,
      'الكتب' => widget.allIndexedBooks,
      _ => widget.filteredIndexedBooks,
    };
    final items = IndexedBookLibraryAdapter.toItems(
      books,
      authors: widget.authors,
      bookAuthorMap: widget.bookAuthorMap,
      authorDeathYears: widget.authorDeathYears,
    );
    return items.isEmpty ? null : items.first;
  }

  void _setSearchScope(String value) {
    setState(() => _searchScope = value);
    _scheduleFullSearch();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _scheduleFullSearch();
  }

  String _normalizePath(String path) => p.normalize(path).toLowerCase();

  void _scheduleFullSearch() {
    _searchTimer?.cancel();
    if (_searchScope != 'full') return;
    _searchTimer = Timer(const Duration(milliseconds: 250), _runFullSearch);
  }

  Future<void> _runFullSearch() async {
    final revision = ++_searchRevision;
    Set<String> paths;
    try {
      paths = await _fullSearch.findPaths(widget.booksSearchController.text);
    } catch (_) {
      paths = {};
    }
    if (!mounted || revision != _searchRevision) return;
    setState(() => _fullSearchPaths = paths.map(_normalizePath).toSet());
  }
}
