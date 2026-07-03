import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookPositionStore.dart';
import 'package:golden_shamela/Services/BookSourceChangeMonitor.dart';
import 'package:golden_shamela/Services/OpenTabsStore.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/UI/BookSideBar/BooksSideBarIcons.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/LibraryControl/library_control_dialog.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_tab_view.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_tab.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_import_actions.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_dialog.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_tab.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_tab_view.dart';
import 'package:golden_shamela/UI/SavedItems/saved_items_dialog.dart';
import 'package:golden_shamela/UI/SavedItems/helpers/work_session_store.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';
import 'package:golden_shamela/UI/Search/shamela_search_view.dart';
import 'package:golden_shamela/UI/SettingsScreen.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/UI/Widgets/BackgroundTasksBar.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'home_page/home_page_book_management.dart';
import 'home_page/home_page_search_handlers.dart';
import 'home_page/home_page_tab_shortcuts.dart';
import 'home_page/home_page_tab_space.dart';
import 'home_page/home_page_tab_space_view.dart';
import 'home_page/home_page_window_communication.dart';

part 'home_page/home_page_actions.dart';
part 'home_page/home_page_detached_tab_resize.dart';
part 'home_page/home_page_detached_tabs.dart';
part 'home_page/home_page_open_tabs.dart';
part 'home_page/home_page_saved_items.dart';
part 'home_page/home_page_search_tabs.dart';
part 'home_page/home_page_tab_close_actions.dart';
part 'home_page/home_page_app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<HomePageTabSpace> _spaces = [
    HomePageTabSpace(),
    HomePageTabSpace(),
  ];
  int _activeSpaceIndex = 0;
  HomePageSplitMode _splitMode = HomePageSplitMode.single;
  final List<_DetachedHomeTabRecord> _detachedTabs = [];

  HomePageWindowCommunication? _windowCommunication;
  HomePageSearchHandlers? _searchHandlers;
  HomePageBookManagement? _bookManagement;

  HomePageTabSpace get _activeSpace => _spaces[_activeSpaceIndex];

  @override
  void initState() {
    super.initState();
    _initializeHelpers();
    unawaited(_restoreOpenTabs());
  }

  void _initializeHelpers() {
    _bookManagement = HomePageBookManagement(context: context);

    _searchHandlers = HomePageSearchHandlers(
      context: context,
      onResultTapped: (bookPath, pageNumber) =>
          this._handleSearchResultNavigation(bookPath, pageNumber),
      onPerformSearch: this._performSearchInMainWindow,
      isMounted: () => mounted,
      setState: () => setState(() {}),
      onSearchCompleted: this._addSearchResultsTab,
    );

    _windowCommunication = HomePageWindowCommunication(
      onBookSelected: (bookPath, pageNumber) {
        this._onBookSelected(File(bookPath), pageNumber: pageNumber);
      },
      onPerformSearch: this._performSearchInMainWindow,
      onSearchResults: this._addSearchResultsTab,
      isMounted: () => mounted,
    );

    _windowCommunication!.setup();
  }

  @override
  Widget build(BuildContext context) {
    return HomePageTabShortcuts(
      currentIndex: _activeSpace.selectedBookP,
      totalTabs: _activeSpace.totalTabs,
      onSwitchToIndex: (index) => this._switchToBook(_activeSpace, index),
      onSwitchDetachedTab: this._switchDetachedTab,
      onCloseCurrentTab: this._closeCurrentTabCommand,
      onCloseAllTabs: this._closeAllTabsCommand,
      onOpenLibraryPicker: () => unawaited(this._openLibraryPicker()),
      onAddBook: () => unawaited(this._addBookFromHome()),
      onOpenRecitedText: () => this._openRecitedTextTab(),
      onOpenSearch: () => unawaited(_searchHandlers!.openSearchWindow()),
      onOpenLibraryControl: () => unawaited(this._openLibraryControlPanel()),
      onOpenSavedItems: this._openSavedItemsDialog,
      onOpenSettings: this._openSettings,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildStackedAppBar(),
                  Expanded(child: _buildTabSpaces()),
                  const BackgroundTasksBar(),
                ],
              ),
              this._buildDetachedTabsLayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSpaces() {
    if (_splitMode == HomePageSplitMode.single) {
      return _buildTabSpace(_spaces.first);
    }

    return LibrarySplitPane(
      axis: _splitMode == HomePageSplitMode.vertical
          ? Axis.horizontal
          : Axis.vertical,
      initialRatio: 0.5,
      minRatio: 0.2,
      maxRatio: 0.8,
      first: _buildTabSpace(_spaces[0]),
      second: _buildTabSpace(_spaces[1]),
    );
  }

  Widget _buildTabSpace(HomePageTabSpace space) {
    return HomePageTabSpaceView(
      space: space,
      active: identical(space, _activeSpace),
      onActivate: () => this._activateSpace(space),
      onBookSelected: (
        book, {
        pageNumber,
        fromSearchResults = false,
      }) =>
          this._onBookSelected(
        book,
        space: space,
        pageNumber: pageNumber,
        fromSearchResults: fromSearchResults,
      ),
      onCloseBook: (index) => this._closeBook(space, index),
      onSwitchToBook: (index) => this._switchToBook(space, index),
      onCloseSearchResultsTab: (tabId) =>
          this._closeSearchResultsTab(space, tabId),
      onCloseLibraryDataTab: () => this._closeLibraryDataTab(space),
      onCloseRecitedTextTab: () => this._closeRecitedTextTab(space),
      onCloseCurrentTab: () => this._closeCurrentTab(space),
      onOpenBooks: () => unawaited(this._openLibraryPicker(space: space)),
      onOpenRecitedText: () => this._openRecitedTextTab(space: space),
      onOpenAuthors: () => this._openLibraryDataTab(space: space),
      onOpenSearch: () => unawaited(_searchHandlers!.openSearchWindow()),
      onSearch: (query, sectionId, sectionTitle) =>
          this._performHomeStartSearch(space, query, sectionId, sectionTitle),
      onOpenSection: (sectionId) =>
          unawaited(this._openLibraryPicker(space: space, sectionId: sectionId)),
      onOpenRecentBook: (path) => unawaited(this._onBookSelected(
        File(path),
        space: space,
        openSource: BookOpenSource.recent,
      )),
      onReorderBooks: (oldIndex, newIndex) {
        setState(() {
          final draggedBook = space.openedBooks.removeAt(oldIndex);
          space.openedBooks.insert(newIndex, draggedBook);
        });
        this._saveOpenTabs();
      },
      buildSearchResultsTab: (tab) => _buildSearchResultsTab(space, tab),
      onTabsChanged: this._saveOpenTabs,
    );
  }

  Widget _buildSearchResultsTab(
    HomePageTabSpace space,
    SearchResultsTab tab,
  ) {
    return ShamelaSearchView(
      key: ValueKey(tab.id),
      results: tab.results,
      totalCount: tab.totalCount,
      searchQueries: tab.searchQueries,
      morphologicalSearch: tab.morphologicalSearch,
      searchSnapshot: tab.searchSnapshot,
      isSearching: tab.isSearching,
      onLoadBook: (bookPath, pageNumber) async {
        final openComment = AppState().openCommentPanelForSearchTarget;
        AppState().setSearchHighlight(tab.searchQueries);
        AppState().setSearchTarget(
          pageNumber,
          null,
          openCommentPanel: openComment,
        );
        return this._loadBookInsideSearchTab(bookPath, pageNumber);
      },
      onOpenBookFull: (bookPath, pageNumber) =>
          this._handleSearchResultNavigation(
        bookPath,
        pageNumber,
        space: space,
      ),
      onNewSearch: (query, morphological) {
        this._performQuickSearchForTab(space, tab.id, query, morphological);
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

}
