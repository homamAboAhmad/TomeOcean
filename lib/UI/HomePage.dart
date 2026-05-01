import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/SettingsScreen.dart';
import 'package:golden_shamela/UI/AuthorsManagement/authors_management_screen.dart';
import 'package:golden_shamela/UI/Search/shamela_search_view.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/UI/Widgets/BackgroundTasksBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'home_page/home_page_window_communication.dart';
import 'home_page/home_page_search_handlers.dart';
import 'home_page/home_page_book_management.dart';
import 'home_page/home_page_ui_helpers.dart';
import 'BooksDrawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WordDocument> openedBooks = [];
  String? filePath;
  int selectedBookP = 0;

  List<SearchResultsTab> _searchResultsTabs = [];

  HomePageWindowCommunication? _windowCommunication;
  HomePageSearchHandlers? _searchHandlers;
  HomePageBookManagement? _bookManagement;

  @override
  void initState() {
    super.initState();
    _initializeHelpers();
  }


  void _initializeHelpers() {
    _bookManagement = HomePageBookManagement(
      context: context,
    );

    _searchHandlers = HomePageSearchHandlers(
      context: context,
      onResultTapped: _handleSearchResultNavigation,
      onPerformSearch: _performSearchInMainWindow,
      isMounted: () => mounted,
      setState: () => setState(() {}),
      onSearchCompleted: _addSearchResultsTab,
    );

    _windowCommunication = HomePageWindowCommunication(
      onBookSelected: (bookPath, pageNumber) {
        _onBookSelected(File(bookPath), pageNumber: pageNumber);
      },
      onPerformSearch: _performSearchInMainWindow,
      onSearchResults: _addSearchResultsTab,
      isMounted: () => mounted,
    );

    _windowCommunication!.setup();
  }

  Widget _buildSearchResultsTabViewer() {
    final tabIndex = selectedBookP - openedBooks.length;
    if (tabIndex < 0 || tabIndex >= _searchResultsTabs.length) {
      return Center(child: Text('خطأ في عرض النتائج', style: normalStyle()));
    }

    final tab = _searchResultsTabs[tabIndex];
    return ShamelaSearchView(
      key: ValueKey(tab.id),
      results: tab.results,
      totalCount: tab.totalCount,
      searchQueries: tab.searchQueries,
      morphologicalSearch: tab.morphologicalSearch,
      isSearching: tab.isSearching,
      onOpenBookFull: (bookPath, pageNumber) async {
        AppState().setSearchHighlight(tab.searchQueries);
        await _onBookSelected(
          File(bookPath),
          pageNumber: pageNumber,
          fromSearchResults: true,
        );
      },
      onNewSearch: (query, morphological) {
        _performQuickSearchForTab(tab.id, query, morphological);
      },
      onNewSearchDialog: () => _searchHandlers!.openSearchWindow(),
      onStopSearch: () {
        setState(() {
          tab.cancelled = true;
          tab.isSearching = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3), // Neutral premium background
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 2,
          toolbarHeight: 70,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: secondaryColor,
                size: 28,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'القائمة الرئيسية',
            ),
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: secondaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "المكتبة",
                  style: bigStyle(fontSize: 22, color: secondaryColor),
                ),
              ],
            ),
          ),
          centerTitle: true,
          actions: [
            _buildAppBarAction(
              icon: Icons.search_rounded,
              tooltip: 'بحث',
              onPressed: () => _searchHandlers!.openSearchWindow(),
            ),
            _buildAppBarAction(
              icon: Icons.people_outline_rounded,
              tooltip: 'إدارة المؤلفين',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AuthorsManagementScreen(),
                ),
              ),
            ),
            _buildAppBarAction(
              icon: Icons.settings_rounded,
              tooltip: 'الإعدادات',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: BooksDrawer(onBookSelected: _onBookSelected),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Base Empty State
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 80,
                          color: Colors.blueGrey.withOpacity(0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'اختر كتاباً من القائمة الجانبية للبدء',
                          style: bigStyle(
                            color: Colors.blueGrey.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Layer
                  if (openedBooks.isNotEmpty &&
                      selectedBookP < openedBooks.length)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 48.0,
                      ), // Space for tabs bar
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: DocViewer(
                          openedBooks[selectedBookP],
                          key: ObjectKey(openedBooks[selectedBookP]),
                          onBookSelected: _onBookSelected,
                          onCloseBook: () => _closeBook(selectedBookP),
                        ),
                      ),
                    ),

                  if (_searchResultsTabs.isNotEmpty &&
                      selectedBookP >= openedBooks.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: _buildSearchResultsTabViewer(),
                      ),
                    ),

                  // Tabs Layer (Top)
                  if (openedBooks.isNotEmpty || _searchResultsTabs.isNotEmpty)
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: HomePageUIHelpers.openedBooksTitlesList(
                        openedBooks: openedBooks,
                        searchResultsTabs: _searchResultsTabs,
                        selectedBookP: selectedBookP,
                        onSwitchToBook: _switchToBook,
                        onCloseBook: _closeBook,
                        onCloseSearchResultsTab: _closeSearchResultsTab,
                        onReorderBooks: (oldIndex, newIndex) {
                          setState(() {
                            final draggedBook = openedBooks.removeAt(oldIndex);
                            openedBooks.insert(newIndex, draggedBook);
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const BackgroundTasksBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: secondaryColor, size: 22),
          ),
        ),
      ),
    );
  }


  Future<void> _onBookSelected(
    File book, {
    int? pageNumber,
    bool fromSearchResults = false,
  }) async {
    filePath = book.path;

    if (!fromSearchResults) {
      AppState().clearSearchHighlight();
    }

    final bookTitle = getFileName(book.path);

    WordDocument tempDoc = WordDocument.empty();
    tempDoc.title = bookTitle;
    tempDoc.isLoading.value = true;
    tempDoc.loadingMessage.value = "جاري التحضير...";

    setState(() {
      openedBooks.add(tempDoc);
      selectedBookP = openedBooks.length - 1;
    });

    WordDocument? loadedDoc = await _bookManagement!.readDocxFile(
      filePath,
      tempDoc,
    );

    if (loadedDoc != null && mounted) {
      setState(() {
        int idx = openedBooks.indexOf(tempDoc);
        if (idx != -1) {
          openedBooks[idx] = loadedDoc;
          if (pageNumber != null) {
            openedBooks[idx].currentPage = pageNumber;
          }
        }
      });
    } else if (mounted) {
      setState(() {
        openedBooks.remove(tempDoc);
        if (selectedBookP >= openedBooks.length) {
          selectedBookP = openedBooks.length - 1;
        }
        if (selectedBookP < 0 && openedBooks.isNotEmpty) {
          selectedBookP = 0;
        }
      });
    }
  }

  void _handleSearchResultNavigation(String bookPath, int pageNumber) async {
    await _onBookSelected(
      File(bookPath),
      pageNumber: pageNumber,
      fromSearchResults: true,
    );
  }

  void _closeBook(int i) {
    if (i >= openedBooks.length && _searchResultsTabs.isNotEmpty) {
      final tabIndex = i - openedBooks.length;
      if (tabIndex >= 0 && tabIndex < _searchResultsTabs.length) {
        setState(() {
          _searchResultsTabs.removeAt(tabIndex);
          if (selectedBookP >= openedBooks.length + _searchResultsTabs.length) {
            selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
          }
          if (selectedBookP < 0 && openedBooks.isNotEmpty) {
            selectedBookP = 0;
          }
        });
      }
      return;
    }

    openedBooks.removeAt(i);
    if (selectedBookP >= openedBooks.length) {
      selectedBookP = openedBooks.length - 1;
    }
    if (selectedBookP < 0 && openedBooks.isNotEmpty) {
      selectedBookP = 0;
    }
    setState(() {});
  }

  void _closeSearchResultsTab(String tabId) {
    setState(() {
      _searchResultsTabs.removeWhere((tab) => tab.id == tabId);
      if (selectedBookP >= openedBooks.length + _searchResultsTabs.length) {
        selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
      }
      if (selectedBookP < 0 && openedBooks.isNotEmpty) {
        selectedBookP = 0;
      }
    });
  }

  void _switchToBook(int i) {
    selectedBookP = i;
    setState(() {});
  }

  void _addSearchResultsTab(
    List<Map<String, dynamic>> results,
    int totalCount,
    List<String> searchQueries,
    bool morphologicalSearch,
  ) {
    setState(() {
      final tabId = DateTime.now().millisecondsSinceEpoch.toString();
      final newTab = SearchResultsTab(
        id: tabId,
        results: results,
        totalCount: totalCount,
        searchQueries: searchQueries,
        morphologicalSearch: morphologicalSearch,
      );
      _searchResultsTabs.add(newTab);
      selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
    });
  }

  void _performQuickSearchForTab(
    String tabId,
    String query,
    bool morphological,
  ) {
    final tabIndex = _searchResultsTabs.indexWhere((t) => t.id == tabId);
    if (tabIndex != -1) {
      setState(() {
        _searchResultsTabs[tabIndex].results = [];
        _searchResultsTabs[tabIndex].totalCount = 0;
        _searchResultsTabs[tabIndex].searchQueries = [query];
        _searchResultsTabs[tabIndex].morphologicalSearch = morphological;
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
      searchSections: {
        'main': true,
        'footnote': true,
        'comment': true,
        'title': false,
      },
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
          _updateSearchResultsTab(tabId, results, totalCount, queries, [
            query,
          ], morph);
        }
      },
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
    final searchQueries = _extractSearchQueries(groupControllersMap);
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create the tab immediately so the user sees it right away
    setState(() {
      _searchResultsTabs.add(
        SearchResultsTab(
          id: tabId,
          results: [],
          totalCount: 0,
          searchQueries: searchQueries,
          morphologicalSearch: morphologicalSearch,
          isSearching: true,
        ),
      );
      selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
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
        final idx = _searchResultsTabs.indexWhere((t) => t.id == tabId);
        return idx == -1 || _searchResultsTabs[idx].cancelled;
      },
      onSearchResultsUpdate: (results, totalCount, queries, morphological) {
        if (mounted) {
          _updateSearchResultsTab(
            tabId,
            results,
            totalCount,
            queries,
            searchQueries,
            morphological,
          );
        }
      },
      onSearchComplete: () {
        if (mounted) {
          final idx = _searchResultsTabs.indexWhere((t) => t.id == tabId);
          if (idx != -1) {
            setState(() => _searchResultsTabs[idx].isSearching = false);
          }
        }
      },
    );
  }

  List<String> _extractSearchQueries(Map<String, dynamic> groupControllersMap) {
    final searchQueries = <String>[];
    groupControllersMap.forEach((key, value) {
      if (value is List) {
        for (var text in value) {
          final trimmedText = text.toString().trim();
          if (trimmedText.isNotEmpty) {
            searchQueries.add(trimmedText);
          }
        }
      }
    });
    return searchQueries;
  }

  void _updateSearchResultsTab(
    String tabId,
    List<Map<String, dynamic>> results,
    int? totalCount,
    List<String> queries,
    List<String> fallbackQueries,
    bool morphological,
  ) {
    setState(() {
      final tabIndex = _searchResultsTabs.indexWhere((tab) => tab.id == tabId);
      final searchQueries = queries.isNotEmpty ? queries : fallbackQueries;

      if (tabIndex == -1) {
        _searchResultsTabs.add(
          SearchResultsTab(
            id: tabId,
            results: List.from(results),
            totalCount: totalCount ?? 0,
            searchQueries: searchQueries,
            morphologicalSearch: morphological,
          ),
        );
      } else {
        _searchResultsTabs[tabIndex].results = List.from(results);
        _searchResultsTabs[tabIndex].totalCount = totalCount ?? 0;
        _searchResultsTabs[tabIndex].searchQueries = searchQueries;
        _searchResultsTabs[tabIndex].morphologicalSearch = morphological;
      }

      selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
    });
  }
}
