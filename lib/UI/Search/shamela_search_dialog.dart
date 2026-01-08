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
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:flutter/services.dart';

class ShamelaSearchDialog extends StatefulWidget {
  final Function(String, int) onResultTapped;
  final List<Map<String, dynamic>> indexedBooks;
  final Function(List<Map<String, dynamic>>, int, List<String>, bool)?
  onSearchCompleted;

  const ShamelaSearchDialog({
    Key? key,
    required this.onResultTapped,
    required this.indexedBooks,
    this.onSearchCompleted,
  }) : super(key: key);

  @override
  _ShamelaSearchDialogState createState() => _ShamelaSearchDialogState();
}

class _ShamelaSearchDialogState extends State<ShamelaSearchDialog> {
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
  final Map<String, bool> _searchSections = {
    'main': true,
    'footnote': true,
    'comment': true,
    'title': false,
  };
  String _searchGrouping = 'all';
  bool _isLoading = false;
  bool _hasSearched = false; // Track if a search was performed
  List<Map<String, dynamic>> _results = [];
  int _totalCount = 0;
  String? _errorMessage;
  late Map<String, bool> _selectedBooks;
  List<Map<String, dynamic>> _filteredIndexedBooks = [];
  final SearchStateManager _stateManager = SearchStateManager();
  final SearchExecutor _searchExecutor = SearchExecutor();
  final SelectedBooksManager _selectedBooksManager = SelectedBooksManager();
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  Set<String> _selectedAuthorIds = {}, _selectedSectionIds = {};
  String? _viewedAuthorId;
  String? _viewedSectionId;
  bool _isLoadingFilters = false;
  Map<String, int> _authorBookCounts = {};
  Map<String, String> _authorDeathYears = {};
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
        for (var b in _filteredIndexedBooks) {
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

  /// Sync _selectedBooks with _selectedBooksForSearch
  /// Only books that are in _selectedBooksForSearch should be marked as selected
  void _syncSelectedBooksWithSearchList() {
    setState(() {
      // Get all book paths from _selectedBooksForSearch
      final bookPathsInSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'book' && item['bookPath'] != null)
          .map((item) => item['bookPath'] as String)
          .toSet();

      // Also get book paths from authors in _selectedBooksForSearch
      final authorIdsInSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'author' && item['authorId'] != null)
          .map((item) => item['authorId'] as String)
          .toSet();

      // Get book paths from selected authors
      final bookPathsFromAuthors = <String>{};
      for (var book in _filteredIndexedBooks) {
        final bookPath = book['book_path'] as String;
        final authorId = book['authorId'] as String?;
        if (authorId != null && authorIdsInSearch.contains(authorId)) {
          bookPathsFromAuthors.add(bookPath);
        }
      }

      // Note: Sections in _selectedBooksForSearch don't directly mark books as selected
      // Books from sections will be included during search execution
      // So we don't need to sync books from sections here

      // Combine all sets
      final allBookPathsInSearch = bookPathsInSearch.union(
        bookPathsFromAuthors,
      );

      // Update _selectedBooks to only mark books that are in _selectedBooksForSearch
      for (var bookPath in _selectedBooks.keys) {
        _selectedBooks[bookPath] = allBookPathsInSearch.contains(bookPath);
      }

      // Also update for new books in filtered list
      for (var book in _filteredIndexedBooks) {
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

  void _performSearch() async {
    // Check if any group has non-empty queries
    bool hasQueries = false;
    for (var group in _groupControllers.values) {
      if (group.any((c) => c.text.trim().isNotEmpty)) {
        hasQueries = true;
        break;
      }
    }
    if (!hasQueries) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
    });

    try {
      // Get section IDs from _selectedBooksForSearch
      final sectionIdsFromSearch = _selectedBooksForSearch
          .where(
            (item) => item['type'] == 'section' && item['sectionId'] != null,
          )
          .map((item) => item['sectionId'] as String)
          .toList();

      // Get book paths from sections in _selectedBooksForSearch
      List<String>? booksFromSections;
      if (sectionIdsFromSearch.isNotEmpty) {
        await _metadataDb.initialize();
        final allBookPaths = <String>[];
        for (var sectionId in sectionIdsFromSearch) {
          final bookPaths = await _metadataDb.getBookPaths(
            sectionId: sectionId,
          );
          allBookPaths.addAll(bookPaths);
        }
        // Filter to only include books that are in the filtered indexed books
        booksFromSections = allBookPaths.where((bookPath) {
          return _filteredIndexedBooks.any(
            (book) => book['book_path'] == bookPath,
          );
        }).toList();
      }

      // Get books from _selectedBooksForSearch (books and authors)
      final bookPathsFromSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'book' && item['bookPath'] != null)
          .map((item) => item['bookPath'] as String)
          .toList();

      // Get book paths from authors in _selectedBooksForSearch
      final authorIdsFromSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'author' && item['authorId'] != null)
          .map((item) => item['authorId'] as String)
          .toSet();

      List<String>? booksFromAuthors;
      if (authorIdsFromSearch.isNotEmpty) {
        await _metadataDb.initialize();
        final allBookPaths = <String>[];
        for (var authorId in authorIdsFromSearch) {
          final bookPaths = await _metadataDb.getBookPaths(authorId: authorId);
          allBookPaths.addAll(bookPaths);
        }
        // Filter to only include books that are in the filtered indexed books
        booksFromAuthors = allBookPaths.where((bookPath) {
          return _filteredIndexedBooks.any(
            (book) => book['book_path'] == bookPath,
          );
        }).toList();
      }

      // Combine all book paths
      Set<String> allBooksToSearch = {};
      if (booksFromSections != null) allBooksToSearch.addAll(booksFromSections);
      if (bookPathsFromSearch.isNotEmpty)
        allBooksToSearch.addAll(bookPathsFromSearch);
      if (booksFromAuthors != null) allBooksToSearch.addAll(booksFromAuthors);

      // If we have specific books from _selectedBooksForSearch, use them
      // Otherwise, use the default logic
      List<String>? booksToSearch;
      if (allBooksToSearch.isNotEmpty) {
        booksToSearch = allBooksToSearch.toList();
      } else {
        booksToSearch = _searchExecutor.determineBooksToSearch(
          filteredIndexedBooks: _filteredIndexedBooks,
          allIndexedBooks: widget.indexedBooks,
          selectedBooks: _selectedBooks,
        );
      }

      final selectedSections = _searchSections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final result = await _searchExecutor.performPageSearch(
        groupControllers: _groupControllers,
        searchGrouping: _searchGrouping,
        bookPaths: booksToSearch,
        sectionTypes: selectedSections.length < _searchSections.length
            ? selectedSections
            : null,
        morphologicalSearch: _morphologicalSearch,
        affixSearch: _affixSearch,
        considerHamzas: _considerHamzas,
        considerDiacritics: _considerDiacritics,
        considerNumbers: _considerNumbers,
        allPhrasesRequired: _allPhrasesRequired,
        ordered: _ordered,
        proximity: _proximity,
      );

      // Get search queries for display
      final searchQueries = _groupControllers.values
          .expand((group) => group.map((c) => c.text.trim()))
          .where((q) => q.isNotEmpty)
          .toList();

      // If onSearchCompleted is provided, send results to HomePage
      if (widget.onSearchCompleted != null && result.results.isNotEmpty) {
        Navigator.of(context).pop(); // Close dialog
        widget.onSearchCompleted!(
          result.results,
          result.totalCount,
          searchQueries,
          _morphologicalSearch,
        );
      } else {
        // Fallback: show results in dialog panel
        setState(() {
          _results = result.results;
          _totalCount = result.totalCount;
        });
      }
    } catch (e) {
      print("خطأ في البحث: $e");
      setState(() => _errorMessage = "خطأ في البحث: $e");
    } finally {
      setState(() => _isLoading = false);
    }
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
      viewedAuthorId: _viewedAuthorId,
      viewedSectionId: _viewedSectionId,
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
              const SelectAllIntent(),
        },
        child: Actions(
          actions: {
            SelectAllIntent: CallbackAction<SelectAllIntent>(
              onInvoke: (_) {
                _handleSelectAll();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
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
                    // Show results panel or no results message
                    if (_results.isNotEmpty)
                      SearchDialogBuilder.buildResultsPanel(
                            results: _results,
                            totalCount: _totalCount,
                            onResultTapped: (path, page) {
                              widget.onResultTapped(path, page);
                              Navigator.of(context).pop();
                            },
                            onClose: () => setState(() {
                              _results = [];
                              _hasSearched = false;
                            }),
                            searchQueries: _groupControllers.values
                                .expand(
                                  (group) => group.map((c) => c.text.trim()),
                                )
                                .where((q) => q.isNotEmpty)
                                .toList(),
                            morphologicalSearch: _morphologicalSearch,
                          ) ??
                          SizedBox.shrink()
                    else if (_hasSearched && !_isLoading && _results.isEmpty)
                      SearchDialogBuilder.buildNoResultsPanel(
                        searchQueries: _groupControllers.values
                            .expand((group) => group.map((c) => c.text.trim()))
                            .where((q) => q.isNotEmpty)
                            .toList(),
                        onClose: () => setState(() => _hasSearched = false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}
