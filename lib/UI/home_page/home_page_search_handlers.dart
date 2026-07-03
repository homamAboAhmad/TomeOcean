import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:golden_shamela/UI/Search/shamela_search_dialog.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/UI/Search/helpers/search_results_author_sorter.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_selection.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'package:window_manager/window_manager.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

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

  /// Open search window
  Future<void> openSearchWindow() async {
    try {
      final appState = AppState();
      final booksLoader = IndexedBooksLoader();

      final cachedBooks = appState.cachedIndexedBooks;
      final indexedBooks = cachedBooks != null && cachedBooks.isNotEmpty
          ? cachedBooks
          : await booksLoader.getIndexedBooks();

      if (indexedBooks.isEmpty) {
        ShowSnackBar(
          context,
          "لا توجد كتب مفهرسة. يرجى فهرسة الكتب أولاً من شاشة الفهرسة.",
        );
        return;
      }

      appState.cachedIndexedBooks = indexedBooks;

      final searchMode =
          PreferencesHelper.prefs.getString('search_window_mode') ?? 'separate';
      final useMultiWindow =
          searchMode == 'separate' &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (useMultiWindow) {
        try {
          final windowConfig = WindowConfiguration(
            arguments: jsonEncode({
              'windowType': 'search',
              'windowId': DateTime.now().millisecondsSinceEpoch.toString(),
            }),
            hiddenAtLaunch: true,
          );

          final window = await WindowController.create(windowConfig);
          await window.show();
        } catch (e, stackTrace) {
          ShowSnackBar(context, "خطأ في فتح نافذة البحث: $e");
          showSearchDialog(indexedBooks);
        }
      } else {
        showSearchDialog(indexedBooks);
      }
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
        onDelegateSearch: (
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
      final bookAuthorMap = await metadataDb.getAllBookAuthorMappings();
      final authors = await metadataDb.getAuthors();
      final authorDeathYears = {
        for (final author in authors)
          if (author.deathYear?.isNotEmpty == true)
            author.id: author.deathYear!,
      };

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
      final selection = SearchScopeSelection.fromItems(selectedBooksForSearch);
      if (!selection.isEmpty) {
        final resolvedBooks = await SearchScopeBookResolver(
          metadataDb,
        ).resolveBookPaths(
          selection: selection,
          filteredIndexedBooks: indexedBooks,
        );
        booksToSearch = resolvedBooks.toList();
      }

      final selectedSections = searchSections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final allResults = <Map<String, dynamic>>[];
      int? totalCount;
      final searchQueries = <String>[];
      var lastEmittedCount = 0;
      var lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);
      var wasCancelled = false;

      void emitResults() {
        lastEmittedCount = allResults.length;
        lastEmitTime = DateTime.now();
        onSearchResultsUpdate(
          List<Map<String, dynamic>>.of(allResults, growable: false),
          totalCount,
          searchQueries,
          morphologicalSearch,
        );
      }

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
        includeComments: searchSections['comment'] == true,
        morphologicalSearch: morphologicalSearch,
        affixSearch: affixSearch,
        considerHamzas: considerHamzas,
        considerDiacritics: considerDiacritics,
        considerNumbers: considerNumbers,
        allPhrasesRequired: allPhrasesRequired,
        ordered: ordered,
        proximity: proximity,
        batchSize: 50,
      )) {
        if (!isMounted() || (isCancelled != null && isCancelled())) {
          wasCancelled = true;
          break;
        }

        if (totalCount == null || searchResult.totalCount > totalCount!) {
          totalCount = searchResult.totalCount;
        }

        // Avoid synchronous disk checks here; the index already carries the book
        // path, and per-row File.existsSync freezes large streamed result sets.
        final validResults = searchResult.results.where((r) {
          final bookPath = r['book_path'] as String?;
          return bookPath != null && bookPath.isNotEmpty;
        }).toList();

        allResults.addAll(validResults);
        SearchResultsAuthorSorter.sort(
          allResults,
          bookAuthorMap: bookAuthorMap,
          authorDeathYears: authorDeathYears,
        );
        final now = DateTime.now();
        final enoughNewRows = allResults.length - lastEmittedCount >= 50;
        final enoughTimePassed =
            now.difference(lastEmitTime).inMilliseconds >= 150;
        if (enoughNewRows || enoughTimePassed) {
          emitResults();
        }
      }

      if (!wasCancelled &&
          isMounted() &&
          (allResults.length != lastEmittedCount || totalCount != null)) {
        emitResults();
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
