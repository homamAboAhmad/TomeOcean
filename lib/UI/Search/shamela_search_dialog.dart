import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/Search/widgets/results_view.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/Search/widgets/search_options_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/bottom_bar.dart';
import 'package:golden_shamela/UI/Search/widgets/middle_panel_content.dart';
import 'package:golden_shamela/UI/Search/helpers/search_state_manager.dart';
import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/UI/Search/helpers/search_results_author_sorter.dart';
import 'package:golden_shamela/UI/Search/helpers/selected_books_manager.dart';
import 'package:golden_shamela/UI/Search/helpers/search_period_range.dart';
import 'package:golden_shamela/UI/Search/helpers/search_history_store.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_selection.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_item_ids.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_items_merger.dart';
import 'package:golden_shamela/UI/Search/helpers/search_sections_selection_rules.dart';
import 'package:golden_shamela/UI/Search/helpers/fts_query_builder.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/UI/Search/models/search_history_record.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';
import 'package:golden_shamela/UI/Search/widgets/search_dialog_builder.dart';
import 'package:golden_shamela/UI/Search/helpers/search_callbacks_helper.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';

List<TextEditingController> _newQueryControllers() {
  return List.generate(
    AppOtherSettings.instance.draft().searchFieldCount,
    (_) => TextEditingController(),
  );
}

class ShamelaSearchDialog extends StatefulWidget {
  final Function(String, int) onResultTapped;
  final List<Map<String, dynamic>> indexedBooks;
  final Function(List<Map<String, dynamic>>, int, List<String>, bool)?
  onSearchCompleted;
  final Function(
    Map<String, dynamic> groupControllersMap,
    String searchGrouping,
    List<Map<String, dynamic>> selectedBooksForSearch,
    Map<String, bool> searchSections,
    bool morphologicalSearch,
    bool affixSearch,
    bool considerHamzas,
    bool considerDiacritics,
    bool considerNumbers,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
    List<Map<String, dynamic>> indexedBooks,
  )?
  onDelegateSearch;

  const ShamelaSearchDialog({
    Key? key,
    required this.onResultTapped,
    required this.indexedBooks,
    this.onSearchCompleted,
    this.onDelegateSearch,
  }) : super(key: key);

  @override
  _ShamelaSearchDialogState createState() => _ShamelaSearchDialogState();
}

class _ShamelaSearchDialogState extends State<ShamelaSearchDialog> {
  final Map<String, List<TextEditingController>> _groupControllers = {
    'and': _newQueryControllers(),
    'or': _newQueryControllers(),
    'not': _newQueryControllers(),
  };
  bool _morphologicalSearch = false, _affixSearch = false;
  bool _considerHamzas = false,
      _considerDiacritics = false,
      _considerNumbers = true;
  bool _allPhrasesRequired = false, _ordered = false, _proximity = false;
  final Map<String, bool> _searchSections = {
    'main': true,
    'footnote': true,
    'comment': false,
    'title': false,
  };
  String _searchGrouping = 'all';
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _results = [];
  int _totalCount = 0;
  String? _errorMessage;
  late Map<String, bool> _selectedBooks;
  List<Map<String, dynamic>> _filteredIndexedBooks = [];
  final SearchStateManager _stateManager = SearchStateManager();
  final SearchExecutor _searchExecutor = SearchExecutor();
  final SelectedBooksManager _selectedBooksManager = SelectedBooksManager();
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();
  final SearchHistoryStore _historyStore = SearchHistoryStore();
  late final SearchScopeBookResolver _scopeBookResolver;
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
  int _scopeSyncRevision = 0;

  @override
  void initState() {
    super.initState();
    _filteredIndexedBooks = widget.indexedBooks;
    _selectedBooks = {
      for (var b in widget.indexedBooks) b['book_path'] as String: false,
    };
    _scopeBookResolver = SearchScopeBookResolver(_metadataDb);
    _loadFilterData();
  }

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
      if (mounted) setState(() => _bookAuthorMap = bookAuthorMap);
    } catch (e) {
      print("ShamelaSearchDialog: Error loading filter data: $e");
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _updateFilteredBooks() async {
    try {
      final result = await _stateManager.updateFilteredBooks(
        selectedAuthorIds: _selectedAuthorIds,
        selectedSectionIds: _selectedSectionIds,
        allIndexedBooks: widget.indexedBooks,
      );
      setState(() {
        _filteredIndexedBooks = result.filteredBooks;
        // Initialize selectedBooks for new books, preserving existing selections
        final newSelectedBooks = <String, bool>{};
        for (var b in widget.indexedBooks) {
          final bookPath = b['book_path'] as String;
          newSelectedBooks[bookPath] = _selectedBooks[bookPath] ?? false;
        }
        _selectedBooks = newSelectedBooks;
      });
      // Sync with search list after updating filtered books
      _syncSelectedBooksWithSearchList();
    } catch (e) {
      print("ShamelaSearchDialog: Error updating filtered books: $e");
      setState(() => _filteredIndexedBooks = widget.indexedBooks);
    }
  }

  void _addBooksToSelectedList(List<String> bookPaths) async {
    final newItems = await _selectedBooksManager.addBooksToSelectedList(
      bookPaths,
      _allAuthors,
      _authorDeathYears,
      widget.indexedBooks,
    );
    final filtered = newItems
        .where(
          (item) => !_selectedBooksForSearch.any(
            (e) =>
                e['type'] == item['type'] && e['bookPath'] == item['bookPath'],
          ),
        )
        .toList();
    if (filtered.isNotEmpty) {
      setState(() => _selectedBooksForSearch.addAll(filtered));
      _syncSelectedBooksWithSearchList();
    }
  }

  void _addAuthorToSelectedList(String authorId) async {
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
    );
    setState(() => _selectedBooksForSearch.add(result['authorItem']));
    _syncSelectedBooksWithSearchList();
  }

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

  void _clearSelectedList() {
    setState(() => _selectedBooksForSearch.clear());
    _syncSelectedBooksWithSearchList();
  }

  // Helper methods for bulk operations
  void _addAuthorsToList(List<String> authorIds) {
    for (var id in authorIds) {
      _addAuthorToSelectedList(id);
    }
  }

  void _removeAuthorsFromList(List<String> authorIds) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'author' && authorIds.contains(item['authorId']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  void _removeBooksFromList(List<String> bookPaths) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'book' && bookPaths.contains(item['bookPath']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  void _addSectionsToList(List<String> sectionIds) {
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
    _syncSelectedBooksWithSearchList();
  }

  void _removeSectionsFromList(List<String> sectionIds) {
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) =>
            item['type'] == 'section' && sectionIds.contains(item['sectionId']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  void _addPeriodsToList(List<SearchPeriodRange> periods) {
    if (periods.isEmpty) return;
    setState(() {
      for (final period in periods) {
        if (_selectedBooksForSearch.any(
          (item) => item['type'] == 'period' && item['periodId'] == period.id,
        )) {
          continue;
        }
        _selectedBooksForSearch.add(period.toSearchItem());
      }
    });
    _syncSelectedBooksWithSearchList();
  }

  void _removePeriodsFromList(List<SearchPeriodRange> periods) {
    final ids = periods.map((period) => period.id).toSet();
    setState(() {
      _selectedBooksForSearch.removeWhere(
        (item) => item['type'] == 'period' && ids.contains(item['periodId']),
      );
    });
    _syncSelectedBooksWithSearchList();
  }

  void _addScopeItemsToList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final merged = SearchScopeItemsMerger.merge(
      currentItems: _selectedBooksForSearch,
      incomingItems: items,
    );
    setState(() {
      _selectedBooksForSearch = merged.items;
      _selectedAuthorIds = merged.authorIds;
      _selectedSectionIds = merged.sectionIds;
    });
    _syncSelectedBooksWithSearchList();
  }

  /// Sync _selectedBooks with _selectedBooksForSearch
  /// Only books that are in _selectedBooksForSearch should be marked as selected
  Future<void> _syncSelectedBooksWithSearchList() async {
    final revision = ++_scopeSyncRevision;
    final selection = SearchScopeSelection.fromItems(_selectedBooksForSearch);
    final allBookPathsInSearch =
        await _scopeBookResolver.selectedBookPathsForDisplay(
      selection: selection,
      filteredIndexedBooks: widget.indexedBooks,
      bookAuthorMap: _bookAuthorMap,
    );
    if (!mounted || revision != _scopeSyncRevision) return;
    setState(() {
      for (var bookPath in _selectedBooks.keys) {
        _selectedBooks[bookPath] = allBookPathsInSearch.contains(bookPath);
      }

      for (var book in widget.indexedBooks) {
        final bookPath = book['book_path'] as String;
        if (!_selectedBooks.containsKey(bookPath)) {
          _selectedBooks[bookPath] = allBookPathsInSearch.contains(bookPath);
        }
      }
    });
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

  Future<List<String>?> _resolveBooksToSearch() async {
    final selection = SearchScopeSelection.fromItems(_selectedBooksForSearch);
    if (!selection.isEmpty) {
      final paths = await _scopeBookResolver.resolveBookPaths(
        selection: selection,
        filteredIndexedBooks: widget.indexedBooks,
        bookAuthorMap: _bookAuthorMap,
      );
      return paths.toList();
    }

    return _searchExecutor.determineBooksToSearch(
      filteredIndexedBooks: _filteredIndexedBooks,
      allIndexedBooks: widget.indexedBooks,
      selectedBooks: _selectedBooks,
    );
  }

  void _performSearch() async {
    final validationMessage = _searchInputValidationMessage();
    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    // التحقق من تحديد كتب للبحث
    if (_selectedBooksForSearch.isEmpty) {
      setState(() => _errorMessage = 'يرجى تحديد كتاب واحد على الأقل من قائمة البحث');
      return;
    }

    // إذا كان هناك delegate، أغلق النافذة فوراً وفوّض البحث للنافذة الرئيسية
    if (widget.onDelegateSearch != null) {
      final groupControllersMap = <String, dynamic>{};
      _groupControllers.forEach((key, controllers) {
        groupControllersMap[key] = controllers.map((c) => c.text).toList();
      });

      await _saveCurrentSearchHistory();
      Navigator.of(context).pop();
      widget.onDelegateSearch!(
        groupControllersMap,
        _searchGrouping,
        List<Map<String, dynamic>>.from(_selectedBooksForSearch),
        Map<String, bool>.from(_searchSections),
        _morphologicalSearch,
        _affixSearch,
        _considerHamzas,
        _considerDiacritics,
        _considerNumbers,
        _allPhrasesRequired,
        _ordered,
        _proximity,
        widget.indexedBooks,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
    });

    try {
      final booksToSearch = await _resolveBooksToSearch();

      final selectedSections = _searchSections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final searchQueries = _groupControllers.values
          .expand((group) => group.map((c) => c.text.trim()))
          .where((q) => q.isNotEmpty)
          .toList();

      await for (final batch in _searchExecutor.performPageSearchStream(
        groupControllers: _groupControllers,
        searchGrouping: _searchGrouping,
        bookPaths: booksToSearch,
        sectionTypes: selectedSections.length < _searchSections.length
            ? selectedSections
            : null,
        includeComments: _searchSections['comment'] == true,
        morphologicalSearch: _morphologicalSearch,
        affixSearch: _affixSearch,
        considerHamzas: _considerHamzas,
        considerDiacritics: _considerDiacritics,
        considerNumbers: _considerNumbers,
        allPhrasesRequired: _allPhrasesRequired,
        ordered: _ordered,
        proximity: _proximity,
        batchSize: 20,
      )) {
        if (!mounted) break;
        setState(() {
          _results.addAll(batch.results);
          SearchResultsAuthorSorter.sort(
            _results,
            bookAuthorMap: _bookAuthorMap,
            authorDeathYears: _authorDeathYears,
          );
          if (batch.totalCount > _totalCount) _totalCount = batch.totalCount;
        });
      }

      if (!mounted) return;

      await _saveCurrentSearchHistory();
      if (widget.onSearchCompleted != null && _results.isNotEmpty) {
        Navigator.of(context).pop();
        widget.onSearchCompleted!(
          _results,
          _totalCount,
          searchQueries,
          _morphologicalSearch,
        );
      }
    } catch (e) {
      print("خطأ في البحث: $e");
      if (mounted) setState(() => _errorMessage = "خطأ في البحث: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _searchInputValidationMessage() {
    final hasQueries = _groupControllers.values.any(
      (group) => group.any(
        (controller) => FtsQueryBuilder.clean(controller.text).isNotEmpty,
      ),
    );
    if (!hasQueries) return 'أدخل عبارة بحث واحدة على الأقل';

    final hasSelectedSection = _searchSections.entries.any((entry) {
      return entry.value &&
          const {'main', 'footnote', 'title', 'comment'}.contains(entry.key);
    });
    if (!hasSelectedSection) return 'اختر نطاق بحث واحدًا على الأقل';

    return null;
  }

  void _addQueryField(String groupKey, int index) {
    setState(() {
      _groupControllers[groupKey]!.insert(index, TextEditingController());
    });
  }

  void _removeQueryField(String groupKey, int index) {
    setState(() {
      if (_groupControllers[groupKey]!.length > 1) {
        _groupControllers[groupKey]![index].dispose();
        _groupControllers[groupKey]!.removeAt(index);
      }
    });
  }

  Future<void> _saveCurrentSearchHistory() {
    return _historyStore.saveRecord(_currentHistoryRecord());
  }

  SearchHistoryRecord _currentHistoryRecord() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = _currentSearchSnapshot();
    return SearchHistoryRecord(
      id: now.toString(),
      createdAt: now,
      groupQueries: snapshot.groupQueries,
      searchGrouping: snapshot.searchGrouping,
      scopeItems: _copyScopeItems(_selectedBooksForSearch),
      searchSections: snapshot.searchSections,
      options: snapshot.options,
    );
  }

  SearchStateSnapshot _currentSearchSnapshot() {
    return SearchStateSnapshot(
      groupQueries: _buildGroupQueries(),
      searchGrouping: _searchGrouping,
      searchSections: Map<String, bool>.from(_searchSections),
      options: {
        'morphologicalSearch': _morphologicalSearch,
        'affixSearch': _affixSearch,
        'considerHamzas': _considerHamzas,
        'considerDiacritics': _considerDiacritics,
        'considerNumbers': _considerNumbers,
        'allPhrasesRequired': _allPhrasesRequired,
        'ordered': _ordered,
        'proximity': _proximity,
      },
    );
  }

  Map<String, List<String>> _buildGroupQueries() {
    return {
      for (final entry in _groupControllers.entries)
        entry.key: entry.value.map((controller) => controller.text).toList(),
    };
  }

  Future<void> _applyHistoryRecord(
    SearchHistoryRecord record, {
    required bool runSearch,
  }) async {
    setState(() {
      _replaceGroupControllers(record.groupQueries);
      _searchGrouping = record.searchGrouping;
      _selectedBooksForSearch = _copyScopeItems(record.scopeItems);
      _selectedAuthorIds = searchScopeItemIds(
        record.scopeItems,
        type: 'author',
        key: 'authorId',
      );
      _selectedSectionIds = searchScopeItemIds(
        record.scopeItems,
        type: 'section',
        key: 'sectionId',
      );
      for (final key in _searchSections.keys.toList()) {
        _searchSections[key] = record.searchSections[key] ?? false;
      }
      _morphologicalSearch = record.options['morphologicalSearch'] ?? false;
      _affixSearch = record.options['affixSearch'] ?? false;
      _considerHamzas = record.options['considerHamzas'] ?? false;
      _considerDiacritics = record.options['considerDiacritics'] ?? false;
      _considerNumbers = record.options['considerNumbers'] ?? true;
      _allPhrasesRequired = record.options['allPhrasesRequired'] ?? false;
      _ordered = record.options['ordered'] ?? false;
      _proximity = record.options['proximity'] ?? false;
    });
    await _syncSelectedBooksWithSearchList();
    if (runSearch) _performSearch();
  }

  void _replaceGroupControllers(Map<String, List<String>> groupQueries) {
    for (final controllers in _groupControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    for (final key in _groupControllers.keys.toList()) {
      final queries = groupQueries[key] ?? const [];
      final effectiveQueries = queries.isEmpty ? [''] : queries;
      _groupControllers[key] = effectiveQueries
          .map((query) => TextEditingController(text: query))
          .toList();
    }
  }

  List<Map<String, dynamic>> _copyScopeItems(
    List<Map<String, dynamic>> items,
  ) {
    return items.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Widget _buildSearchOptionsPanel() {
    return SearchOptionsPanel(
      searchSections: _searchSections,
      onSearchSectionChanged: (key, value) =>
          setState(() => SearchSectionsSelectionRules.apply(
                _searchSections,
                key,
                value,
              )),
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
        });
      },
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      totalCount: _results.length,
      selectedBooksForSearch: _selectedBooksForSearch,
      onRemoveFromSelectedList: _removeFromSelectedList,
      onClearSelectedList: _clearSelectedList,
      selectedBooksSearchController: _selectedBooksSearchController,
      searchGrouping: _searchGrouping,
      onSearchGroupingChanged: (value) =>
          setState(() => _searchGrouping = value),
    );
  }

  List<Map<String, dynamic>> _getFilteredBooks() {
    final q = _booksSearchController.text.toLowerCase();
    return q.isEmpty
        ? widget.indexedBooks
        : widget.indexedBooks
              .where(
                (b) => AppStoragePaths
                    .displayTitleFromPath(b['book_path'] as String)
                    .toLowerCase()
                    .contains(q),
              )
              .toList();
  }

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
      selectedPeriods: SearchPeriodRange.fromSearchItems(
        _selectedBooksForSearch,
      ),
      authors: _allAuthors,
      sections: _allSections,
      authorBookCounts: _authorBookCounts,
      authorDeathYears: _authorDeathYears,
      selectedBooksForSearch: _selectedBooksForSearch,
      searchSnapshot: _currentSearchSnapshot(),
      isLoadingFilters: _isLoadingFilters,
      onAuthorToggled: (id) {},
      onClearAuthors: () {},
      onClearSections: () {},
      onAuthorClicked: (authorId) {
        setState(() => _viewedAuthorId = authorId);
      },
      onSectionClicked: (sectionId) {
        setState(() => _viewedSectionId = sectionId);
      },
      onAuthorsAdded: _addAuthorsToList,
      onAuthorsRemoved: _removeAuthorsFromList,
      onBooksAdded: _addBooksToSelectedList,
      onBooksRemoved: _removeBooksFromList,
      onSectionsAdded: _addSectionsToList,
      onSectionsRemoved: _removeSectionsFromList,
      onPeriodsAdded: _addPeriodsToList,
      onPeriodsRemoved: _removePeriodsFromList,
      onScopeItemsAdded: _addScopeItemsToList,
      onHistoryRecordSelected: _applyHistoryRecord,
      viewedAuthorId: _viewedAuthorId,
      viewedSectionId: _viewedSectionId,
      bookAuthorMap: _bookAuthorMap,
    );
  }

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
          _selectedBooksForSearch.removeWhere(
            (item) =>
                item['type'] == 'author' && ids.contains(item['authorId']),
          );
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

  List<String> get _currentSearchQueries => _groupControllers.values
      .expand((group) => group.map((c) => c.text.trim()))
      .where((q) => q.isNotEmpty)
      .toList();

  Widget _buildResultsArea() {
    if (_results.isEmpty && _hasSearched && !_isLoading) {
      return SearchDialogBuilder.buildNoResultsPanel(
        searchQueries: _currentSearchQueries,
        onClose: () => setState(() => _hasSearched = false),
      );
    }
    if (_results.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 340,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SearchResultsView(
        results: _results,
        totalCount: _results.length,
        onResultTapped: (path, page) {
          widget.onResultTapped(path, page);
          Navigator.of(context).pop();
        },
        onClose: () => setState(() {
          _results = [];
          _hasSearched = false;
        }),
        searchQueries: _currentSearchQueries,
        morphologicalSearch: _morphologicalSearch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.95,
              child: Column(
                children: [
                  SearchDialogBuilder.buildHeader(
                    () => Navigator.of(context).pop(),
                  ),
                  SearchDialogBuilder.buildContent(
                    selectedTab: _selectedSidebarTab,
                    onTabSelected: (tab) =>
                        setState(() => _selectedSidebarTab = tab),
                    searchOptionsPanel: _buildSearchOptionsPanel(),
                    middlePanelContent: _buildMiddlePanelContent(),
                  ),
                  _buildBottomBar(),
                  if (_results.isNotEmpty || (_hasSearched && !_isLoading))
                    _buildResultsArea(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
