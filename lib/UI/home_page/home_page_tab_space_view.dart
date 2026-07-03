import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_tab_view.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_tab_view.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/UI/home_page/home_page_tab_space.dart';
import 'package:golden_shamela/UI/home_page/home_page_ui_helpers.dart';
import 'package:golden_shamela/UI/home_page/home_start_view.dart';

class HomePageTabSpaceView extends StatelessWidget {
  final HomePageTabSpace space;
  final bool active;
  final VoidCallback onActivate;
  final Future<void> Function(
    File book, {
    int? pageNumber,
    bool fromSearchResults,
  }) onBookSelected;
  final ValueChanged<int> onCloseBook;
  final ValueChanged<int> onSwitchToBook;
  final ValueChanged<String> onCloseSearchResultsTab;
  final VoidCallback onCloseLibraryDataTab;
  final VoidCallback onCloseRecitedTextTab;
  final VoidCallback onCloseCurrentTab;
  final VoidCallback onOpenBooks;
  final VoidCallback onOpenRecitedText;
  final VoidCallback onOpenAuthors;
  final VoidCallback onOpenSearch;
  final void Function(String query, String? sectionId, String? sectionTitle)
      onSearch;
  final ValueChanged<String> onOpenSection;
  final ValueChanged<String> onOpenRecentBook;
  final void Function(int oldIndex, int newIndex) onReorderBooks;
  final Widget Function(SearchResultsTab tab) buildSearchResultsTab;
  final VoidCallback onTabsChanged;

  const HomePageTabSpaceView({
    super.key,
    required this.space,
    required this.active,
    required this.onActivate,
    required this.onBookSelected,
    required this.onCloseBook,
    required this.onSwitchToBook,
    required this.onCloseSearchResultsTab,
    required this.onCloseLibraryDataTab,
    required this.onCloseRecitedTextTab,
    required this.onCloseCurrentTab,
    required this.onOpenBooks,
    required this.onOpenRecitedText,
    required this.onOpenAuthors,
    required this.onOpenSearch,
    required this.onSearch,
    required this.onOpenSection,
    required this.onOpenRecentBook,
    required this.onReorderBooks,
    required this.buildSearchResultsTab,
    required this.onTabsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onActivate(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: active
              ? Border.all(color: actionColor.withOpacity(0.42))
              : null,
        ),
        child: Stack(
          children: [
            if (space.totalTabs == 0) _emptyState(),
            if (space.openedBooks.isNotEmpty &&
                space.selectedBookP < space.openedBooks.length)
              _content(
                DocViewer(
                  space.openedBooks[space.selectedBookP],
                  key: ObjectKey(space.openedBooks[space.selectedBookP]),
                  onBookSelected: onBookSelected,
                  onCloseBook: () => onCloseBook(space.selectedBookP),
                  onPageChanged: onTabsChanged,
                ),
              ),
            if (space.isSearchResultsTabSelected)
              _content(_buildSelectedSearchTab()),
            if (space.isLibraryDataTabSelected)
              _content(const LibraryDataTabView()),
            if (space.isRecitedTextTabSelected)
              _content(const RecitedTextTabView()),
            if (space.totalTabs > 0) _tabsBar(),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return HomeStartView(
      onOpenBooks: onOpenBooks,
      onOpenRecitedText: onOpenRecitedText,
      onOpenAuthors: onOpenAuthors,
      onOpenSearch: onOpenSearch,
      onSearch: onSearch,
      onOpenSection: onOpenSection,
      onOpenRecentBook: onOpenRecentBook,
    );
  }

  Widget _content(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 48.0),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): onCloseCurrentTab,
        },
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSelectedSearchTab() {
    final tab = space.selectedSearchResultsTab;
    if (tab == null) {
      return Center(child: Text('خطأ في عرض النتائج', style: normalStyle()));
    }
    return buildSearchResultsTab(tab);
  }

  Widget _tabsBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: mutedColor,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: HomePageUIHelpers.openedBooksTitlesList(
        openedBooks: space.openedBooks,
        searchResultsTabs: space.searchResultsTabs,
        libraryDataTab: space.libraryDataTab,
        recitedTextTab: space.recitedTextTab,
        selectedBookP: space.selectedBookP,
        onSwitchToBook: onSwitchToBook,
        onCloseBook: onCloseBook,
        onCloseSearchResultsTab: onCloseSearchResultsTab,
        onCloseLibraryDataTab: onCloseLibraryDataTab,
        onCloseRecitedTextTab: onCloseRecitedTextTab,
        onReorderBooks: onReorderBooks,
      ),
    );
  }
}
