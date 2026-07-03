part of '../HomePage.dart';

extension _HomePageSavedItems on _HomePageState {
  void _openSavedItemsDialog() {
    showSavedItemsDialog(
      context: context,
      createCurrentSession: _createCurrentSessionRecord,
      onOpenSession: (session) {
        Navigator.of(context).pop();
        unawaited(_openWorkSession(session));
      },
      onOpenResults: (result) {
        Navigator.of(context).pop();
        _openSavedSearchResults(result);
      },
    );
  }

  WorkSessionRecord _createCurrentSessionRecord(String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final books = <WorkSessionBookRecord>[];
    final searchTabs = <WorkSessionSearchRecord>[];
    var selectedIndex = 0;
    var offset = 0;

    for (var i = 0; i < _spaces.length; i++) {
      final space = _spaces[i];
      if (i == _activeSpaceIndex) selectedIndex = offset + space.selectedBookP;
      for (final book in space.openedBooks) {
        final path = book.sourcePath ?? '';
        if (path.isEmpty) continue;
        books.add(WorkSessionBookRecord(
          bookPath: path,
          pageIndex: book.currentPage,
          source: book.openSource,
          title: book.title,
        ));
      }
      searchTabs.addAll(
        space.searchResultsTabs.map(WorkSessionSearchRecord.fromTab),
      );
      offset += space.totalTabs;
    }

    return WorkSessionRecord(
      id: now.toString(),
      name: name.trim().isEmpty ? 'جلسة عمل محفوظة' : name.trim(),
      createdAt: now,
      orderIndex: 0,
      kind: WorkSessionRecord.savedKind,
      selectedIndex: selectedIndex,
      books: books,
      searchTabs: searchTabs,
    );
  }

  Future<void> _openWorkSession(WorkSessionRecord session) async {
    setState(() {
      _splitMode = HomePageSplitMode.single;
      _activeSpaceIndex = 0;
      for (final space in _spaces) {
        space.closeAllTabs();
      }
    });

    final target = _spaces.first;
    for (final book in session.books) {
      if (!mounted) return;
      await _onBookSelected(
        File(book.bookPath),
        space: target,
        pageNumber: book.pageIndex,
        openSource: book.source,
      );
    }

    if (!mounted) return;
    final loadedSearchTabs = <WorkSessionSearchRecord>[];
    for (final tab in session.searchTabs) {
      loadedSearchTabs.add(await WorkSessionStore().loadSearchTabResults(tab));
    }
    if (!mounted) return;

    setState(() {
      for (final loadedTab in loadedSearchTabs) {
        target.searchResultsTabs.add(SearchResultsTab(
          id: '${session.id}_${target.searchResultsTabs.length}',
          results: loadedTab.results,
          totalCount: loadedTab.totalCount,
          searchQueries: loadedTab.searchQueries,
          morphologicalSearch: loadedTab.morphologicalSearch,
          searchSnapshot: loadedTab.searchSnapshot,
          isSearching: false,
        ));
      }
      target.selectedBookP = session.selectedIndex.clamp(
        0,
        target.totalTabs == 0 ? 0 : target.totalTabs - 1,
      ).toInt();
    });
    _saveOpenTabs();
  }

  void _openSavedSearchResults(SavedSearchResultsRecord result) {
    final space = _activeSpace;
    setState(() {
      final tabId = DateTime.now().millisecondsSinceEpoch.toString();
      space.searchResultsTabs.add(SearchResultsTab(
        id: tabId,
        results: result.results
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
        totalCount: result.totalCount,
        searchQueries: List<String>.from(result.searchQueries),
        morphologicalSearch: result.morphologicalSearch,
        searchSnapshot: result.searchSnapshot,
        isSearching: false,
      ));
      space.selectedBookP =
          space.openedBooks.length + space.searchResultsTabs.length - 1;
    });
  }
}
