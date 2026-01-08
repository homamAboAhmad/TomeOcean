import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:path/path.dart' as p;
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/Search/widgets/search_options_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/sidebar_navigation.dart';
import 'package:golden_shamela/UI/Search/widgets/bottom_bar.dart';
import 'package:golden_shamela/UI/Search/widgets/results_view.dart';
import 'package:golden_shamela/UI/Search/widgets/middle_panel_content.dart';
import 'package:golden_shamela/UI/Search/helpers/search_state_manager.dart';
import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/UI/Search/helpers/selected_books_manager.dart';
import 'package:golden_shamela/UI/Search/widgets/search_dialog_builder.dart';
import 'package:golden_shamela/UI/Search/helpers/search_callbacks_helper.dart';
import 'package:golden_shamela/UI/Search/helpers/search_operation_controller.dart';
import 'package:golden_shamela/UI/Search/helpers/book_selection_logic.dart';
import 'package:golden_shamela/UI/Search/widgets/no_results_bottom_sheet.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:flutter/services.dart';

/// Main search window widget for Shamela search functionality.
///
/// This widget provides a comprehensive search interface with:
/// - Multiple search query groups (AND, OR, NOT)
/// - Advanced search options (morphological, affix, etc.)
/// - Book/Author/Section filtering and selection
/// - Results display and navigation
class ShamelaSearchWindow extends StatefulWidget {
  /// Callback invoked when a search result is tapped.
  final Function(String, int)? onResultTapped;

  /// Callback invoked when a search is requested with parameters.
  final Function(Map<String, dynamic>)? onSearchRequested;

  /// List of all indexed books available for search.
  final List<Map<String, dynamic>> indexedBooks;

  const ShamelaSearchWindow({
    Key? key,
    this.onResultTapped,
    this.onSearchRequested,
    required this.indexedBooks,
  }) : super(key: key);

  @override
  _ShamelaSearchWindowState createState() => _ShamelaSearchWindowState();
}

class _ShamelaSearchWindowState extends State<ShamelaSearchWindow> {
  final Map<String, List<TextEditingController>> _groupControllers = {
    'and': List.generate(5, (_) => TextEditingController()),
    'or': List.generate(5, (_) => TextEditingController()),
    'not': List.generate(5, (_) => TextEditingController()),
  };
  bool _morphologicalSearch = false, _affixSearch = false;
  bool _considerHamzas = false,
      _considerDiacritics = false,
      _considerNumbers = true;
  bool _allPhrasesRequired = false, _ordered = false, _proximity = false;
  // Note: 'comment' is excluded as the feature is under development
  final Map<String, bool> _searchSections = {
    'main': true,
    'footnote': true,
    'title': false,
  };
  String _searchGrouping = 'all';
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  int _totalCount = 0;
  String? _errorMessage;
  bool _hasSearched = false;
  late Map<String, bool> _selectedBooks;
  List<Map<String, dynamic>> _filteredIndexedBooks = [];
  final SearchStateManager _stateManager = SearchStateManager();
  final SearchExecutor _searchExecutor = SearchExecutor();
  final SelectedBooksManager _selectedBooksManager = SelectedBooksManager();
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();
  late final SearchOperationController _searchOperationController;
  late final BookSelectionLogic _bookSelectionLogic;
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  Set<String> _selectedAuthorIds = {}, _selectedSectionIds = {};
  String? _viewedAuthorId;
  String? _viewedSectionId;
  bool _isLoadingFilters = false;
  Map<String, int> _authorBookCounts = {};
  Map<String, String> _authorDeathYears = {};
  Map<String, String> _bookAuthorMap = {};
  String _selectedSidebarTab = 'المؤلفون';
  final TextEditingController _booksSearchController = TextEditingController();
  final TextEditingController _selectedBooksSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _selectedBooksForSearch = [];

  @override
  void initState() {
    super.initState();
    _filteredIndexedBooks = widget.indexedBooks;
    _selectedBooks = {
      for (var b in widget.indexedBooks) b['book_path'] as String: false,
    };
    _searchOperationController = SearchOperationController(
      searchExecutor: _searchExecutor,
      metadataDb: _metadataDb,
    );
    _bookSelectionLogic = BookSelectionLogic(
      searchExecutor: _searchExecutor,
      metadataDb: _metadataDb,
    );
    _loadFilterData();
  }

  @override
  void dispose() {
    for (var group in _groupControllers.values) {
      for (var c in group) c.dispose();
    }
    _booksSearchController.dispose();
    _selectedBooksSearchController.dispose();
    super.dispose();
  }

  /// Loads filter data including authors, sections, and book-author mappings.
  ///
  /// Sets [_isLoadingFilters] to true during loading and false when complete.
  /// Handles errors gracefully by setting loading state to false.
  Future<void> _loadFilterData() async {
    setState(() => _isLoadingFilters = true);
    try {
      final filterData = await _stateManager.loadFilterData();
      setState(() {
        _allAuthors = filterData.authors;
        _allSections = filterData.sections;
        _authorBookCounts = filterData.authorBookCounts;
        _authorDeathYears = filterData.authorDeathYears;
        _isLoadingFilters = false;
      });

      final bookAuthorMap = await _metadataDb.getAllBookAuthorMappings();
      if (mounted) {
        setState(() {
          _bookAuthorMap = bookAuthorMap;
        });
      }
    } catch (e) {
      // Error handling: Reset loading state and continue
      // In production, consider showing an error message to the user
      if (mounted) {
        setState(() => _isLoadingFilters = false);
      }
    }
  }

  /// Updates the filtered books list based on selected authors and sections.
  ///
  /// Syncs the selected books state and updates the UI accordingly.
  /// Falls back to all indexed books if an error occurs.
  Future<void> _updateFilteredBooks() async {
    try {
      final result = await _stateManager.updateFilteredBooks(
        selectedAuthorIds: _selectedAuthorIds,
        selectedSectionIds: _selectedSectionIds,
        allIndexedBooks: widget.indexedBooks,
      );
      setState(() {
        _filteredIndexedBooks = result.filteredBooks;
        final newSelectedBooks = <String, bool>{};
        for (var b in _filteredIndexedBooks) {
          final bookPath = b['book_path'] as String;
          newSelectedBooks[bookPath] = _selectedBooks[bookPath] ?? false;
        }
        _selectedBooks = newSelectedBooks;
      });
      _syncSelectedBooksWithSearchList();
    } catch (e) {
      // Error handling: Fall back to all books
      if (mounted) {
        setState(() => _filteredIndexedBooks = widget.indexedBooks);
      }
    }
  }

  /// Adds books to the selected list for search.
  ///
  /// Filters out books that are already in the selected list.
  Future<void> _addBooksToSelectedList(List<String> bookPaths) async {
    try {
      final newItems = await _selectedBooksManager.addBooksToSelectedList(
        bookPaths,
        _allAuthors,
        _authorDeathYears,
      );

      final filtered = newItems
          .where(
            (item) => !_selectedBooksForSearch.any(
              (e) =>
                  e['type'] == item['type'] &&
                  e['bookPath'] == item['bookPath'],
            ),
          )
          .toList();

      if (filtered.isNotEmpty) {
        setState(() => _selectedBooksForSearch.addAll(filtered));
        _syncSelectedBooksWithSearchList();
      }
    } catch (e) {
      print('Error in _addBooksToSelectedList: $e');
    }
  }

  /// Adds an author and their books to the selected list for search.
  ///
  /// Skips if the author is already in the selected list.
  Future<void> _addAuthorToSelectedList(String authorId) async {
    if (_selectedBooksForSearch.any(
      (item) => item['type'] == 'author' && item['authorId'] == authorId,
    ))
      return;
    final author = _allAuthors.firstWhere(
      (a) => a.id == authorId,
      orElse: () => Author(id: '', name: '', description: ''),
    );
    if (author.id.isEmpty) return;
    final result = await _selectedBooksManager.addAuthorToSelectedList(
      authorId,
      author,
      _authorDeathYears[authorId],
      _filteredIndexedBooks,
    );
    setState(() => _selectedBooksForSearch.add(result['authorItem']));
    final paths = result['bookPaths'] as List;
    if (paths.isNotEmpty) {
      _addBooksToSelectedList(paths.cast<String>());
    } else {
      _syncSelectedBooksWithSearchList();
    }
  }

  /// Adds sections to the selected list for search.
  ///
  /// Skips sections that are already in the selected list.
  Future<void> _addSectionsToSelectedList(List<String> sectionIds) async {
    if (sectionIds.isEmpty) return;

    setState(() {
      for (var sectionId in sectionIds) {
        if (_selectedBooksForSearch.any(
          (item) => item['type'] == 'section' && item['sectionId'] == sectionId,
        )) {
          continue;
        }

        final section = _allSections.firstWhere(
          (s) => s.id == sectionId,
          orElse: () => Section(id: '', title: ''),
        );

        if (section.id.isNotEmpty) {
          _selectedBooksForSearch.add({
            'type': 'section',
            'name': section.title,
            'sectionId': sectionId,
            'bookPath': null,
            'authorId': null,
          });
        }
      }
    });
  }

  /// Adds multiple authors to the selected list.
  ///
  /// Processes each author sequentially.
  Future<void> _addAuthorsToSelectedList(List<String> authorIds) async {
    for (var authorId in authorIds) {
      await _addAuthorToSelectedList(authorId);
    }
  }

  /// Removes authors from the selected list and syncs the book selection.
  void _removeAuthorsFromSelectedList(List<String> authorIds) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'author' && authorIds.contains(item['authorId']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  /// Removes sections from the selected list and syncs the book selection.
  void _removeSectionsFromSelectedList(List<String> sectionIds) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'section' && sectionIds.contains(item['sectionId']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  /// Removes books from the selected list and syncs the selection state.
  void _removeBooksFromSelectedList(List<String> bookPaths) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'book' && bookPaths.contains(item['bookPath']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  /// Removes items from the selected list by their indices.
  ///
  /// Sorts indices in descending order to avoid index shifting issues.
  void _removeFromSelectedList(List<int> indices) {
    setState(() {
      indices.sort((a, b) => b.compareTo(a));
      for (var i in indices) {
        if (i >= 0 && i < _selectedBooksForSearch.length)
          _selectedBooksForSearch.removeAt(i);
      }
    });
    _syncSelectedBooksWithSearchList();
  }

  /// Clears the entire selected list and syncs the book selection state.
  void _clearSelectedList() {
    setState(() => _selectedBooksForSearch.clear());
    _syncSelectedBooksWithSearchList();
  }

  /// Synchronizes the selected books state with the search list.
  ///
  /// Updates [_selectedBooks] based on books in [_selectedBooksForSearch]
  /// and books from selected authors.
  void _syncSelectedBooksWithSearchList() {
    setState(() {
      final bookPathsInSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'book' && item['bookPath'] != null)
          .map((item) => item['bookPath'] as String)
          .toSet();

      final authorIdsInSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'author' && item['authorId'] != null)
          .map((item) => item['authorId'] as String)
          .toSet();

      final bookPathsFromAuthors = <String>{};
      for (var book in _filteredIndexedBooks) {
        final bookPath = book['book_path'] as String;
        final authorId = book['authorId'] as String?;
        if (authorId != null && authorIdsInSearch.contains(authorId)) {
          bookPathsFromAuthors.add(bookPath);
        }
      }

      final allBookPathsInSearch = bookPathsInSearch.union(
        bookPathsFromAuthors,
      );

      for (var bookPath in _selectedBooks.keys) {
        _selectedBooks[bookPath] = allBookPathsInSearch.contains(bookPath);
      }

      for (var book in _filteredIndexedBooks) {
        final bookPath = book['book_path'] as String;
        if (!_selectedBooks.containsKey(bookPath)) {
          _selectedBooks[bookPath] = allBookPathsInSearch.contains(bookPath);
        }
      }
    });
  }

  /// Performs the search operation with current parameters.
  ///
  /// Executes the search locally and updates results. Also sends search params
  /// via [onSearchRequested] callback if provided. Returns early if no queries are provided.
  /// Sets [_errorMessage] if an error occurs during the process.
  Future<void> _performSearch() async {
    if (!_searchOperationController.hasSearchQueries(_groupControllers)) {
      return;
    }

    _initializeSearchState();

    try {
      final booksToSearch = await _bookSelectionLogic.determineBooksToSearch(
        selectedBooksForSearch: _selectedBooksForSearch,
        filteredIndexedBooks: _filteredIndexedBooks,
        allIndexedBooks: widget.indexedBooks,
        selectedBooks: _selectedBooks,
      );
      final selectedSections = _searchOperationController.getSelectedSections(
        _searchSections,
      );
      final result = await _searchOperationController.executeSearch(
        groupControllers: _groupControllers,
        searchGrouping: _searchGrouping,
        booksToSearch: booksToSearch,
        selectedSections: selectedSections,
        searchSections: _searchSections,
        morphologicalSearch: _morphologicalSearch,
        affixSearch: _affixSearch,
        considerHamzas: _considerHamzas,
        considerDiacritics: _considerDiacritics,
        considerNumbers: _considerNumbers,
        allPhrasesRequired: _allPhrasesRequired,
        ordered: _ordered,
        proximity: _proximity,
      );

      _updateSearchResults(result);
      _handleNoResults(result);
      _sendSearchParamsIfNeeded();
    } catch (e) {
      _handleSearchError(e);
    } finally {
      _finalizeSearchState();
    }
  }

  /// Initializes the search state before performing search.
  void _initializeSearchState() {
    setState(() {
      _isLoading = true;
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
      _hasSearched = true;
    });
  }

  /// Updates the search results state.
  void _updateSearchResults(SearchResult result) {
    setState(() {
      _results = result.results;
      _totalCount = result.totalCount;
    });
  }

  /// Handles the case when no results are found.
  void _handleNoResults(SearchResult result) {
    if (result.results.isEmpty && result.totalCount == 0 && mounted) {
      NoResultsBottomSheet.show(context);
    }
  }

  /// Sends search parameters via callback if results exist and callback is provided.
  void _sendSearchParamsIfNeeded() {
    if (widget.onSearchRequested == null || _results.isEmpty) {
      return;
    }

    final groupControllersMap = _searchOperationController
        .buildGroupControllersMap(_groupControllers);
    final searchParams = _searchOperationController.buildSearchParams(
      groupControllersMap: groupControllersMap,
      searchGrouping: _searchGrouping,
      selectedBooksForSearch: _selectedBooksForSearch,
      searchSections: _searchSections,
      morphologicalSearch: _morphologicalSearch,
      affixSearch: _affixSearch,
      considerHamzas: _considerHamzas,
      considerDiacritics: _considerDiacritics,
      considerNumbers: _considerNumbers,
      allPhrasesRequired: _allPhrasesRequired,
      ordered: _ordered,
      proximity: _proximity,
      indexedBooks: widget.indexedBooks,
    );
    widget.onSearchRequested!(searchParams);
  }

  /// Handles search errors.
  void _handleSearchError(dynamic error) {
    if (mounted) {
      setState(() {
        _errorMessage = "خطأ في البحث: $error";
        _results = [];
        _totalCount = 0;
      });
    }
  }

  /// Finalizes the search state after search completion.
  void _finalizeSearchState() {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Adds a new query field to the specified group at the given index.
  void _addQueryField(String groupKey, int index) {
    setState(() {
      _groupControllers[groupKey]!.insert(index, TextEditingController());
    });
  }

  /// Removes a query field from the specified group at the given index.
  ///
  /// Ensures at least one field remains in each group.
  void _removeQueryField(String groupKey, int index) {
    setState(() {
      if (_groupControllers[groupKey]!.length > 1) {
        _groupControllers[groupKey]![index].dispose();
        _groupControllers[groupKey]!.removeAt(index);
      }
    });
  }

  /// Builds the search options panel widget.
  Widget _buildSearchOptionsPanel() {
    return SearchOptionsPanel(
      searchSections: _searchSections,
      onSearchSectionChanged: (key, value) =>
          setState(() => _searchSections[key] = value),
      morphologicalSearch: _morphologicalSearch,
      affixSearch: _affixSearch,
      considerHamzas: _considerHamzas,
      considerDiacritics: _considerDiacritics,
      considerNumbers: _considerNumbers,
      onAdvancedOptionChanged: SearchCallbacksHelper.createAdvancedCallback(
        setMorphological: (v) => setState(() => _morphologicalSearch = v),
        setAffix: (v) => setState(() => _affixSearch = v),
        setHamzas: (v) => setState(() => _considerHamzas = v),
        setDiacritics: (v) => setState(() => _considerDiacritics = v),
        setNumbers: (v) => setState(() => _considerNumbers = v),
      ),
      allPhrasesRequired: _allPhrasesRequired,
      ordered: _ordered,
      proximity: _proximity,
      onPhraseOptionChanged: SearchCallbacksHelper.createPhraseCallback(
        setAllPhrases: (v) => setState(() => _allPhrasesRequired = v),
        setOrdered: (v) => setState(() => _ordered = v),
        setProximity: (v) => setState(() => _proximity = v),
      ),
      groupControllers: _groupControllers,
      onAddQueryField: _addQueryField,
      onRemoveQueryField: _removeQueryField,
      onSearch: _performSearch,
      onClear: () {
        for (var group in _groupControllers.values) {
          for (var c in group) c.clear();
        }
        setState(() {
          _results = [];
          _totalCount = 0;
          _hasSearched = false;
        });
      },
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      totalCount: _totalCount,
      selectedBooksForSearch: _selectedBooksForSearch,
      onRemoveFromSelectedList: _removeFromSelectedList,
      onClearSelectedList: _clearSelectedList,
      selectedBooksSearchController: _selectedBooksSearchController,
      searchGrouping: _searchGrouping,
      onSearchGroupingChanged: (value) =>
          setState(() => _searchGrouping = value),
    );
  }

  /// Gets the filtered books list based on the current search query.
  ///
  /// Returns all filtered books if search query is empty,
  /// otherwise filters by book title.
  List<Map<String, dynamic>> _getFilteredBooks() {
    final q = _booksSearchController.text.toLowerCase();
    return q.isEmpty
        ? _filteredIndexedBooks
        : _filteredIndexedBooks
              .where(
                (b) => p
                    .basenameWithoutExtension(b['book_path'] as String)
                    .toLowerCase()
                    .contains(q),
              )
              .toList();
  }

  /// Builds the middle panel content widget (books/authors/sections).
  Widget _buildMiddlePanelContent() {
    return MiddlePanelContent(
      selectedTab: _selectedSidebarTab,
      filteredIndexedBooks: _filteredIndexedBooks,
      allIndexedBooks: widget.indexedBooks,
      selectedBooks: _selectedBooks,
      onBookSelectionChanged: (bookPath, value) {
        setState(() {
          _selectedBooks[bookPath] = value;
        });
      },
      onClearBooks: () {
        setState(() {
          for (var book in _getFilteredBooks()) {
            _selectedBooks[book['book_path'] as String] = false;
          }
        });
      },

      booksSearchController: _booksSearchController,
      selectedAuthorIds: _selectedAuthorIds,
      selectedSectionIds: _selectedSectionIds,
      authors: _allAuthors,
      sections: _allSections,
      authorBookCounts: _authorBookCounts,
      authorDeathYears: _authorDeathYears,
      isLoadingFilters: _isLoadingFilters,
      onAuthorToggled: (id) {
        setState(() {
          // Handle both authors and sections (MiddlePanelContent reuses this for sections)
          if (_selectedAuthorIds.contains(id)) {
            _selectedAuthorIds.remove(id);
          } else if (_selectedSectionIds.contains(id)) {
            _selectedSectionIds.remove(id);
          } else {
            // Check if it's an author ID or section ID by checking which list contains it
            final isAuthor = _allAuthors.any((a) => a.id == id);
            if (isAuthor) {
              _selectedAuthorIds.add(id);
            } else {
              _selectedSectionIds.add(id);
            }
          }
        });
        _updateFilteredBooks();
      },

      onClearAuthors: () {
        setState(() => _selectedAuthorIds = {});
        _updateFilteredBooks();
      },
      onClearSections: () {
        setState(() => _selectedSectionIds.clear());
        _updateFilteredBooks();
      },
      onAuthorClicked: (authorId) {
        setState(() => _viewedAuthorId = authorId);
      },
      onSectionClicked: (sectionId) {
        setState(() => _viewedSectionId = sectionId);
      },
      onAuthorsAdded: _addAuthorsToSelectedList,
      onAuthorsRemoved: _removeAuthorsFromSelectedList,
      onBooksAdded: _addBooksToSelectedList,
      onBooksRemoved: _removeBooksFromSelectedList,
      onSectionsAdded: _addSectionsToSelectedList,
      onSectionsRemoved: _removeSectionsFromSelectedList,
      viewedAuthorId: _viewedAuthorId,
      viewedSectionId: _viewedSectionId,
      bookAuthorMap: _bookAuthorMap,
      onSelectAll: _handleSelectAll,
      onSelectAllAuthors: _handleSelectAllAuthors,
      onSelectAllBooks: () {
        // This callback will be handled by AuthorsTablePanel/SectionsListPanel
        // They know which books are visible
      },
      onSelectAllSections: _handleSelectAllSections,
    );
  }

  /// Builds the bottom bar widget with selection actions.
  ///
  /// Only shows deselect buttons since selection is handled in the panels.
  Widget _buildBottomBar() {
    return SearchBottomBar(
      selectedTab: _selectedSidebarTab,
      selectedAuthorIds: _selectedAuthorIds,
      selectedSectionIds: _selectedSectionIds,
      selectedBooks: _selectedBooks,
      filteredIndexedBooks: _filteredIndexedBooks,
      onDeselectAllBooks: () {
        final paths = _selectedBooks.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList();
        setState(() {
          for (var path in paths) {
            _selectedBooks[path] = false;
            _selectedBooksForSearch.removeWhere(
              (item) => item['type'] == 'book' && item['bookPath'] == path,
            );
          }
        });
      },
      onDeselectAllAuthors: () {
        final ids = _selectedAuthorIds.toList();
        setState(() {
          _selectedAuthorIds.clear();
          for (var id in ids) {
            _selectedBooksForSearch.removeWhere(
              (item) =>
                  (item['type'] == 'author' || item['type'] == 'book') &&
                  item['authorId'] == id,
            );
          }
        });
        _updateFilteredBooks();
      },
      onDeselectAllSections: () {
        setState(() => _selectedSectionIds.clear());
        _updateFilteredBooks();
      },
      onIgnore: () {
        _clearSelectedList();
        setState(() {
          _selectedBooks.clear();
          _selectedAuthorIds.clear();
          _selectedSectionIds.clear();
        });
      },
      totalAuthors: _allAuthors.length,
    );
  }

  /// Handles select all action based on the current sidebar tab.
  ///
  /// Selects all items in the active tab (books, authors, or sections).
  void _handleSelectAll() {
    switch (_selectedSidebarTab) {
      case 'الكتب':
        setState(() {
          for (var book in _getFilteredBooks()) {
            _selectedBooks[book['book_path'] as String] = true;
          }
        });
        break;
      case 'المؤلفون':
        setState(() {
          _selectedAuthorIds = _allAuthors.map((a) => a.id).toSet();
        });
        _updateFilteredBooks();
        break;
      case 'التصنيف':
        setState(() {
          _selectedSectionIds = _allSections.map((s) => s.id).toSet();
        });
        _updateFilteredBooks();
        break;
    }
  }

  /// Selects all authors and updates the filtered books list.
  void _handleSelectAllAuthors() {
    setState(() {
      _selectedAuthorIds = _allAuthors.map((a) => a.id).toSet();
    });
    _updateFilteredBooks();
  }

  /// Selects all sections and updates the filtered books list.
  void _handleSelectAllSections() {
    setState(() {
      _selectedSectionIds = _allSections.map((s) => s.id).toSet();
    });
    _updateFilteredBooks();
  }

  /// Fallback handler for selecting all books in author panel.
  ///
  /// Note: This is typically handled by [AuthorsTablePanel] which knows
  /// which books are visible. This is a fallback that selects all filtered books.
  void _handleSelectAllBooksInAuthorPanel() {
    setState(() {
      for (var book in _getFilteredBooks()) {
        _selectedBooks[book['book_path'] as String] = true;
      }
    });
  }

  /// Fallback handler for selecting all books in section panel.
  ///
  /// Note: This is typically handled by [SectionsListPanel] which knows
  /// which books are visible. This is a fallback that selects all filtered books.
  void _handleSelectAllBooksInSectionPanel() {
    setState(() {
      for (var book in _getFilteredBooks()) {
        _selectedBooks[book['book_path'] as String] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _buildScaffold(),
    );
  }

  /// Builds the main scaffold widget with all UI components.
  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          SearchDialogBuilder.buildContent(
            selectedTab: _selectedSidebarTab,
            onTabSelected: (tab) => setState(() => _selectedSidebarTab = tab),
            searchOptionsPanel: _buildSearchOptionsPanel(),
            middlePanelContent: _buildMiddlePanelContent(),
          ),
          _buildBottomBar(),
          if (_results.isNotEmpty)
            SearchDialogBuilder.buildResultsPanel(
                  results: _results,
                  totalCount: _totalCount,
                  onResultTapped: widget.onResultTapped != null
                      ? (path, page) => widget.onResultTapped!(path, page)
                      : (path, page) {
                          // If onResultTapped is null, do nothing
                          // Results will be sent via onSearchPerformed
                        },
                  onClose: () => setState(() {
                    _results = [];
                    _hasSearched = false;
                  }),
                  searchQueries: _groupControllers.values
                      .expand((group) => group.map((c) => c.text.trim()))
                      .where((q) => q.isNotEmpty)
                      .toList(),
                  morphologicalSearch: _morphologicalSearch,
                ) ??
                SizedBox.shrink(),
        ],
      ),
    );
  }
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}
