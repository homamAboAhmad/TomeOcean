part of 'library_control_dialog.dart';

extension _LibraryControlExportActions on _LibraryControlDialogState {
  Future<void> _exportSelectedBooks() async {
    final paths = _checkedBookPaths.isEmpty
        ? [_selectedBookPath].whereType<String>().toSet()
        : _checkedBookPaths;
    final books = _books.where((book) => paths.contains(book.bookPath)).toList();
    await _exportBooks(books);
  }

  Future<void> _exportAuthorBooks() async {
    final id = _selectedAuthorId;
    if (id == null) return;
    await _exportBooks(await _repo.loadBooks(authorId: id, limit: null));
  }

  Future<void> _exportSectionBooks() async {
    final id = _selectedSectionId;
    if (id == null) return;
    await _exportBooks(await _repo.loadBooks(sectionId: id, limit: null));
  }

  Future<void> _exportBooks(List<LibraryBookItem> books) async {
    if (books.isEmpty) return;
    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory == null) return;
    setState(() {
      _busy = true;
      _progressDone = 0;
      _progressTotal = books.length;
      _progressText = _exportProgressText(0, books.length);
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    late final int count;
    try {
      count = await _exporter.exportBooks(
        books,
        directory,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
            _progressText = _exportProgressText(done, total);
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressDone = null;
          _progressTotal = null;
          _progressText = null;
        });
      }
    }
    _message('تم تصدير $count ملف');
  }

  String _exportProgressText(int done, int total) {
    if (total <= 1) return 'جاري تصدير الكتاب';
    return 'جاري تصدير الكتب: $done من $total';
  }
}
