import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_tab.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_tab.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';

enum HomePageSplitMode {
  single,
  vertical,
  horizontal,
  detachCurrentTab,
  returnDetachedTabs,
  closeCurrentTab,
  closeAllTabs,
  closeOtherTabs,
}

class HomePageTabSpace {
  final List<WordDocument> openedBooks = [];
  final List<SearchResultsTab> searchResultsTabs = [];
  LibraryDataTab? libraryDataTab;
  RecitedTextTab? recitedTextTab;
  int selectedBookP = 0;
  String? filePath;

  int get totalTabs =>
      openedBooks.length +
      searchResultsTabs.length +
      (libraryDataTab == null ? 0 : 1) +
      (recitedTextTab == null ? 0 : 1);

  bool get isSearchResultsTabSelected {
    final tabIndex = selectedBookP - openedBooks.length;
    return tabIndex >= 0 && tabIndex < searchResultsTabs.length;
  }

  bool get isLibraryDataTabSelected {
    if (libraryDataTab == null) return false;
    return selectedBookP == openedBooks.length + searchResultsTabs.length;
  }

  bool get isRecitedTextTabSelected {
    if (recitedTextTab == null) return false;
    return selectedBookP ==
        openedBooks.length +
            searchResultsTabs.length +
            (libraryDataTab == null ? 0 : 1);
  }

  SearchResultsTab? get selectedSearchResultsTab {
    final tabIndex = selectedBookP - openedBooks.length;
    if (tabIndex < 0 || tabIndex >= searchResultsTabs.length) return null;
    return searchResultsTabs[tabIndex];
  }

  bool moveSelectedTabTo(HomePageTabSpace target) {
    if (totalTabs == 0 || identical(this, target)) return false;

    final selectedIndex = selectedBookP;
    if (selectedIndex < openedBooks.length) {
      target.openedBooks.add(openedBooks.removeAt(selectedIndex));
      target.selectedBookP = target.openedBooks.length - 1;
      selectLastTab();
      return true;
    }

    final searchIndex = selectedIndex - openedBooks.length;
    if (searchIndex >= 0 && searchIndex < searchResultsTabs.length) {
      target.searchResultsTabs.add(searchResultsTabs.removeAt(searchIndex));
      target.selectedBookP =
          target.openedBooks.length + target.searchResultsTabs.length - 1;
      selectLastTab();
      return true;
    }

    final dataIndex = openedBooks.length + searchResultsTabs.length;
    if (libraryDataTab != null && selectedIndex == dataIndex) {
      target.libraryDataTab = libraryDataTab;
      libraryDataTab = null;
      target.selectedBookP =
          target.openedBooks.length + target.searchResultsTabs.length;
      selectLastTab();
      return true;
    }

    final recitedIndex = dataIndex + (libraryDataTab == null ? 0 : 1);
    if (recitedTextTab != null && selectedIndex == recitedIndex) {
      target.recitedTextTab = recitedTextTab;
      recitedTextTab = null;
      target.selectedBookP = target.openedBooks.length +
          target.searchResultsTabs.length +
          (target.libraryDataTab == null ? 0 : 1);
      selectLastTab();
      return true;
    }

    return false;
  }

  void absorbTabsFrom(
    HomePageTabSpace source, {
    bool selectSourceTab = false,
  }) {
    if (identical(this, source) || source.totalTabs == 0) return;

    final sourceSelected = source.selectedBookP;
    final sourceBookCount = source.openedBooks.length;
    final sourceSearchCount = source.searchResultsTabs.length;
    final targetBookCount = openedBooks.length;
    final targetSearchCount = searchResultsTabs.length;
    int? nextSelected;

    if (selectSourceTab && sourceSelected < sourceBookCount) {
      nextSelected = targetBookCount + sourceSelected;
    } else if (selectSourceTab &&
        sourceSelected < sourceBookCount + sourceSearchCount) {
      nextSelected = targetBookCount +
          sourceBookCount +
          targetSearchCount +
          sourceSelected -
          sourceBookCount;
    }

    openedBooks.addAll(source.openedBooks);
    searchResultsTabs.addAll(source.searchResultsTabs);
    source.openedBooks.clear();
    source.searchResultsTabs.clear();

    final sourceHadLibraryData = source.libraryDataTab != null;
    if (source.libraryDataTab != null) {
      libraryDataTab ??= source.libraryDataTab;
      if (selectSourceTab &&
          sourceSelected == sourceBookCount + sourceSearchCount) {
        nextSelected = openedBooks.length + searchResultsTabs.length;
      }
      source.libraryDataTab = null;
    }

    if (source.recitedTextTab != null) {
      recitedTextTab ??= source.recitedTextTab;
      if (selectSourceTab &&
          sourceSelected ==
              sourceBookCount +
                  sourceSearchCount +
                  (sourceHadLibraryData ? 1 : 0)) {
        nextSelected = openedBooks.length +
            searchResultsTabs.length +
            (libraryDataTab == null ? 0 : 1);
      }
      source.recitedTextTab = null;
    }

    if (nextSelected != null) selectedBookP = nextSelected;
    normalizeSelectedTab();
    source.normalizeSelectedTab();
  }

  void selectLastTab() {
    selectedBookP = totalTabs == 0 ? 0 : totalTabs - 1;
  }

  void normalizeSelectedTab() {
    if (totalTabs == 0) {
      selectedBookP = 0;
      return;
    }
    if (selectedBookP >= totalTabs) selectedBookP = totalTabs - 1;
    if (selectedBookP < 0) selectedBookP = 0;
  }

  void closeSelectedTab() {
    if (selectedBookP < openedBooks.length) {
      openedBooks.removeAt(selectedBookP);
    } else if (selectedBookP < openedBooks.length + searchResultsTabs.length) {
      searchResultsTabs.removeAt(selectedBookP - openedBooks.length);
    } else if (isLibraryDataTabSelected) {
      libraryDataTab = null;
    } else if (isRecitedTextTabSelected) {
      recitedTextTab = null;
    }
    normalizeSelectedTab();
  }

  void closeAllTabs() {
    openedBooks.clear();
    searchResultsTabs.clear();
    libraryDataTab = null;
    recitedTextTab = null;
    selectedBookP = 0;
  }

  void closeOtherTabs() {
    if (totalTabs <= 1) return;

    final selectedIndex = selectedBookP;
    if (selectedIndex < openedBooks.length) {
      final selectedBook = openedBooks[selectedIndex];
      closeAllTabs();
      openedBooks.add(selectedBook);
      return;
    }

    final searchIndex = selectedIndex - openedBooks.length;
    if (searchIndex >= 0 && searchIndex < searchResultsTabs.length) {
      final selectedSearch = searchResultsTabs[searchIndex];
      closeAllTabs();
      searchResultsTabs.add(selectedSearch);
      return;
    }

    final selectedLibraryData = libraryDataTab;
    final selectedRecitedText = recitedTextTab;
    final keepLibraryData = isLibraryDataTabSelected;
    final keepRecitedText = isRecitedTextTabSelected;
    closeAllTabs();
    if (keepLibraryData) libraryDataTab = selectedLibraryData;
    if (keepRecitedText) recitedTextTab = selectedRecitedText;
  }
}
