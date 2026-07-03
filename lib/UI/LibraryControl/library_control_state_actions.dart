part of 'library_control_dialog.dart';

extension _LibraryControlStateActions on _LibraryControlDialogState {
  KeyEventResult _handleEscapeKey() {
    if (_tab == _LibraryControlDialogState._booksTab &&
        _checkedBookPaths.isNotEmpty) {
      setState(_checkedBookPaths.clear);
      return KeyEventResult.handled;
    }
    Navigator.of(context).pop();
    return KeyEventResult.handled;
  }

  void _deleteCurrentTab() {
    if (_busy) return;
    if (_tab == _LibraryControlDialogState._booksTab) {
      _deleteSelectedBooks();
    } else if (_tab == _LibraryControlDialogState._authorsTab) {
      _deleteAuthor();
    } else {
      _deleteSection();
    }
  }

  void _scheduleReload() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  String get _searchHint {
    if (_tab == _LibraryControlDialogState._authorsTab) return 'بحث في المؤلفين';
    if (_tab == _LibraryControlDialogState._sectionsTab) return 'بحث في التصنيفات';
    return 'بحث في الكتب أو المؤلفين';
  }

  int get _visibleCount => _tab == _LibraryControlDialogState._booksTab
      ? _books.length
      : (_tab == _LibraryControlDialogState._authorsTab
          ? _authors.length
          : _sections.length);

  LibraryBookItem? get _selectedBook {
    for (final book in _books) {
      if (book.bookPath == _selectedBookPath) return book;
    }
    return null;
  }

  Future<void> _reload() async {
    _searchDebounce?.cancel();
    final ticket = ++_reloadSerial;
    final tab = _tab;
    final query = _search.text;
    setState(() => _busy = true);
    try {
      if (tab == _LibraryControlDialogState._booksTab) {
        final books = await _repo.loadBooks(query: query);
        if (!_canApplyReload(ticket, tab)) return;
        setState(() => _books = books);
      } else if (tab == _LibraryControlDialogState._authorsTab) {
        final authors = await _repo.loadAuthors(query);
        if (!_canApplyReload(ticket, tab)) return;
        setState(() => _authors = authors);
      } else {
        final sections = await _repo.loadSections(query);
        if (!_canApplyReload(ticket, tab)) return;
        setState(() => _sections = sections);
      }
    } finally {
      if (mounted && ticket == _reloadSerial) {
        setState(() {
          _busy = false;
          _progressDone = null;
          _progressTotal = null;
          _progressText = null;
        });
      }
    }
  }

  bool _canApplyReload(int ticket, String tab) {
    return mounted && ticket == _reloadSerial && tab == _tab;
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(dialogContext, false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              Navigator.pop(dialogContext, true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AlertDialog(
            title: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('موافق'),
              ),
            ],
          ),
        ),
      ) ??
      false;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
