import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_sidebar_tabs.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_import_actions.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_tab_toolbars.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_views.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_sidebar_tabs.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_resizable_dialog_frame.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_lazy_book_card_panel.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_index.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_search_debouncer.dart';
import 'library_picker_repository.dart';

Future<String?> showLibraryPickerDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const LibraryPickerDialog(),
    );
class LibraryPickerDialog extends StatefulWidget {
  const LibraryPickerDialog({super.key});
  @override
  State<LibraryPickerDialog> createState() => _LibraryPickerDialogState();
}
class _LibraryPickerDialogState extends State<LibraryPickerDialog> {
  static const _booksTab = 'books';
  static const _sectionsTab = 'sections';
  static const _authorsTab = 'authors';
  static const _favoritesTab = 'favorites';
  static const _recentTab = 'recent';
  final _repo = LibraryPickerRepository();
  final _booksSearch = TextEditingController();
  final _sectionsSearch = TextEditingController();
  final _sectionBooksSearch = TextEditingController();
  final _authorsSearch = TextEditingController();
  final _authorBooksSearch = TextEditingController();
  final _selectedTypes = BookMetadataOptions.bookTypes.toSet();
  List<LibraryBookItem> _books = [];
  late LibraryPickerIndex _index = LibraryPickerIndex(_books);
  List<Author> _authors = [];
  List<Author> _authorsByName = [];
  List<Author> _authorsByDeath = [];
  List<Section> _sections = [];
  Set<String> _favorites = {};
  List<String> _recentPaths = [];
  Set<String> _fullSearchPaths = {};
  String _tab = _booksTab;
  String _searchScope = 'title_author';
  String? _selectedPath;
  final _selectedPathNotifier = ValueNotifier<String?>(null);
  final _selectedDetails = ValueNotifier<Future<LibraryBookItem?>?>(null);
  final _searchDebouncer = LibrarySearchDebouncer();
  int _searchRevision = 0;
  String? _selectedSectionId;
  String? _selectedAuthorId;
  bool _includeMatchingPrinted = true;
  bool _includeNotMatchingPrinted = true;
  bool _sortAuthorsByName = false;
  bool _showCard = false;
  bool _loading = true;
  final _splitController = LibrarySplitController();
  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    for (final controller in [
      _booksSearch, _sectionsSearch, _sectionBooksSearch,
      _authorsSearch, _authorBooksSearch,
    ]) { controller.dispose(); }
    _splitController.dispose();
    _selectedPathNotifier.dispose();
    _selectedDetails.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    final results = await Future.wait([
      _repo.loadBooks(),
      _repo.loadAuthors(),
      _repo.loadSections(),
      _repo.loadFavorites(),
      _repo.loadRecentPaths(),
    ]);
    if (!mounted) return;
    setState(() {
      _books = results[0] as List<LibraryBookItem>;
      _index = LibraryPickerIndex(_books);
      _authors = results[1] as List<Author>;
      _authorsByName =
          LibraryPickerIndex.sortedAuthors(_authors, byName: true);
      _authorsByDeath =
          LibraryPickerIndex.sortedAuthors(_authors, byName: false);
      _sections = results[2] as List<Section>;
      _favorites = results[3] as Set<String>;
      _recentPaths = results[4] as List<String>;
      _selectedPath = _books.isEmpty ? null : _books.first.bookPath;
      _selectedPathNotifier.value = _selectedPath;
      _selectedSectionId = _sections.isEmpty ? null : _sections.first.id;
      _selectedAuthorId = _authors.isEmpty ? null : _authors.first.id;
      _loading = false;
    });
  }
  @override Widget build(BuildContext context) {
    final content = Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: LibraryDesignTokens.fontFamily,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: Colors.white,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _body(),
        ),
      ),
    );
    return LibraryResizableDialogFrame(
      minWidth: LibraryDesignTokens.pickerMinimumWidth,
      minHeight: 560,
      child: content,
    );
  } Widget _body() {
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          child: _showCard
              ? Column(
                  children: [
                    _toolbarForTab(),
                    Expanded(
                      child: LibrarySplitPane(
                        axis: Axis.vertical,
                        initialRatio: 0.68,
                        minRatio: 0.3,
                        maxRatio: 0.85,
                        first: _content(),
                        second: LibraryLazyBookCardPanel(
                          details: _selectedDetails,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _toolbarForTab(),
                    Expanded(child: _content()),
                  ],
                ),
        ),
        LibrarySidebarTabs(
          tabs: libraryPickerSidebarTabs,
          selectedTab: _tab,
          onTabSelected: (tab) => setState(() => _tab = tab),
        ),
      ],
    );
  } Widget _toolbarForTab() {
    if (_tab == _sectionsTab) {
      return LibrarySectionsToolbar(
            selectedTypes: _selectedTypes,
            includeMatchingPrinted: _includeMatchingPrinted,
            includeNotMatchingPrinted: _includeNotMatchingPrinted,
            onTypeToggled: _toggleType,
            onGroupChanged: _setTypeGroup,
            onMatchingPrintedChanged: (v) {
              setState(() => _includeMatchingPrinted = v);
            },
            onNotMatchingPrintedChanged: (v) {
              setState(() => _includeNotMatchingPrinted = v);
            },
      );
    }
    if (_tab == _authorsTab) {
      return const SizedBox.shrink();
    }
    return LibraryBooksToolbar(
      searchController: _booksSearch,
      searchScope: _searchScope,
      showCard: _showCard,
      onToggleCard: _toggleCard,
      onPickFiles: _pickDocxFiles,
      onPickFolder: _pickFolder,
      onSearchScopeChanged: _setSearchScope,
      onSearchChanged: (_) => _debounceRebuild(),
    );
  } Widget _content() {
    switch (_tab) {
      case _sectionsTab:
        return _sectionsView();
      case _authorsTab:
        return _authorsView();
      case _favoritesTab:
        return _booksTable(
          _booksForGeneralSearch()
              .where((book) => _favorites.contains(book.bookPath))
              .toList(),
        );
      case _recentTab:
        return _booksTable(
          _recentPaths.map(_bookByPath).whereType<LibraryBookItem>().where(
            (book) => _matchesGeneralSearch(book),
          ).toList(),
          additionalActionBuilder: _recentDeleteButton,
        );
      default:
        return _booksTable(_booksForGeneralSearch());
    }
  } Widget _sectionsView() {
    final visibleSections = _sections.where((section) {
      return LibraryTextNormalizer.contains(section.title, _sectionsSearch.text);
    }).toList();
    final books = _books.where((book) {
      return book.book.sectionId == _selectedSectionId &&
          _matchesSectionFilters(book) &&
          _matchesBookSearch(book, _sectionBooksSearch.text);
    }).toList();
    return LibrarySectionsView(
      sections: visibleSections,
      books: books,
      counts: _index.sectionCounts,
      selectedSectionId: _selectedSectionId,
      selectedBookPath: _selectedPath,
      favoritePaths: _favorites,
      onSectionSelected: (id) => setState(() => _selectedSectionId = id),
      onBookSelected: _selectBook,
      onBookOpened: _openBook,
      onFavoriteChanged: _toggleFavorite,
      splitController: _splitController,
      booksSearchController: _sectionBooksSearch,
      onBooksSearchChanged: (_) => _debounceRebuild(),
      entitiesSearchController: _sectionsSearch,
      onEntitiesSearchChanged: (_) => _debounceRebuild(),
      booksLeadingActions: _bookFragmentActions,
      booksSearchScope: _searchScope,
      onBooksSearchScopeChanged: _setSearchScope,
    );
  } Widget _authorsView() {
    final orderedAuthors =
        _sortAuthorsByName ? _authorsByName : _authorsByDeath;
    final visibleAuthors = orderedAuthors.where((author) {
      return LibraryTextNormalizer.contains(author.name, _authorsSearch.text);
    }).toList();
    final books = _books.where((book) {
      return book.book.authorId == _selectedAuthorId &&
          _matchesBookSearch(book, _authorBooksSearch.text);
    }).toList();
    return LibraryAuthorsView(
      authors: visibleAuthors,
      books: books,
      counts: _index.authorCounts,
      selectedAuthorId: _selectedAuthorId,
      selectedBookPath: _selectedPath,
      favoritePaths: _favorites,
      onAuthorSelected: (id) => setState(() => _selectedAuthorId = id),
      onAuthorHeaderTap: () => setState(() => _sortAuthorsByName = true),
      onDeathHeaderTap: () => setState(() => _sortAuthorsByName = false),
      onBookSelected: _selectBook,
      onBookOpened: _openBook,
      onFavoriteChanged: _toggleFavorite,
      splitController: _splitController,
      booksSearchController: _authorBooksSearch,
      onBooksSearchChanged: (_) => _debounceRebuild(),
      entitiesSearchController: _authorsSearch,
      onEntitiesSearchChanged: (_) => _debounceRebuild(),
      booksLeadingActions: _bookFragmentActions,
      booksSearchScope: _searchScope,
      onBooksSearchScopeChanged: _setSearchScope,
    );
  } Widget _booksTable(
    List<LibraryBookItem> books, {
    Widget Function(LibraryBookItem)? additionalActionBuilder,
  }) {
    return LibraryBooksTable(
      books: books,
      selectedPath: _selectedPath,
      favoritePaths: _favorites,
      onSelected: _selectBook,
      onDoubleTap: _openBook,
      onFavoriteChanged: _toggleFavorite,
      additionalActionBuilder: additionalActionBuilder,
    );
  }
  List<LibraryBookItem> _booksForGeneralSearch() =>
      _books.where(_matchesGeneralSearch).toList();
  bool _matchesGeneralSearch(LibraryBookItem book) =>
      _matchesBookSearch(book, _booksSearch.text);

  bool _matchesBookSearch(LibraryBookItem book, String query) {
    if (_searchScope == 'title') return _index.matchesTitle(book, query);
    if (_searchScope == 'title_author') {
      return _index.matchesTitleAuthor(book, query);
    }
    return query.trim().isEmpty || _fullSearchPaths.contains(book.bookPath);
  }
  bool _matchesSectionFilters(LibraryBookItem book) {
    final type = BookMetadataOptions.normalizeType(book.book.bookType);
    final typeMatches = _selectedTypes.contains(type);
    if (!typeMatches) return false;
    if (!BookMetadataOptions.printedTypes.contains(type)) {
      return true;
    }
    final matching = book.book.matchesPrinted;
    return matching ? _includeMatchingPrinted : _includeNotMatchingPrinted;
  }
  LibraryBookItem? _bookByPath(String path) => _index.byPath[path];
  void _toggleCard() {
    setState(() => _showCard = !_showCard);
    if (_showCard) _loadSelectedDetails();
  }
  List<Widget> get _bookFragmentActions => buildLibraryBookActions(
        showCard: _showCard,
        onToggleCard: _toggleCard,
        onPickFiles: _pickDocxFiles,
        onPickFolder: _pickFolder,
      );
  void _selectBook(LibraryBookItem book) {
    _selectedPath = book.bookPath;
    _selectedPathNotifier.value = book.bookPath;
    if (_showCard) _selectedDetails.value = _repo.loadBookDetails(book);
  }
  void _loadSelectedDetails() => _selectedDetails.value =
      _selectedPath == null ? null : _repo.loadBookDetails(_bookByPath(_selectedPath!)!);
  void _debounceRebuild() => _searchDebouncer.run(_rebuildSearch);
  Future<void> _rebuildSearch() async {
    final revision = ++_searchRevision;
    if (_searchScope == 'full') {
      final paths = await _repo.searchFullBookPaths(_activeSearchQuery);
      if (revision != _searchRevision) return;
      _fullSearchPaths = paths;
    }
    if (mounted) setState(() {});
  }
  void _setSearchScope(String value) { _searchScope = value; _rebuildSearch(); }
  String get _activeSearchQuery => _tab == _sectionsTab
      ? _sectionBooksSearch.text
      : _tab == _authorsTab ? _authorBooksSearch.text : _booksSearch.text;
  void _openBook(LibraryBookItem book) => Navigator.of(context).pop(book.bookPath);
  void _toggleType(String type) {
    setState(() {
      _selectedTypes.contains(type)
          ? _selectedTypes.remove(type)
          : _selectedTypes.add(type);
    });
  }
  void _setTypeGroup(List<String> types, bool selected) {
    setState(() {
      selected ? _selectedTypes.addAll(types) : _selectedTypes.removeAll(types);
      final isPrintedGroup =
          types.length == BookMetadataOptions.printedTypes.length &&
          types.every(BookMetadataOptions.printedTypes.contains);
      if (isPrintedGroup) {
        _includeMatchingPrinted = selected;
        _includeNotMatchingPrinted = selected;
      }
    });
  } Future<void> _toggleFavorite(LibraryBookItem book, bool value) async {
    await _repo.setFavorite(book.bookPath, value);
    if (!mounted) return;
    setState(() {
      if (value) {
        _favorites.add(book.bookPath);
      } else {
        _favorites.remove(book.bookPath);
      }
    });
  } Widget _recentDeleteButton(LibraryBookItem book) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
      iconSize: 18,
      tooltip: 'حذف من مؤخرًا',
      icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
      onPressed: () => _removeRecent(book.bookPath),
    );
  }
  Future<void> _removeRecent(String path) async {
    await _repo.removeRecent(path);
    if (mounted) setState(() => _recentPaths.remove(path));
  }
  Future<void> _pickDocxFiles() async {
    if (await LibraryImportActions.pickDocxFiles(context) && mounted) {
      await _load();
    }
  }
  Future<void> _pickFolder() async {
    if (await LibraryImportActions.pickFolder(context) && mounted) {
      await _load();
    }
  }
}
