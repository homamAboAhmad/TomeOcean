import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_field.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_selectable_books_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_selectable_entities_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/Search/helpers/indexed_book_library_adapter.dart';
import 'package:golden_shamela/UI/Search/widgets/search_books_pane_chrome.dart';
import 'package:golden_shamela/UI/Search/widgets/search_book_selection_toolbar_state.dart';
import 'package:path/path.dart' as p;

class SearchEntityBooksPanel extends StatefulWidget {
  final List<LibraryEntityRow> rows;
  final String? viewedEntityId;
  final Set<String> selectedEntityIds;
  final String entityTitleHeader;
  final String entitySecondaryHeader;
  final String entitySearchHint;
  final bool showEntityCount;
  final String chooseEntityMessage;
  final String booksTitle;
  final Future<List<Map<String, dynamic>>> Function() loadBooks;
  final Map<String, bool> selectedBooks;
  final List<Author> authors;
  final Map<String, String> authorDeathYears;
  final Map<String, String> bookAuthorMap;
  final String bookSearchQuery;
  final String bookSearchScope;
  final Set<String> fullSearchPaths;
  final String? focusedBookPath;
  final ValueChanged<LibraryBookItem> onBookFocused;
  final SearchBookSelectionStateChanged? onBookSelectionStateChanged;
  final int selectAllRequest;
  final Widget? booksToolbar;
  final bool showBookCard;
  final Widget? bookCard;
  final ValueChanged<String> onEntitySelected;
  final Function(List<String>) onEntitiesAdded;
  final Function(List<String>) onEntitiesRemoved;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;

  const SearchEntityBooksPanel({
    super.key,
    required this.rows,
    required this.viewedEntityId,
    required this.selectedEntityIds,
    required this.entityTitleHeader,
    required this.entitySecondaryHeader,
    required this.entitySearchHint,
    required this.showEntityCount,
    required this.chooseEntityMessage,
    required this.booksTitle,
    required this.loadBooks,
    required this.selectedBooks,
    required this.onEntitySelected,
    required this.onEntitiesAdded,
    required this.onEntitiesRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    required this.bookSearchQuery,
    required this.bookSearchScope,
    required this.fullSearchPaths,
    required this.focusedBookPath,
    required this.onBookFocused,
    this.onBookSelectionStateChanged,
    this.selectAllRequest = 0,
    this.booksToolbar,
    this.showBookCard = false,
    this.bookCard,
    this.authors = const [],
    this.authorDeathYears = const {},
    this.bookAuthorMap = const {},
  });

  @override
  State<SearchEntityBooksPanel> createState() => _SearchEntityBooksPanelState();
}

class _SearchEntityBooksPanelState extends State<SearchEntityBooksPanel> {
  Set<String> _temporarilySelectedEntityIds = {};
  Set<String> _temporarilySelectedBookPaths = {};
  List<Map<String, dynamic>> _currentVisibleBooks = [];
  Future<List<Map<String, dynamic>>>? _booksFuture;
  final TextEditingController _entitiesSearchController =
      TextEditingController();
  final FocusNode _entitiesFocusNode = FocusNode();
  final FocusNode _booksFocusNode = FocusNode();
  int _handledSelectAllRequest = 0;

  @override
  void didUpdateWidget(covariant SearchEntityBooksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewedEntityId != oldWidget.viewedEntityId) {
      _booksFuture = null;
      _temporarilySelectedBookPaths.clear();
    }
  }

  @override
  void dispose() {
    _entitiesSearchController.dispose();
    _entitiesFocusNode.dispose();
    _booksFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LibrarySplitPane(
      axis: Axis.horizontal,
      first: _booksPane(),
      second: _entitiesPane(),
      initialRatio: 0.5,
    );
  }

  Widget _entitiesPane() {
    final rows = _filteredEntityRows;
    return GestureDetector(
      onTap: _entitiesFocusNode.requestFocus,
      child: Focus(
        focusNode: _entitiesFocusNode,
        autofocus: true,
        onKeyEvent: (_, event) => _handleEntitiesKeyEvent(event),
        child: Column(
          children: [
            _entitiesSearchBar(),
            Expanded(
              child: LibrarySelectableEntitiesPanel(
                rows: rows,
                selectedId: widget.viewedEntityId,
                checkedIds: _temporarilySelectedEntityIds,
                highlightedIds: widget.selectedEntityIds,
                titleHeader: widget.entityTitleHeader,
                secondaryHeader: widget.entitySecondaryHeader,
                showCountColumn: widget.showEntityCount,
                onSelected: widget.onEntitySelected,
                onCheckedChanged: _setTemporaryEntitySelection,
                onToggleAll: () => _toggleSelectAllEntities(rows),
                onAdd: _addEntities,
                onRemove: _removeEntities,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entitiesSearchBar() {
    return Container(
      height: LibraryDesignTokens.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        color: LibraryDesignTokens.surface,
        border: Border(bottom: BorderSide(color: LibraryDesignTokens.divider)),
      ),
      child: LibrarySearchField(
        controller: _entitiesSearchController,
        hint: widget.entitySearchHint,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _booksPane() {
    final card = widget.bookCard;
    if (widget.viewedEntityId == null) {
      _handledSelectAllRequest = widget.selectAllRequest;
      _notifyBookSelectionState(const []);
      return SearchBooksPaneChrome(
        toolbar: widget.booksToolbar,
        showCard: false,
        card: card ?? const SizedBox.shrink(),
        child: Center(child: Text(widget.chooseEntityMessage)),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _booksFuture ??= widget.loadBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SearchBooksPaneChrome(
            toolbar: widget.booksToolbar,
            showCard: false,
            card: card ?? const SizedBox.shrink(),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final books = _filterBooks(snapshot.data ?? []);
        _currentVisibleBooks = books;
        _handleSelectAllRequest(books);
        _notifyBookSelectionState(books);
        return SearchBooksPaneChrome(
          toolbar: widget.booksToolbar,
          showCard: widget.showBookCard && card != null,
          card: card ?? const SizedBox.shrink(),
          child: GestureDetector(
            onTap: _booksFocusNode.requestFocus,
            child: Focus(
              focusNode: _booksFocusNode,
              onKeyEvent: (_, event) => _handleBooksKeyEvent(event),
              child: LibrarySelectableBooksPanel(
                books: IndexedBookLibraryAdapter.toItems(
                  books,
                  authors: widget.authors,
                  bookAuthorMap: widget.bookAuthorMap,
                  authorDeathYears: widget.authorDeathYears,
                ),
                checkedPaths: _temporarilySelectedBookPaths,
                highlightedPaths: _selectedBookPaths,
                selectedPath: widget.focusedBookPath,
                onSelected: widget.onBookFocused,
                onCheckedChanged: (item, selected) =>
                    _setTemporaryBookSelection(item.bookPath, selected),
                onAdd: _addBooks,
                onRemove: _removeBooks,
              ),
            ),
          ),
        );
      },
    );
  }

  Set<String> get _selectedBookPaths => widget.selectedBooks.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toSet();

  List<LibraryEntityRow> get _filteredEntityRows {
    final query = _entitiesSearchController.text;
    if (LibraryTextNormalizer.normalize(query).isEmpty) return widget.rows;
    return widget.rows.where((row) {
      return LibraryTextNormalizer.contains(row.title, query) ||
          LibraryTextNormalizer.contains(row.secondary ?? '', query);
    }).toList();
  }

  List<Map<String, dynamic>> _filterBooks(List<Map<String, dynamic>> books) {
    final query = LibraryTextNormalizer.normalize(widget.bookSearchQuery);
    if (query.isEmpty) return books;
    final items = IndexedBookLibraryAdapter.toItems(
      books,
      authors: widget.authors,
      bookAuthorMap: widget.bookAuthorMap,
      authorDeathYears: widget.authorDeathYears,
    );
    final matches = <String>{};
    for (final item in items) {
      final matchesQuery = widget.bookSearchScope == 'title'
          ? item.normalizedTitle.contains(query)
          : widget.bookSearchScope == 'full'
              ? widget.fullSearchPaths.contains(_normalizePath(item.bookPath))
              : item.normalizedTitleAuthor.contains(query);
      if (matchesQuery) matches.add(item.bookPath);
    }
    return books
        .where((book) => matches.contains(book['book_path'] as String))
        .toList();
  }

  String _normalizePath(String path) => p.normalize(path).toLowerCase();

  void _notifyBookSelectionState(List<Map<String, dynamic>> books) {
    final callback = widget.onBookSelectionStateChanged;
    if (callback == null) return;
    final paths = books.map((book) => book['book_path'] as String).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(
        visibleBookPaths: paths,
        checkedBookPaths: Set.of(_temporarilySelectedBookPaths),
        onToggleAll: () => _toggleSelectAllBooks(books),
      );
    });
  }

  void _handleSelectAllRequest(List<Map<String, dynamic>> books) {
    if (_handledSelectAllRequest == widget.selectAllRequest) return;
    _handledSelectAllRequest = widget.selectAllRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toggleSelectAllBooks(books);
    });
  }

  void _setTemporaryEntitySelection(String id, bool selected) {
    setState(() {
      selected
          ? _temporarilySelectedEntityIds.add(id)
          : _temporarilySelectedEntityIds.remove(id);
    });
  }

  void _setTemporaryBookSelection(String path, bool selected) {
    setState(() {
      selected
          ? _temporarilySelectedBookPaths.add(path)
          : _temporarilySelectedBookPaths.remove(path);
    });
  }

  void _addEntities() =>
      _applyAndClear(_temporarilySelectedEntityIds, widget.onEntitiesAdded);

  void _removeEntities() =>
      _applyAndClear(_temporarilySelectedEntityIds, widget.onEntitiesRemoved);

  void _addBooks() =>
      _applyAndClear(_temporarilySelectedBookPaths, widget.onBooksAdded);

  void _removeBooks() =>
      _applyAndClear(_temporarilySelectedBookPaths, widget.onBooksRemoved);

  void _applyAndClear(Set<String> selection, Function(List<String>) action) {
    if (selection.isEmpty) return;
    action(selection.toList());
    setState(selection.clear);
  }

  KeyEventResult _handleEntitiesKeyEvent(KeyEvent event) =>
      _handleSelectionKeyEvent(event, () {
        _toggleSelectAllEntities(_filteredEntityRows);
      });

  KeyEventResult _handleBooksKeyEvent(KeyEvent event) =>
      _handleSelectionKeyEvent(event, () {
        _toggleSelectAllBooks(_currentVisibleBooks);
      });

  KeyEventResult _handleSelectionKeyEvent(
    KeyEvent event,
    VoidCallback selectAll,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      selectAll();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleSelectAllEntities(List<LibraryEntityRow> rows) {
    final visibleIds = rows.map((row) => row.id).toSet();
    setState(() {
      final allVisibleSelected = visibleIds.isNotEmpty &&
          visibleIds.every(_temporarilySelectedEntityIds.contains);
      allVisibleSelected
          ? _temporarilySelectedEntityIds.removeAll(visibleIds)
          : _temporarilySelectedEntityIds.addAll(visibleIds);
    });
  }

  void _toggleSelectAllBooks(List<Map<String, dynamic>> books) {
    setState(() {
      final visiblePaths =
          books.map((book) => book['book_path'] as String).toSet();
      final allVisibleSelected = visiblePaths.isNotEmpty &&
          visiblePaths.every(_temporarilySelectedBookPaths.contains);
      if (allVisibleSelected) {
        _temporarilySelectedBookPaths.removeAll(visiblePaths);
      } else {
        _temporarilySelectedBookPaths.addAll(visiblePaths);
      }
    });
  }
}
