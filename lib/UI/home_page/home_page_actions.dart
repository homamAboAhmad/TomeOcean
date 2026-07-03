part of '../HomePage.dart';

extension _HomePageActions on _HomePageState {
  Future<void> _openLibraryPicker({
    HomePageTabSpace? space,
    String? sectionId,
  }) async {
    final selected = await showLibraryPickerDialog(
      context,
      initialSectionId: sectionId,
    );
    if (selected != null && mounted) {
      await _onBookSelected(
        File(selected.bookPath),
        space: space,
        openSource: selected.source,
      );
    }
  }

  Future<void> _addBookFromHome() async {
    await LibraryImportActions.pickDocxFiles(context);
  }

  void _openLibraryDataTab({HomePageTabSpace? space, bool save = true}) {
    final target = space ?? _activeSpace;
    setState(() {
      target.libraryDataTab ??= const LibraryDataTab(id: 'library-data');
      target.selectedBookP =
          target.openedBooks.length + target.searchResultsTabs.length;
    });
    if (save) _saveOpenTabs();
  }

  Future<void> _openLibraryControlPanel() async {
    await showLibraryControlDialog(context);
  }

  void _openRecitedTextTab({HomePageTabSpace? space, bool save = true}) {
    final target = space ?? _activeSpace;
    setState(() {
      target.recitedTextTab ??= const RecitedTextTab(id: 'recited-text');
      target.selectedBookP = target.openedBooks.length +
          target.searchResultsTabs.length +
          (target.libraryDataTab == null ? 0 : 1);
    });
    if (save) _saveOpenTabs();
  }

  void _setSplitMode(HomePageSplitMode mode) {
    if (mode == HomePageSplitMode.detachCurrentTab) {
      this._detachCurrentTab();
      return;
    }
    if (mode == HomePageSplitMode.returnDetachedTabs) {
      this._returnDetachedTabs();
      return;
    }

    setState(() {
      final splittingFromSingle =
          _splitMode == HomePageSplitMode.single &&
          mode != HomePageSplitMode.single;
      _splitMode = mode;
      if (splittingFromSingle && _spaces[0].moveSelectedTabTo(_spaces[1])) {
        _activeSpaceIndex = 1;
        return;
      }
      if (mode == HomePageSplitMode.single) {
        _spaces[0].absorbTabsFrom(
          _spaces[1],
          selectSourceTab: _activeSpaceIndex == 1,
        );
        _activeSpaceIndex = 0;
      }
    });
  }

  void _activateSpace(HomePageTabSpace space) {
    final index = _spaces.indexOf(space);
    if (index == -1 || index == _activeSpaceIndex) return;
    setState(() => _activeSpaceIndex = index);
  }

  Future<void> _onBookSelected(
    File book, {
    HomePageTabSpace? space,
    int? pageNumber,
    bool fromSearchResults = false,
    String openSource = BookOpenSource.other,
  }) async {
    final target = space ?? _activeSpace;
    target.filePath = book.path;

    if (!fromSearchResults) {
      AppState().clearSearchHighlight();
    }

    WordDocument tempDoc = WordDocument.empty();
    WordDocument? openedDoc;
    tempDoc.title = AppStoragePaths.displayTitleFromPath(book.path);
    tempDoc.openSource = openSource;
    tempDoc.isLoading.value = true;
    tempDoc.loadingMessage.value = 'جاري التحضير...';

    setState(() {
      target.openedBooks.add(tempDoc);
      target.selectedBookP = target.openedBooks.length - 1;
    });

    BooksMetadataDatabase().recordRecentBook(book.path).catchError((e) {
      debugPrint('Failed to record recent book: $e');
    });

    BooksMetadataDatabase().getBookByPath(book.path).then((storedBook) {
      if (!mounted || storedBook?.title.isNotEmpty != true) return;
      final idx = target.openedBooks.indexOf(tempDoc);
      if (idx == -1) return;
      setState(() => target.openedBooks[idx].title = storedBook!.title);
    }).catchError((e) {
      debugPrint('Failed to load book title: $e');
    });

    WordDocument? loadedDoc = await _bookManagement!.readDocxFile(
      book.path,
      tempDoc: tempDoc,
      deferArchiveLoad: fromSearchResults,
      onArchiveLoaded: () {
        if (mounted) setState(() {});
      },
    );

    if (loadedDoc != null && mounted) {
      loadedDoc.sourcePath = book.path;
      loadedDoc.openSource = openSource;
      openedDoc = loadedDoc;
      BookSourceChangeMonitor.registerCompletionCallback(
        book.path,
        tempDoc,
        () async {
          final updated = await _replaceBookAfterBackgroundUpdate(
            target,
            () => openedDoc ?? tempDoc,
            book.path,
            openSource,
            fromSearchResults,
          );
          if (updated != null) openedDoc = updated;
        },
      );
      final rememberedPage =
          pageNumber ?? BookPositionStore.instance.load(book.path, openSource);
      setState(() {
        int idx = target.openedBooks.indexOf(tempDoc);
        if (idx != -1) {
          target.openedBooks[idx] = loadedDoc;
          if (rememberedPage != null) {
            target.openedBooks[idx].currentPage = rememberedPage;
          }
        }
      });
      _saveOpenTabs();
    } else if (mounted) {
      setState(() {
        target.openedBooks.remove(tempDoc);
        target.normalizeSelectedTab();
      });
      _saveOpenTabs();
    }
  }

  Future<WordDocument?> _replaceBookAfterBackgroundUpdate(
    HomePageTabSpace target,
    WordDocument? Function() currentDocument,
    String bookPath,
    String openSource,
    bool fromSearchResults,
  ) async {
    if (!mounted) return null;
    final current = currentDocument();
    if (current == null) return null;
    final index = target.openedBooks.indexOf(current);
    if (index == -1) return null;
    final currentPage = target.openedBooks[index].currentPage;

    final updated = await _bookManagement!.readDocxFile(
      bookPath,
      deferArchiveLoad: fromSearchResults,
      onArchiveLoaded: () {
        if (mounted) setState(() {});
      },
    );
    if (updated == null || !mounted) return null;

    final maxPage = updated.pageFilePaths.isEmpty
        ? 0
        : updated.pageFilePaths.length - 1;
    updated.sourcePath = bookPath;
    updated.openSource = openSource;
    updated.currentPage = currentPage.clamp(0, maxPage).toInt();

    setState(() {
      final currentIndex = target.openedBooks.indexOf(current);
      if (currentIndex != -1) target.openedBooks[currentIndex] = updated;
    });
    _saveOpenTabs();
    return updated;
  }

  void _handleSearchResultNavigation(
    String bookPath,
    int pageNumber, {
    HomePageTabSpace? space,
  }) async {
    if (AppOtherSettings.instance.draft().showSearchBookIndexByDefault) {
      showBookSideBar = true;
    }
    final openComment = AppState().openCommentPanelForSearchTarget;
    AppState().setSearchTarget(
      pageNumber,
      null,
      openCommentPanel: openComment,
    );
    await _onBookSelected(
      File(bookPath),
      space: space,
      pageNumber: pageNumber,
      fromSearchResults: true,
    );
  }

  Future<WordDocument?> _loadBookInsideSearchTab(
    String bookPath,
    int pageNumber,
  ) async {
    BooksMetadataDatabase().recordRecentBook(bookPath).catchError((e) {
      debugPrint('Failed to record recent book: $e');
    });

    final document = await _bookManagement!.readDocxFile(
      bookPath,
      deferArchiveLoad: true,
      onArchiveLoaded: () {
        if (mounted) setState(() {});
      },
    );
    document?.currentPage = pageNumber;
    return document;
  }

  void _closeBook(HomePageTabSpace space, int i) {
    setState(() {
      if (i >= space.openedBooks.length) {
        final tabIndex = i - space.openedBooks.length;
        if (tabIndex >= 0 && tabIndex < space.searchResultsTabs.length) {
          space.searchResultsTabs.removeAt(tabIndex);
        }
      } else if (i >= 0) {
        space.openedBooks.removeAt(i);
      }
      space.normalizeSelectedTab();
    });
    _saveOpenTabs();
  }

  void _closeSearchResultsTab(HomePageTabSpace space, String tabId) {
    setState(() {
      space.searchResultsTabs.removeWhere((tab) => tab.id == tabId);
      space.normalizeSelectedTab();
    });
    _saveOpenTabs();
  }

  void _closeLibraryDataTab(HomePageTabSpace space) {
    setState(() {
      space.libraryDataTab = null;
      space.normalizeSelectedTab();
    });
    _saveOpenTabs();
  }

  void _closeRecitedTextTab(HomePageTabSpace space) {
    setState(() {
      space.recitedTextTab = null;
      space.normalizeSelectedTab();
    });
    _saveOpenTabs();
  }

  void _switchToBook(HomePageTabSpace space, int i) {
    setState(() {
      _activeSpaceIndex = _spaces.indexOf(space);
      space.selectedBookP = i;
    });
  }

}
