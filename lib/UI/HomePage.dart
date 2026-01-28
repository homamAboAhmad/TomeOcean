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

  int? _pendingPageNumber;

  void _initializeHelpers() {
    _bookManagement = HomePageBookManagement(
      context: context,
      onBookAdded: (book) {
        setState(() {
          openedBooks.add(book);
          selectedBookP = openedBooks.length - 1;
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
    return SearchResultsTabViewer(
      results: tab.results,
      totalCount: tab.totalCount,
      onResultTapped: (bookPath, pageNumber) async {
        // Set search terms to highlight in the opened page
        AppState().setSearchHighlight(tab.searchQueries);

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
              icon: Icons.storage_rounded,
              tooltip: 'فهرسة الكتب',
              onPressed: () => _showIndexingDialog(context),
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
            // Hidden/Secondary actions could go into a popup menu if needed
            // Keeping bug report for now as requested by user previously
            // _buildAppBarAction(
            //   icon: Icons.bug_report_rounded,
            //   tooltip: 'اختبار',
            //   onPressed: () => Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (context) => TestScreen()),
            //   ),
            // ),
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

  void _showIndexingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IndexingDialog(),
    );
  }

  Future<void> _onBookSelected(
    File book, {
    int? pageNumber,
    bool fromSearchResults = false,
  }) async {
    filePath = book.path;

    // Clear search highlighting if not coming from search results
    if (!fromSearchResults) {
      AppState().clearSearchHighlight();
    }

    _pendingPageNumber = pageNumber;
    await _bookManagement!.readDocxFile(filePath);

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
