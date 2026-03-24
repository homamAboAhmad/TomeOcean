import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/UI/Search/shamela_search_dialog.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'package:window_manager/window_manager.dart';

/// Search handlers for HomePage
class HomePageSearchHandlers {
  final BuildContext context;
  final Function(String, int) onResultTapped;
  final Function(
    Map<String, dynamic>,
    String,
    List<Map<String, dynamic>>,
    Map<String, bool>,
    bool,
    bool,
    bool,
    bool,
    bool,
    bool,
    bool,
    bool,
    List<Map<String, dynamic>>,
  )
  onPerformSearch;
  final bool Function() isMounted;
  final Function() setState;
  final Function(List<Map<String, dynamic>>, int, List<String>, bool)?
  onSearchCompleted;

  HomePageSearchHandlers({
    required this.context,
    required this.onResultTapped,
    required this.onPerformSearch,
    required this.isMounted,
    required this.setState,
    this.onSearchCompleted,
  });

  /// Open search window (Always in-app as requested)
  Future<void> openSearchWindow() async {
    try {
      final appState = AppState();
      final booksLoader = IndexedBooksLoader();

      List<Map<String, dynamic>> indexedBooks =
          appState.cachedIndexedBooks ?? await booksLoader.getIndexedBooks();

      if (indexedBooks.isEmpty) {
        ShowSnackBar(
          context,
          "لا توجد كتب مفهرسة. يرجى فهرسة الكتب أولاً من شاشة الفهرسة.",
        );
        return;
      }

      if (appState.cachedIndexedBooks == null) {
        appState.cachedIndexedBooks = indexedBooks;
      }

      // Always show search dialog in-app
      showSearchDialog(indexedBooks);
    } catch (e) {
      ShowSnackBar(context, "خطأ في فتح البحث: $e");
    }
  }

  /// Show search dialog (fallback)
  void showSearchDialog(List<Map<String, dynamic>> indexedBooks) {
    showDialog(
      context: context,
      builder: (context) => ShamelaSearchDialog(
        onResultTapped: onResultTapped,
        indexedBooks: indexedBooks,
        onSearchCompleted: onSearchCompleted,
        onDelegateSearch:
            (
              groupControllersMap,
              searchGrouping,
              selectedBooksForSearch,
              searchSections,
              morphologicalSearch,
              affixSearch,
              considerHamzas,
              considerDiacritics,
              considerNumbers,
              allPhrasesRequired,
              ordered,
              proximity,
              indexedBooks,
            ) {
              onPerformSearch(
                groupControllersMap,
                searchGrouping,
                selectedBooksForSearch,
                searchSections,
                morphologicalSearch,
                affixSearch,
                considerHamzas,
                considerDiacritics,
                considerNumbers,
                allPhrasesRequired,
                ordered,
                proximity,
                indexedBooks,
              );
            },
      ),
    );
  }

  /// Perform search in main window with streaming results
  Future<void> performSearchInMainWindow({
    required Map<String, dynamic> groupControllersMap,
    required String searchGrouping,
    required List<Map<String, dynamic>> selectedBooksForSearch,
    required Map<String, bool> searchSections,
    required bool morphologicalSearch,
    required bool affixSearch,
    required bool considerHamzas,
    required bool considerDiacritics,
    required bool considerNumbers,
    required bool allPhrasesRequired,
    required bool ordered,
    required bool proximity,
    required List<Map<String, dynamic>> indexedBooks,
    required Function(List<Map<String, dynamic>>, int?, List<String>, bool)
    onSearchResultsUpdate,
    bool Function()? isCancelled,
    VoidCallback? onSearchComplete,
  }) async {
    try {
      final searchExecutor = SearchExecutor();
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();

      final Map<String, List<TextEditingController>> groupControllers = {};
      groupControllersMap.forEach((key, value) {
        if (value is List) {
          groupControllers[key] = value.map((text) {
            final controller = TextEditingController();
            controller.text = text.toString();
            return controller;
          }).toList();
        }
      });

      List<String>? booksToSearch;

      final sectionIdsFromSearch = selectedBooksForSearch
          .where(
            (item) => item['type'] == 'section' && item['sectionId'] != null,
          )
          .map((item) {
            final sectionId = item['sectionId'];
            return sectionId is String ? sectionId : sectionId.toString();
          })
          .where((id) => id.isNotEmpty)
          .toList();

      List<String>? booksFromSections;
      if (sectionIdsFromSearch.isNotEmpty) {
        final allBookPaths = <String>[];
        for (var sectionId in sectionIdsFromSearch) {
          try {
            final bookPaths = await metadataDb.getBookPaths(
              sectionId: sectionId.toString(),
            );
            allBookPaths.addAll(bookPaths);
          } catch (e, stackTrace) {
            // Continue with next section
          }
        }
        booksFromSections = allBookPaths
            .where(
              (bookPath) =>
                  indexedBooks.any((book) => book['book_path'] == bookPath),
            )
            .toList();
      }

      final bookPathsFromSearch = selectedBooksForSearch
          .where((item) => item['type'] == 'book' && item['bookPath'] != null)
          .map((item) => item['bookPath'] as String)
          .toList();

      final authorIdsFromSearch = selectedBooksForSearch
          .where((item) => item['type'] == 'author' && item['authorId'] != null)
          .map((item) {
            final authorId = item['authorId'];
            return authorId is String ? authorId : authorId.toString();
          })
          .where((id) => id.isNotEmpty)
          .toSet();

      List<String>? booksFromAuthors;
      if (authorIdsFromSearch.isNotEmpty) {
        final allBookPaths = <String>[];
        for (var authorId in authorIdsFromSearch) {
          try {
            final bookPaths = await metadataDb.getBookPaths(
              authorId: authorId.toString(),
            );
            allBookPaths.addAll(bookPaths);
          } catch (e, stackTrace) {
            // Continue with next author
          }
        }
        booksFromAuthors = allBookPaths
            .where(
              (bookPath) =>
                  indexedBooks.any((book) => book['book_path'] == bookPath),
            )
            .toList();
      }

      Set<String> allBooksToSearch = {};
      if (booksFromSections != null) allBooksToSearch.addAll(booksFromSections);
      if (bookPathsFromSearch.isNotEmpty)
        allBooksToSearch.addAll(bookPathsFromSearch);
      if (booksFromAuthors != null) allBooksToSearch.addAll(booksFromAuthors);

      if (allBooksToSearch.isNotEmpty) {
        booksToSearch = allBooksToSearch.toList();
      }

      final selectedSections = searchSections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      List<Map<String, dynamic>> allResults = [];
      int? totalCount;
      List<String> searchQueries = [];

      groupControllers.values.forEach((controllers) {
        controllers.forEach((controller) {
          if (controller.text.trim().isNotEmpty) {
            searchQueries.add(controller.text.trim());
          }
        });
      });

      await for (final searchResult in searchExecutor.performPageSearchStream(
        groupControllers: groupControllers,
        searchGrouping: searchGrouping,
        bookPaths: booksToSearch,
        sectionTypes: selectedSections.length < searchSections.length
            ? selectedSections
            : null,
        morphologicalSearch: morphologicalSearch,
        affixSearch: affixSearch,
        considerHamzas: considerHamzas,
        considerDiacritics: considerDiacritics,
        considerNumbers: considerNumbers,
        allPhrasesRequired: allPhrasesRequired,
        ordered: ordered,
        proximity: proximity,
        batchSize: 10,
      )) {
        if (!isMounted() || (isCancelled != null && isCancelled())) {
          break;
        }

        if (totalCount == null) {
          totalCount = searchResult.totalCount;
        }

        // Filter out results for non-existent book files
        final validResults = searchResult.results.where((r) {
          final bookPath = r['book_path'] as String?;
          return bookPath != null && File(bookPath).existsSync();
        }).toList();

        allResults.addAll(validResults);
        onSearchResultsUpdate(
          allResults,
          totalCount,
          searchQueries,
          morphologicalSearch,
        );
      }
    } catch (e, stackTrace) {
      if (isMounted()) {
        onSearchResultsUpdate([], 0, [], false);
      }
    } finally {
      onSearchComplete?.call();
    }
  }
}
