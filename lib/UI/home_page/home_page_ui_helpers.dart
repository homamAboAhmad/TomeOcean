import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/BookTitleRow.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';

/// UI helper functions for HomePage
class HomePageUIHelpers {
  /// Build opened books titles list
  static Widget openedBooksTitlesList({
    required List<WordDocument> openedBooks,
    required List<SearchResultsTab> searchResultsTabs,
    required int selectedBookP,
    required Function(int) onSwitchToBook,
    required Function(int) onCloseBook,
    required Function(String) onCloseSearchResultsTab,
    required Function(int, int) onReorderBooks,
  }) {
    final totalTabs = openedBooks.length + searchResultsTabs.length;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8, top: 12),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: totalTabs,
          itemBuilder: (context, i) {
            // Handle search results tabs
            if (i >= openedBooks.length) {
              final tabIndex = i - openedBooks.length;
              if (tabIndex >= 0 && tabIndex < searchResultsTabs.length) {
                final tab = searchResultsTabs[tabIndex];
                return BookTitleRow(
                  title: tab.title,
                  isChoosed: selectedBookP == i,
                  onTab: () => onSwitchToBook(i),
                  onClose: () => onCloseSearchResultsTab(tab.id),
                  key: ValueKey('search_results_${tab.id}'),
                );
              }
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
    );
  }
}
