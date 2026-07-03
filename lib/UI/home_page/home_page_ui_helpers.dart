import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/BookTitleRow.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_tab.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_tab.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/UI/home_page/open_books_dropdown_button.dart';

/// UI helper functions for HomePage
class HomePageUIHelpers {
  /// Build opened books titles list
  static Widget openedBooksTitlesList({
    required List<WordDocument> openedBooks,
    required List<SearchResultsTab> searchResultsTabs,
    required LibraryDataTab? libraryDataTab,
    required RecitedTextTab? recitedTextTab,
    required int selectedBookP,
    required Function(int) onSwitchToBook,
    required Function(int) onCloseBook,
    required Function(String) onCloseSearchResultsTab,
    required VoidCallback onCloseLibraryDataTab,
    required VoidCallback onCloseRecitedTextTab,
    required Function(int, int) onReorderBooks,
  }) {
    final dataTabCount = libraryDataTab == null ? 0 : 1;
    final recitedTextTabCount = recitedTextTab == null ? 0 : 1;
    final totalTabs =
        openedBooks.length +
        searchResultsTabs.length +
        dataTabCount +
        recitedTextTabCount;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8, top: 12),
      child: SizedBox(
        height: 36,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalTabs,
                itemBuilder: (context, i) {
                  final searchStart = openedBooks.length;
                  final dataIndex = searchStart + searchResultsTabs.length;
                  final recitedTextIndex = dataIndex + dataTabCount;
                  if (i >= searchStart && i < dataIndex) {
                    final tab = searchResultsTabs[i - searchStart];
                    return BookTitleRow(
                      title: tab.title,
                      isChoosed: selectedBookP == i,
                      onTab: () => onSwitchToBook(i),
                      onClose: () => onCloseSearchResultsTab(tab.id),
                      key: ValueKey('search_results_${tab.id}'),
                    );
                  }

                  if (libraryDataTab != null && i == dataIndex) {
                    return BookTitleRow(
                      title: libraryDataTab.title,
                      isChoosed: selectedBookP == i,
                      onTab: () => onSwitchToBook(i),
                      onClose: onCloseLibraryDataTab,
                      key: ValueKey('library_data_${libraryDataTab.id}'),
                    );
                  }

                  if (recitedTextTab != null && i == recitedTextIndex) {
                    return BookTitleRow(
                      title: recitedTextTab.title,
                      isChoosed: selectedBookP == i,
                      onTab: () => onSwitchToBook(i),
                      onClose: onCloseRecitedTextTab,
                      key: ValueKey('recited_text_${recitedTextTab.id}'),
                    );
                  }

                  WordDocument book = openedBooks[i];

                  return DragTarget<int>(
                    onWillAccept: (data) => true,
                    onAccept: (oldIndex) {
                      if (oldIndex != i) {
                        onReorderBooks(oldIndex, i);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable(
                        data: i,
                        delay: Duration(milliseconds: 300),
                        feedback: Material(
                          elevation: 4.0,
                          child: BookTitleRow(
                            title: book.title,
                            isChoosed: true,
                            onTab: () {},
                            onClose: () {},
                          ),
                        ),
                        child: BookTitleRow(
                          title: book.title,
                          isChoosed: selectedBookP == i,
                          onTab: () => onSwitchToBook(i),
                          onClose: () => onCloseBook(i),
                          key: ValueKey(book.title),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (openedBooks.isNotEmpty) ...[
              const SizedBox(width: 8),
              OpenBooksDropdownButton(
                openedBooks: openedBooks,
                selectedBookIndex:
                    selectedBookP < openedBooks.length ? selectedBookP : -1,
                onBookSelected: onSwitchToBook,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
