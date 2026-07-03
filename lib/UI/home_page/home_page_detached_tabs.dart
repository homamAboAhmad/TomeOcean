part of '../HomePage.dart';

enum DetachedTabKind { book, searchResults, libraryData, recitedText }

class _DetachedHomeTabRecord {
  final String id;
  final int originSpaceIndex;
  final int originTabIndex;
  final DetachedTabKind kind;
  final WordDocument? book;
  final SearchResultsTab? searchTab;
  final LibraryDataTab? libraryDataTab;
  final RecitedTextTab? recitedTextTab;
  Offset? offset;
  Size? size;

  _DetachedHomeTabRecord({
    required this.id,
    required this.originSpaceIndex,
    required this.originTabIndex,
    required this.kind,
    required this.offset,
    required this.size,
    this.book,
    this.searchTab,
    this.libraryDataTab,
    this.recitedTextTab,
  });

  String get title {
    switch (kind) {
      case DetachedTabKind.book:
        return book?.title ?? '';
      case DetachedTabKind.searchResults:
        return searchTab?.title ?? '';
      case DetachedTabKind.libraryData:
        return libraryDataTab?.title ?? '';
      case DetachedTabKind.recitedText:
        return recitedTextTab?.title ?? '';
    }
  }
}

extension _HomePageDetachedTabs on _HomePageState {
  static const double _minDetachedWidth = 360;
  static const double _minDetachedHeight = 240;
  static const double _detachedMargin = 12;

  Future<void> _detachCurrentTab() async {
    final space = _activeSpace;
    if (space.totalTabs == 0) return;

    final record = _takeSelectedDetachedRecord(space);
    if (record == null) return;

    setState(() {
      _detachedTabs.add(record);
      space.normalizeSelectedTab();
    });
  }

  Future<void> _returnDetachedTabs() async {
    if (_detachedTabs.isEmpty) return;
    setState(() {
      for (final record in List<_DetachedHomeTabRecord>.of(_detachedTabs)) {
        _restoreDetachedTab(record);
      }
      _detachedTabs.clear();
      _activeSpaceIndex = 0;
    });
  }

  bool _switchDetachedTab(int direction) {
    if (_detachedTabs.length <= 1) return false;
    setState(() {
      if (direction > 0) {
        _detachedTabs.insert(0, _detachedTabs.removeLast());
      } else {
        _detachedTabs.add(_detachedTabs.removeAt(0));
      }
    });
    return true;
  }

  Widget _buildDetachedTabsLayer() {
    if (_detachedTabs.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounds = constraints.biggest;
          return Stack(
            children: [
              for (final record in _detachedTabs)
                _positionedDetachedWindow(record, bounds),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedDetachedWindow(
    _DetachedHomeTabRecord record,
    Size bounds,
  ) {
    _clampDetachedRecord(record, bounds);
    final offset = _offsetFor(record);
    final size = _sizeFor(record);
    return Positioned(
      key: ValueKey(record.id),
      left: offset.dx,
      top: offset.dy,
      width: size.width,
      height: size.height,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _activateDetachedTab(record),
        child: Stack(
          children: [
            Positioned.fill(child: _detachedWindow(record, bounds)),
            ...this._resizeBorders(record, bounds),
          ],
        ),
      ),
    );
  }

  Offset _offsetFor(_DetachedHomeTabRecord record) {
    return record.offset ??= Offset(24 + _detachedTabs.indexOf(record) * 24, 24);
  }

  Size _sizeFor(_DetachedHomeTabRecord record) {
    return record.size ??= const Size(760, 560);
  }

  void _activateDetachedTab(_DetachedHomeTabRecord record) {
    if (_detachedTabs.isEmpty || identical(_detachedTabs.last, record)) return;
    setState(() {
      if (_detachedTabs.remove(record)) _detachedTabs.add(record);
    });
  }

  void _clampDetachedRecord(_DetachedHomeTabRecord record, Size bounds) {
    final maxWidth = _clampDouble(
      bounds.width - _detachedMargin * 2,
      _minDetachedWidth,
      double.infinity,
    );
    final maxHeight = _clampDouble(
      bounds.height - _detachedMargin * 2,
      _minDetachedHeight,
      double.infinity,
    );
    final size = _sizeFor(record);
    record.size = Size(
      _clampDouble(size.width, _minDetachedWidth, maxWidth),
      _clampDouble(size.height, _minDetachedHeight, maxHeight),
    );

    final offset = _offsetFor(record);
    final clampedSize = _sizeFor(record);
    final maxLeft = _clampDouble(
      bounds.width - clampedSize.width,
      0,
      double.infinity,
    );
    final maxTop = _clampDouble(
      bounds.height - clampedSize.height,
      0,
      double.infinity,
    );
    record.offset = Offset(
      _clampDouble(offset.dx, 0, maxLeft),
      _clampDouble(offset.dy, 0, maxTop),
    );
  }

  Widget _detachedWindow(_DetachedHomeTabRecord record, Size bounds) {
    return Material(
      elevation: 12,
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                record.offset = _offsetFor(record) + details.delta;
                _clampDetachedRecord(record, bounds);
              });
            },
            child: Container(
              height: 36,
              color: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إرجاع التبويب',
                    icon: const LibraryIcon(LibraryIconType.returnArrow, size: 18),
                    color: secondaryColor,
                    onPressed: () => _returnDetachedTab(record),
                  ),
                  Expanded(
                    child: Text(
                      record.title,
                      overflow: TextOverflow.ellipsis,
                      style: normalStyle(color: secondaryColor),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    icon: const LibraryIcon(LibraryIconType.close, size: 18),
                    color: secondaryColor,
                    onPressed: () => _returnDetachedTab(record),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _detachedContent(record)),
        ],
      ),
    );
  }

  double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  Widget _detachedContent(_DetachedHomeTabRecord record) {
    switch (record.kind) {
      case DetachedTabKind.book:
        final book = record.book!;
        return DocViewer(
          book,
          key: ObjectKey(book),
          onBookSelected: (file) => _onBookSelected(file, space: _spaces[0]),
          onCloseBook: () => _returnDetachedTab(record),
        );
      case DetachedTabKind.searchResults:
        final tab = record.searchTab!;
        return ShamelaSearchView(
          key: ValueKey('detached_${tab.id}'),
          results: tab.results,
          totalCount: tab.totalCount,
          searchQueries: tab.searchQueries,
          morphologicalSearch: tab.morphologicalSearch,
          searchSnapshot: tab.searchSnapshot,
          isSearching: tab.isSearching,
          onNewSearch: (_, __) {},
          onOpenBookFull: (bookPath, pageNumber) =>
              _handleSearchResultNavigation(
            bookPath,
            pageNumber,
            space: _spaces[0],
          ),
        );
      case DetachedTabKind.libraryData:
        return const LibraryDataTabView();
      case DetachedTabKind.recitedText:
        return const RecitedTextTabView();
    }
  }

  void _returnDetachedTab(_DetachedHomeTabRecord record) {
    setState(() {
      if (_detachedTabs.remove(record)) _restoreDetachedTab(record);
    });
  }

  _DetachedHomeTabRecord? _takeSelectedDetachedRecord(HomePageTabSpace space) {
    final originSpaceIndex = _spaces.indexOf(space);
    final originTabIndex = space.selectedBookP;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final offset = Offset(24 + _detachedTabs.length * 24, 24);
    const size = Size(760, 560);

    if (originTabIndex < space.openedBooks.length) {
      return _DetachedHomeTabRecord(
        id: id,
        originSpaceIndex: originSpaceIndex,
        originTabIndex: originTabIndex,
        kind: DetachedTabKind.book,
        offset: offset,
        size: size,
        book: space.openedBooks.removeAt(originTabIndex),
      );
    }

    final searchIndex = originTabIndex - space.openedBooks.length;
    if (searchIndex >= 0 && searchIndex < space.searchResultsTabs.length) {
      return _DetachedHomeTabRecord(
        id: id,
        originSpaceIndex: originSpaceIndex,
        originTabIndex: originTabIndex,
        kind: DetachedTabKind.searchResults,
        offset: offset,
        size: size,
        searchTab: space.searchResultsTabs.removeAt(searchIndex),
      );
    }

    final dataIndex = space.openedBooks.length + space.searchResultsTabs.length;
    if (space.libraryDataTab != null && originTabIndex == dataIndex) {
      final tab = space.libraryDataTab;
      space.libraryDataTab = null;
      return _DetachedHomeTabRecord(
        id: id,
        originSpaceIndex: originSpaceIndex,
        originTabIndex: originTabIndex,
        kind: DetachedTabKind.libraryData,
        offset: offset,
        size: size,
        libraryDataTab: tab,
      );
    }

    final recitedIndex = dataIndex + (space.libraryDataTab == null ? 0 : 1);
    if (space.recitedTextTab != null && originTabIndex == recitedIndex) {
      final tab = space.recitedTextTab;
      space.recitedTextTab = null;
      return _DetachedHomeTabRecord(
        id: id,
        originSpaceIndex: originSpaceIndex,
        originTabIndex: originTabIndex,
        kind: DetachedTabKind.recitedText,
        offset: offset,
        size: size,
        recitedTextTab: tab,
      );
    }

    return null;
  }

  void _restoreDetachedTab(_DetachedHomeTabRecord record) {
    final spaceIndex =
        record.originSpaceIndex.clamp(0, _spaces.length - 1).toInt();
    final space = _spaces[spaceIndex];
    switch (record.kind) {
      case DetachedTabKind.book:
        final index =
            record.originTabIndex.clamp(0, space.openedBooks.length).toInt();
        space.openedBooks.insert(index, record.book!);
        space.selectedBookP = index;
        break;
      case DetachedTabKind.searchResults:
        final index = (record.originTabIndex - space.openedBooks.length)
            .clamp(0, space.searchResultsTabs.length)
            .toInt();
        space.searchResultsTabs.insert(index, record.searchTab!);
        space.selectedBookP = space.openedBooks.length + index;
        break;
      case DetachedTabKind.libraryData:
        space.libraryDataTab ??= record.libraryDataTab;
        space.selectedBookP =
            space.openedBooks.length + space.searchResultsTabs.length;
        break;
      case DetachedTabKind.recitedText:
        space.recitedTextTab ??= record.recitedTextTab;
        space.selectedBookP = space.openedBooks.length +
            space.searchResultsTabs.length +
            (space.libraryDataTab == null ? 0 : 1);
        break;
    }
    space.normalizeSelectedTab();
  }
}
