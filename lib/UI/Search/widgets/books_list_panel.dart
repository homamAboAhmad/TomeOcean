import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_selectable_books_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/Search/helpers/indexed_book_library_adapter.dart';
import 'package:golden_shamela/UI/Search/helpers/indexed_book_title_resolver.dart';
import 'package:golden_shamela/UI/Search/widgets/search_book_selection_toolbar_state.dart';
import 'package:path/path.dart' as p;

class BooksListPanel extends StatefulWidget {
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final Map<String, bool> selectedBooks;
  final TextEditingController searchController;
  final List<Author>? authors;
  final Map<String, String>? authorDeathYears;
  final Map<String, String> bookAuthorMap;
  final String searchScope;
  final Set<String> fullSearchPaths;
  final String? focusedBookPath;
  final ValueChanged<LibraryBookItem> onBookFocused;
  final SearchBookSelectionStateChanged? onSelectionStateChanged;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;
  final int selectAllRequest;

  const BooksListPanel({
    super.key,
    required this.filteredIndexedBooks,
    required this.selectedBooks,
    required this.searchController,
    this.authors,
    this.authorDeathYears,
    this.bookAuthorMap = const {},
    required this.searchScope,
    required this.fullSearchPaths,
    required this.focusedBookPath,
    required this.onBookFocused,
    this.onSelectionStateChanged,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    this.selectAllRequest = 0,
  });

  @override
  State<BooksListPanel> createState() => _BooksListPanelState();
}

class _BooksListPanelState extends State<BooksListPanel> {
  Set<String> _temporarilySelectedBookPaths = {};
  final FocusNode _booksFocusNode = FocusNode();
  int _handledSelectAllRequest = 0;

  @override
  void dispose() {
    _booksFocusNode.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterBooks(String searchQuery) {
    final query = LibraryTextNormalizer.normalize(searchQuery);
    if (query.isEmpty) return widget.filteredIndexedBooks;
    return widget.filteredIndexedBooks.where((book) {
      final bookPath = book['book_path'] as String;
      final bookTitle = LibraryTextNormalizer.normalize(
        IndexedBookTitleResolver.resolve(book),
      );
      final authorId = IndexedBookLibraryAdapter.resolveAuthorId(
        book,
        bookAuthorMap: widget.bookAuthorMap,
      );
      final authorName = LibraryTextNormalizer.normalize(_authorName(authorId));
      if (widget.searchScope == 'title') {
        return bookTitle.contains(query);
      }
      if (widget.searchScope == 'full') {
        return widget.fullSearchPaths.contains(_normalizePath(bookPath));
      }
      return bookTitle.contains(query) || authorName.contains(query);
    }).toList();
  }

  String _authorName(String? authorId) {
    if (authorId == null || authorId.isEmpty || widget.authors == null) {
      return '';
    }
    return widget.authors!
        .firstWhere(
          (author) => author.id == authorId,
          orElse: () => Author(id: '', name: '', description: ''),
        )
        .name;
  }

  String _normalizePath(String path) => p.normalize(path).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final filteredBooks =
        _filterBooks(widget.searchController.text.toLowerCase());
    final items = IndexedBookLibraryAdapter.toItems(
      filteredBooks,
      authors: widget.authors ?? const [],
      bookAuthorMap: widget.bookAuthorMap,
      authorDeathYears: widget.authorDeathYears ?? const {},
    );
    _handleSelectAllRequest(filteredBooks);
    _notifySelectionState(filteredBooks);
    return GestureDetector(
      onTap: _booksFocusNode.requestFocus,
      child: Focus(
        focusNode: _booksFocusNode,
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event, filteredBooks),
        child: LibrarySelectableBooksPanel(
          books: items,
          checkedPaths: _temporarilySelectedBookPaths,
          highlightedPaths: _selectedBookPaths,
          selectedPath: widget.focusedBookPath,
          onSelected: widget.onBookFocused,
          onCheckedChanged: _setTemporaryBookSelection,
          onAdd: _addBooks,
          onRemove: _removeBooks,
        ),
      ),
    );
  }

  Set<String> get _selectedBookPaths => widget.selectedBooks.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toSet();

  void _notifySelectionState(List<Map<String, dynamic>> books) {
    final callback = widget.onSelectionStateChanged;
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

  void _setTemporaryBookSelection(LibraryBookItem item, bool selected) {
    setState(() => selected
        ? _temporarilySelectedBookPaths.add(item.bookPath)
        : _temporarilySelectedBookPaths.remove(item.bookPath));
  }

  void _addBooks() => _applyAndClear(widget.onBooksAdded);

  void _removeBooks() => _applyAndClear(widget.onBooksRemoved);

  void _applyAndClear(Function(List<String>) action) {
    if (_temporarilySelectedBookPaths.isEmpty) return;
    action(_temporarilySelectedBookPaths.toList());
    setState(_temporarilySelectedBookPaths.clear);
  }

  KeyEventResult _handleKeyEvent(
    KeyEvent event,
    List<Map<String, dynamic>> filteredBooks,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      _toggleSelectAllBooks(filteredBooks);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
