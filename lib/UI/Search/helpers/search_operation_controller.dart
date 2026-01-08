import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/Search/helpers/search_executor.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';

/// Controller responsible for managing search operations.
///
/// Handles search execution, state management, and result processing.
class SearchOperationController {
  final SearchExecutor _searchExecutor;
  final BooksMetadataDatabase _metadataDb;

  SearchOperationController({
    required SearchExecutor searchExecutor,
    required BooksMetadataDatabase metadataDb,
  }) : _searchExecutor = searchExecutor,
       _metadataDb = metadataDb;

  /// Checks if there are any search queries in the controllers.
  bool hasSearchQueries(
    Map<String, List<TextEditingController>> groupControllers,
  ) {
    for (var group in groupControllers.values) {
      if (group.any((c) => c.text.trim().isNotEmpty)) {
        return true;
      }
    }
    return false;
  }

  /// Executes the search with given parameters.
  Future<SearchResult> executeSearch({
    required Map<String, List<TextEditingController>> groupControllers,
    required String searchGrouping,
    required List<String>? booksToSearch,
    required List<String> selectedSections,
    required Map<String, bool> searchSections,
    required bool morphologicalSearch,
    required bool affixSearch,
    required bool considerHamzas,
    required bool considerDiacritics,
    required bool considerNumbers,
    required bool allPhrasesRequired,
    required bool ordered,
    required bool proximity,
  }) async {
    return await _searchExecutor.performPageSearch(
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
    );
  }

  /// Gets the list of selected section types.
  ///
  /// **QA Note**: Explicitly excludes 'comment' section type as it's under development.
  /// This is a safety measure to prevent accidental queries to the comments field.
  List<String> getSelectedSections(Map<String, bool> searchSections) {
    // Define valid section types (excludes 'comment' which is under development)
    const validSectionTypes = {'main', 'footnote', 'title'};

    return searchSections.entries
        .where((e) => e.value && validSectionTypes.contains(e.key))
        .map((e) => e.key)
        .toList();
  }

  /// Builds a map of group controllers with their query strings.
  Map<String, List<String>> buildGroupControllersMap(
    Map<String, List<TextEditingController>> groupControllers,
  ) {
    final groupControllersMap = <String, List<String>>{};
    groupControllers.forEach((key, controllers) {
      final queries = <String>[];
      for (final controller in controllers) {
        final query = controller.text.trim();
        if (query.isNotEmpty) {
          queries.add(query);
        }
      }
      groupControllersMap[key] = queries;
    });
    return groupControllersMap;
  }

  /// Builds search parameters map for callback.
  Map<String, dynamic> buildSearchParams({
    required Map<String, List<String>> groupControllersMap,
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
  }) {
    return {
      'groupControllers': groupControllersMap,
      'searchGrouping': searchGrouping,
      'selectedBooksForSearch': selectedBooksForSearch,
      'searchSections': searchSections,
      'morphologicalSearch': morphologicalSearch,
      'affixSearch': affixSearch,
      'considerHamzas': considerHamzas,
      'considerDiacritics': considerDiacritics,
      'considerNumbers': considerNumbers,
      'allPhrasesRequired': allPhrasesRequired,
      'ordered': ordered,
      'proximity': proximity,
      'indexedBooks': indexedBooks,
    };
  }
}
