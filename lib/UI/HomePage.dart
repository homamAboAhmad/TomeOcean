import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/TestScreen.dart';
import 'package:golden_shamela/UI/Widgets/IndexingDialog.dart';
import 'package:golden_shamela/UI/SettingsScreen.dart';
import 'package:golden_shamela/UI/AuthorsManagement/authors_management_screen.dart';
import 'package:golden_shamela/UI/Search/search_results_tab_viewer.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/UI/Widgets/BackgroundTasksBar.dart';
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

  int? _pendingPageNumber;

  void _initializeHelpers() {
    _bookManagement = HomePageBookManagement(
      context: context,
      onBookAdded: (book) {
        setState(() {
          openedBooks.add(book);
          selectedBookP = openedBooks.length - 1;
          // Set page number if pending
          if (_pendingPageNumber != null) {
            openedBooks[selectedBookP].currentPage = _pendingPageNumber!;
            _pendingPageNumber = null;
          }
        });
      },
    );

    _searchHandlers = HomePageSearchHandlers(
      context: context,
      onResultTapped: _handleSearchResultNavigation,
      onPerformSearch: _performSearchInMainWindow,
      isMounted: () => mounted,
      setState: () => setState(() {}),
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
    return SearchResultsTabViewer(
      results: tab.results,
      totalCount: tab.totalCount,
      onResultTapped: (bookPath, pageNumber) async {
        await _onBookSelected(
          File(bookPath),
          pageNumber: pageNumber,
          fromSearchResults: true,
        );
      },
      searchQueries: tab.searchQueries,
      morphologicalSearch: tab.morphologicalSearch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Container(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                "البحر المحيط",
                style: normalStyle(fontSize: 24, color: secondaryColor),
              ),
            ),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: secondaryColor),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: secondaryColor),
              tooltip: 'بحث',
              onPressed: () => _searchHandlers!.openSearchWindow(),
            ),
            IconButton(
              icon: Icon(Icons.storage, color: secondaryColor),
              tooltip: 'فهرسة الكتب',
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const IndexingDialog(),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.people, color: secondaryColor),
              tooltip: 'إدارة المؤلفين',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthorsManagementScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.settings, color: secondaryColor),
              tooltip: 'الإعدادات',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.bug_report, color: secondaryColor),
              tooltip: 'اختبار',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TestScreen()),
                );
              },
            ),
          ],
        ),
        drawer: BooksDrawer(onBookSelected: _onBookSelected),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(color: Colors.white),
                  if (openedBooks.isNotEmpty &&
                      selectedBookP < openedBooks.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: DocViewer(
                        openedBooks[selectedBookP],
                        key: ObjectKey(openedBooks[selectedBookP]),
                        onBookSelected: _onBookSelected,
                      ),
                    ),
                  if (_searchResultsTabs.isNotEmpty &&
                      selectedBookP >= openedBooks.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: _buildSearchResultsTabViewer(),
                    ),
                  if (openedBooks.isNotEmpty || _searchResultsTabs.isNotEmpty)
                    HomePageUIHelpers.openedBooksTitlesList(
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
                ],
              ),
            ),
            const BackgroundTasksBar(),
          ],
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
    final bookTitle = getFileName(filePath!);

    // Always open a new instance of the book, even if it's already opened
    // This allows users to have multiple tabs of the same book

    // Book is not opened (or opened from search results), read and add it
    _pendingPageNumber = pageNumber;
    await _bookManagement!.readDocxFile(filePath);

    // Ensure page number is set (in case onBookAdded didn't set it)
    if (pageNumber != null &&
        openedBooks.isNotEmpty &&
        selectedBookP < openedBooks.length) {
      if (openedBooks[selectedBookP].currentPage != pageNumber) {
        openedBooks[selectedBookP].currentPage = pageNumber;
        if (mounted) {
          setState(() {});
        }
      }
    }

    // Don't close search results tabs when opening a book
    if (mounted && pageNumber == null) {
      setState(() {});
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
    );
  }

  /// Extract search queries from group controllers map
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

  /// Update or create search results tab
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
        final newTab = SearchResultsTab(
          id: tabId,
          results: List.from(results),
          totalCount: totalCount ?? 0,
          searchQueries: searchQueries,
          morphologicalSearch: morphological,
        );
        _searchResultsTabs.add(newTab);
      } else {
        _searchResultsTabs[tabIndex] = SearchResultsTab(
          id: tabId,
          results: List.from(results),
          totalCount: totalCount ?? 0,
          searchQueries: searchQueries,
          morphologicalSearch: morphological,
        );
      }

      selectedBookP = openedBooks.length + _searchResultsTabs.length - 1;
    });
  }
}
