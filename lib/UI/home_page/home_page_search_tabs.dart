part of '../HomePage.dart';

extension _HomePageSearchTabs on _HomePageState {
  void _addSearchResultsTab(
    List<Map<String, dynamic>> results,
    int totalCount,
    List<String> searchQueries,
    bool morphologicalSearch,
  ) {
    final space = _activeSpace;
    setState(() {
      final tabId = DateTime.now().millisecondsSinceEpoch.toString();
      space.searchResultsTabs.add(SearchResultsTab(
        id: tabId,
        results: results,
        totalCount: totalCount,
        searchQueries: searchQueries,
        morphologicalSearch: morphologicalSearch,
      ));
      space.selectedBookP =
          space.openedBooks.length + space.searchResultsTabs.length - 1;
    });
  }

  void _performQuickSearchForTab(
    HomePageTabSpace space,
    String tabId,
    String query,
    bool morphological,
  ) {
    final searchSections = {
      'main': true,
      'footnote': true,
      'comment': true,
      'title': false,
    };
    final snapshot = SearchStateSnapshot(
      groupQueries: {
        'and': [query],
        'or': const [],
        'not': const [],
      },
      searchGrouping: 'all',
      searchSections: searchSections,
      options: const {
        'considerNumbers': true,
      },
    );
    final tabIndex = space.searchResultsTabs.indexWhere((t) => t.id == tabId);
    if (tabIndex != -1) {
      setState(() {
        space.searchResultsTabs[tabIndex].results = [];
        space.searchResultsTabs[tabIndex].totalCount = 0;
        space.searchResultsTabs[tabIndex].searchQueries = [query];
        space.searchResultsTabs[tabIndex].morphologicalSearch = morphological;
        space.searchResultsTabs[tabIndex].searchSnapshot = snapshot;
      });
    }

    _searchHandlers!.performSearchInMainWindow(
      groupControllersMap: <String, dynamic>{
        'and': [query],
        'or': <String>[],
        'not': <String>[],
      },
      searchGrouping: 'all',
      selectedBooksForSearch: [],
      searchSections: searchSections,
      morphologicalSearch: morphological,
      affixSearch: false,
      considerHamzas: false,
      considerDiacritics: false,
      considerNumbers: true,
      allPhrasesRequired: false,
      ordered: false,
      proximity: false,
      indexedBooks: AppState().cachedIndexedBooks ?? [],
      onSearchResultsUpdate: (results, totalCount, queries, morph) {
        if (mounted) {
          _updateSearchResultsTab(
            space,
            tabId,
            results,
            totalCount,
            queries,
            [query],
            morph,
            snapshot,
          );
        }
      },
    );
  }

  Future<void> _performHomeStartSearch(
    HomePageTabSpace space,
    String query,
    String? sectionId,
    String? sectionTitle,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await _searchHandlers!.openSearchWindow();
      return;
    }

    final spaceIndex = _spaces.indexOf(space);
    if (spaceIndex != -1 && spaceIndex != _activeSpaceIndex) {
      setState(() => _activeSpaceIndex = spaceIndex);
    }

    final booksLoader = IndexedBooksLoader();
    final cachedBooks = AppState().cachedIndexedBooks;
    final indexedBooks = cachedBooks != null && cachedBooks.isNotEmpty
        ? cachedBooks
        : await booksLoader.getIndexedBooks();
    if (indexedBooks.isEmpty) {
      if (mounted) {
        ShowSnackBar(
          context,
          'لا توجد كتب مفهرسة. يرجى فهرسة الكتب أولاً من شاشة الفهرسة.',
        );
      }
      return;
    }
    AppState().cachedIndexedBooks = indexedBooks;

    final selectedBooksForSearch = sectionId?.isNotEmpty == true
        ? <Map<String, dynamic>>[
            {
              'type': 'section',
              'name': sectionTitle ?? '',
              'sectionId': sectionId,
              'bookPath': null,
              'authorId': null,
            }
          ]
        : <Map<String, dynamic>>[];

    _performSearchInMainWindow(
      {
        'and': [trimmed],
        'or': <String>[],
        'not': <String>[],
      },
      'all',
      selectedBooksForSearch,
      const {
        'main': true,
        'footnote': true,
        'comment': true,
        'title': false,
      },
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
      indexedBooks,
    );
  }

  void _performSearchInMainWindow(
    Map<String, dynamic> groupControllersMap,
    String searchGrouping,
    List<Map<String, dynamic>> selectedBooksForSearch,
    Map<String, bool> searchSections,
    bool morphologicalSearch,
    bool affixSearch,
    bool considerHamzas,
    bool considerDiacritics,
    bool considerNumbers,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
    List<Map<String, dynamic>> indexedBooks,
  ) {
    final space = _activeSpace;
    final searchQueries = _extractSearchQueries(groupControllersMap);
    final searchSnapshot = _searchSnapshotFromParams(
      groupControllersMap,
      searchGrouping,
      searchSections,
      affixSearch,
      considerHamzas,
      considerDiacritics,
      considerNumbers,
      allPhrasesRequired,
      ordered,
      proximity,
    );
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      space.searchResultsTabs.add(SearchResultsTab(
        id: tabId,
        results: [],
        totalCount: 0,
        searchQueries: searchQueries,
        morphologicalSearch: morphologicalSearch,
        searchSnapshot: searchSnapshot,
        isSearching: true,
      ));
      space.selectedBookP =
          space.openedBooks.length + space.searchResultsTabs.length - 1;
    });

    _searchHandlers!.performSearchInMainWindow(
      groupControllersMap: groupControllersMap,
      searchGrouping: searchGrouping,
      selectedBooksForSearch: selectedBooksForSearch,
      searchSections: searchSections,
      morphologicalSearch: morphologicalSearch,
      affixSearch: affixSearch,
      considerHamzas: considerHamzas,
      considerDiacritics: considerDiacritics,
      considerNumbers: considerNumbers,
      allPhrasesRequired: allPhrasesRequired,
      ordered: ordered,
      proximity: proximity,
      indexedBooks: indexedBooks,
      isCancelled: () {
        final idx = space.searchResultsTabs.indexWhere((t) => t.id == tabId);
        return idx == -1 || space.searchResultsTabs[idx].cancelled;
      },
      onSearchResultsUpdate: (results, totalCount, queries, morphological) {
        if (mounted) {
          _updateSearchResultsTab(
            space,
            tabId,
            results,
            totalCount,
            queries,
            searchQueries,
            morphological,
            searchSnapshot,
          );
        }
      },
      onSearchComplete: () {
        if (!mounted) return;
        final idx = space.searchResultsTabs.indexWhere((t) => t.id == tabId);
        if (idx != -1) setState(() => space.searchResultsTabs[idx].isSearching = false);
      },
    );
  }

  List<String> _extractSearchQueries(Map<String, dynamic> groupControllersMap) {
    final searchQueries = <String>[];
    groupControllersMap.forEach((key, value) {
      if (value is List) {
        for (var text in value) {
          final trimmedText = text.toString().trim();
          if (trimmedText.isNotEmpty) searchQueries.add(trimmedText);
        }
      }
    });
    return searchQueries;
  }

  void _updateSearchResultsTab(
    HomePageTabSpace space,
    String tabId,
    List<Map<String, dynamic>> results,
    int? totalCount,
    List<String> queries,
    List<String> fallbackQueries,
    bool morphological,
    SearchStateSnapshot searchSnapshot,
  ) {
    setState(() {
      final tabIndex =
          space.searchResultsTabs.indexWhere((tab) => tab.id == tabId);
      final searchQueries = queries.isNotEmpty ? queries : fallbackQueries;

      if (tabIndex == -1) {
        space.searchResultsTabs.add(SearchResultsTab(
          id: tabId,
          results: results,
          totalCount: totalCount ?? 0,
          searchQueries: searchQueries,
          morphologicalSearch: morphological,
          searchSnapshot: searchSnapshot,
        ));
        space.selectedBookP =
            space.openedBooks.length + space.searchResultsTabs.length - 1;
      } else {
        space.searchResultsTabs[tabIndex].results = results;
        space.searchResultsTabs[tabIndex].totalCount = totalCount ?? 0;
        space.searchResultsTabs[tabIndex].searchQueries = searchQueries;
        space.searchResultsTabs[tabIndex].morphologicalSearch = morphological;
        space.searchResultsTabs[tabIndex].searchSnapshot = searchSnapshot;
      }
    });
  }

  SearchStateSnapshot _searchSnapshotFromParams(
    Map<String, dynamic> groupControllersMap,
    String searchGrouping,
    Map<String, bool> searchSections,
    bool affixSearch,
    bool considerHamzas,
    bool considerDiacritics,
    bool considerNumbers,
    bool allPhrasesRequired,
    bool ordered,
    bool proximity,
  ) {
    return SearchStateSnapshot(
      groupQueries: groupControllersMap.map((key, value) {
        final values = value is List ? value : const [];
        return MapEntry(
          key,
          values
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        );
      }),
      searchGrouping: searchGrouping,
      searchSections: Map<String, bool>.from(searchSections),
      options: {
        'affixSearch': affixSearch,
        'considerHamzas': considerHamzas,
        'considerDiacritics': considerDiacritics,
        'considerNumbers': considerNumbers,
        'allPhrasesRequired': allPhrasesRequired,
        'ordered': ordered,
        'proximity': proximity,
      },
    );
  }
}
