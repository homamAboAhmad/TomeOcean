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
import 'package:window_manager/window_manager.dart';

class ShamelaSearchWindow extends StatefulWidget {
  final Function(String, int) onResultTapped;
  final List<Map<String, dynamic>> indexedBooks;
  
  const ShamelaSearchWindow({
    Key? key,
    required this.onResultTapped,
    required this.indexedBooks,
  }) : super(key: key);

  @override
  _ShamelaSearchWindowState createState() => _ShamelaSearchWindowState();
}

class _ShamelaSearchWindowState extends State<ShamelaSearchWindow> with WindowListener {
  final Map<String, List<TextEditingController>> _groupControllers = {
    'and': List.generate(5, (_) => TextEditingController()),
    'or': List.generate(5, (_) => TextEditingController()),
    'not': List.generate(5, (_) => TextEditingController()),
  };
  bool _morphologicalSearch = false, _affixSearch = false;
  bool _considerHamzas = false, _considerDiacritics = false, _considerNumbers = true;
  bool _allPhrasesRequired = false, _ordered = false, _proximity = false;
  final Map<String, bool> _searchSections = {'main': true, 'footnote': true, 'comment': true, 'title': false};
  String _searchGrouping = 'all';
  bool _isLoading = false;
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
  bool _isLoadingFilters = false;
  Map<String, int> _authorBookCounts = {};
  Map<String, String> _authorDeathYears = {};
  String _selectedSidebarTab = 'المؤلفون';
  final TextEditingController _booksSearchController = TextEditingController();
  final TextEditingController _selectedBooksSearchController = TextEditingController();
  List<Map<String, dynamic>> _selectedBooksForSearch = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _filteredIndexedBooks = widget.indexedBooks;
    _selectedBooks = {for (var b in widget.indexedBooks) b['book_path'] as String: false};
    _loadFilterData();
    _initializeWindow();
  }

  Future<void> _initializeWindow() async {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    for (var group in _groupControllers.values) {
      for (var c in group) c.dispose();
    }
    _booksSearchController.dispose();
    _selectedBooksSearchController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Handle window close
    super.onWindowClose();
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
      print("ShamelaSearchWindow: Error loading filter data: $e");
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
        final newSelectedBooks = <String, bool>{};
        for (var b in _filteredIndexedBooks) {
          final bookPath = b['book_path'] as String;
          newSelectedBooks[bookPath] = _selectedBooks[bookPath] ?? false;
        }
        _selectedBooks = newSelectedBooks;
      });
      _syncSelectedBooksWithSearchList();
    } catch (e) {
      print("ShamelaSearchWindow: Error updating filtered books: $e");
      setState(() => _filteredIndexedBooks = widget.indexedBooks);
    }
  }

  void _addBooksToSelectedList(List<String> bookPaths) async {
    final newItems = await _selectedBooksManager.addBooksToSelectedList(
      bookPaths, _allAuthors, _authorDeathYears);
    final filtered = newItems.where((item) => !_selectedBooksForSearch.any((e) => 
        e['type'] == item['type'] && e['bookPath'] == item['bookPath'])).toList();
    if (filtered.isNotEmpty) {
      setState(() => _selectedBooksForSearch.addAll(filtered));
      _syncSelectedBooksWithSearchList();
    }
  }

  void _addAuthorToSelectedList(String authorId) async {
    if (_selectedBooksForSearch.any((item) => 
        item['type'] == 'author' && item['authorId'] == authorId)) return;
    final author = _allAuthors.firstWhere(
      (a) => a.id == authorId,
      orElse: () => Author(id: '', name: '', description: ''),
    );
    if (author.id.isEmpty) return;
    final result = await _selectedBooksManager.addAuthorToSelectedList(
      authorId, author, _authorDeathYears[authorId], _filteredIndexedBooks);
    setState(() => _selectedBooksForSearch.add(result['authorItem']));
    final paths = result['bookPaths'] as List;
    if (paths.isNotEmpty) {
      _addBooksToSelectedList(paths.cast<String>());
    } else {
      _syncSelectedBooksWithSearchList();
    }
  }

  void _addSectionsToSelectedList() async {
    if (_selectedSectionIds.isEmpty) return;
    
    setState(() {
      for (var sectionId in _selectedSectionIds) {
        if (_selectedBooksForSearch.any((item) => 
            item['type'] == 'section' && item['sectionId'] == sectionId)) {
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

  void _removeFromSelectedList(List<int> indices) {
    setState(() {
      indices.sort((a, b) => b.compareTo(a));
      for (var i in indices) {
        if (i >= 0 && i < _selectedBooksForSearch.length) _selectedBooksForSearch.removeAt(i);
      }
    });
    _syncSelectedBooksWithSearchList();
  }

  void _clearSelectedList() {
    setState(() => _selectedBooksForSearch.clear());
    _syncSelectedBooksWithSearchList();
  }

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
      
      final allBookPathsInSearch = bookPathsInSearch.union(bookPathsFromAuthors);
      
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

  void _performSearch() async {
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
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
    });

    try {
      final sectionIdsFromSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'section' && item['sectionId'] != null)
          .map((item) => item['sectionId'] as String)
          .toList();
      
      List<String>? booksFromSections;
      if (sectionIdsFromSearch.isNotEmpty) {
        await _metadataDb.initialize();
        final allBookPaths = <String>[];
        for (var sectionId in sectionIdsFromSearch) {
          final bookPaths = await _metadataDb.getBookPaths(sectionId: sectionId);
          allBookPaths.addAll(bookPaths);
        }
        booksFromSections = allBookPaths.where((bookPath) {
          return _filteredIndexedBooks.any((book) => 
              book['book_path'] == bookPath);
        }).toList();
      }
      
      final bookPathsFromSearch = _selectedBooksForSearch
          .where((item) => item['type'] == 'book' && item['bookPath'] != null)
          .map((item) => item['bookPath'] as String)
          .toList();
      
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
        booksFromAuthors = allBookPaths.where((bookPath) {
          return _filteredIndexedBooks.any((book) => 
              book['book_path'] == bookPath);
        }).toList();
      }
      
      Set<String> allBooksToSearch = {};
      if (booksFromSections != null) allBooksToSearch.addAll(booksFromSections);
      if (bookPathsFromSearch.isNotEmpty) allBooksToSearch.addAll(bookPathsFromSearch);
      if (booksFromAuthors != null) allBooksToSearch.addAll(booksFromAuthors);
      
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
          .where((e) => e.value).map((e) => e.key).toList();
      
      final result = await _searchExecutor.performPageSearch(
        groupControllers: _groupControllers,
        searchGrouping: _searchGrouping,
        bookPaths: booksToSearch,
        sectionTypes: selectedSections.length < _searchSections.length ? selectedSections : null,
        morphologicalSearch: _morphologicalSearch,
        affixSearch: _affixSearch,
        considerHamzas: _considerHamzas,
        considerDiacritics: _considerDiacritics,
        considerNumbers: _considerNumbers,
        allPhrasesRequired: _allPhrasesRequired,
        ordered: _ordered,
        proximity: _proximity,
      );
      setState(() {
        _results = result.results;
        _totalCount = result.totalCount;
      });
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
      onSearchSectionChanged: (key, value) => setState(() => _searchSections[key] = value),
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
        setState(() { _results = []; _totalCount = 0; });
      },
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      totalCount: _totalCount,
      selectedBooksForSearch: _selectedBooksForSearch,
      onRemoveFromSelectedList: _removeFromSelectedList,
      onClearSelectedList: _clearSelectedList,
      selectedBooksSearchController: _selectedBooksSearchController,
      searchGrouping: _searchGrouping,
      onSearchGroupingChanged: (value) => setState(() => _searchGrouping = value),
    );
  }

  List<Map<String, dynamic>> _getFilteredBooks() {
    final q = _booksSearchController.text.toLowerCase();
    return q.isEmpty ? _filteredIndexedBooks
        : _filteredIndexedBooks.where((b) => 
            p.basenameWithoutExtension(b['book_path'] as String).toLowerCase().contains(q)).toList();
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
      onSelectAllBooks: () {
        setState(() {
          for (var book in _getFilteredBooks()) {
            _selectedBooks[book['book_path'] as String] = true;
          }
        });
      },
      onInvertSelection: () {
        setState(() {
          for (var book in _getFilteredBooks()) {
            final path = book['book_path'] as String;
            _selectedBooks[path] = !(_selectedBooks[path] ?? false);
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
      onAuthorToggled: (authorId) {
        setState(() {
          if (_selectedAuthorIds.contains(authorId)) {
            _selectedAuthorIds.remove(authorId);
          } else {
            _selectedAuthorIds.add(authorId);
          }
        });
        _updateFilteredBooks();
      },
      onSelectAllAuthors: () {
        final isAll = _selectedAuthorIds.length == _allAuthors.length;
        setState(() => _selectedAuthorIds = isAll ? {} : _allAuthors.map((a) => a.id).toSet());
        _updateFilteredBooks();
      },
      onSectionToggled: (id) {
        setState(() => _selectedSectionIds.contains(id) ? _selectedSectionIds.remove(id)
            : _selectedSectionIds.add(id));
        _updateFilteredBooks();
      },
      onSelectAllSections: () {
        final isAll = _selectedSectionIds.length == _allSections.length;
        setState(() => _selectedSectionIds = isAll ? {} : _allSections.map((s) => s.id).toSet());
        _updateFilteredBooks();
      },
      onClearSections: () {
        setState(() => _selectedSectionIds.clear());
        _updateFilteredBooks();
      },
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
        final paths = _selectedBooks.entries.where((e) => e.value).map((e) => e.key).toList();
        setState(() {
          for (var path in paths) {
            _selectedBooks[path] = false;
            _selectedBooksForSearch.removeWhere((item) => 
                item['type'] == 'book' && item['bookPath'] == path);
          }
        });
      },
      onSelectAllBooks: () {
        final paths = _selectedBooks.entries.where((e) => e.value).map((e) => e.key).toList();
        if (paths.isNotEmpty) _addBooksToSelectedList(paths);
      },
      onDeselectAllAuthors: () {
        final ids = _selectedAuthorIds.toList();
        setState(() {
          _selectedAuthorIds.clear();
          for (var id in ids) {
            _selectedBooksForSearch.removeWhere((item) => 
                (item['type'] == 'author' || item['type'] == 'book') &&
                item['authorId'] == id);
          }
        });
        _updateFilteredBooks();
      },
      onSelectAllAuthors: () {
        for (var id in _selectedAuthorIds) {
          _addAuthorToSelectedList(id);
        }
      },
      onDeselectAllSections: () {
        setState(() => _selectedSectionIds.clear());
        _updateFilteredBooks();
      },
      onSelectAllSections: () {
        _addSectionsToSelectedList();
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
            child: Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                title: Text('البحث', style: bigStyle(color: secondaryColor, fontSize: 18)),
                backgroundColor: primaryColor,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryColor, size: 20),
                    onPressed: () async {
                      await windowManager.close();
                    },
                  ),
                ],
              ),
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
                      onResultTapped: (path, page) {
                        widget.onResultTapped(path, page);
                        windowManager.close();
                      },
                      onClose: () => setState(() => _results = []),
                      searchQueries: _groupControllers.values
                          .expand((group) => group.map((c) => c.text.trim()))
                          .where((q) => q.isNotEmpty)
                          .toList(),
                      morphologicalSearch: _morphologicalSearch,
                    ) ?? SizedBox.shrink(),
                ],
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

