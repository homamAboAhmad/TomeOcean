import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_logic.dart';

/// Handles search execution logic
class SearchExecutor {
  final ShamelaSearchEngine _engine = ShamelaSearchEngine();
  final PageSearchLogic _pageSearchLogic = PageSearchLogic(
    ShamelaSearchEngine(),
  );

  /// Perform search with given parameters
  Future<SearchResult> performSearch({
    required List<String> queries,
    required String operator,
    required List<String>? bookPaths,
    required List<String>? sectionTypes,
    required bool morphologicalSearch,
    required bool affixSearch,
    required bool considerHamzas,
    required bool considerDiacritics,
    required bool considerNumbers,
    required bool allPhrasesRequired,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
    int limit = 100,
  }) async {
    await _engine.initialize();

    final results = await _engine.search(
      queries: queries,
      operator: operator,
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      morphologicalSearch: morphologicalSearch,
      affixSearch: affixSearch,
      considerHamzas: considerHamzas,
      considerDiacritics: considerDiacritics,
      considerNumbers: considerNumbers, // Now this will be used
      allPhrasesRequired: allPhrasesRequired,
      ordered: ordered,
      proximity: proximity,
      proximityDistance: proximityDistance,
      limit: limit,
    );

    final totalCount = results.isNotEmpty
        ? (results.first['estimatedTotalHits'] as int? ?? 0)
        : 0;

    return SearchResult(results: results, totalCount: totalCount);
  }

  /// Determine which books to search in based on filters and selections
  List<String>? determineBooksToSearch({
    required List<Map<String, dynamic>> filteredIndexedBooks,
    required List<Map<String, dynamic>> allIndexedBooks,
    required Map<String, bool> selectedBooks,
  }) {
    // Get selected books from filtered list only
    final selectedBookPaths = selectedBooks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If filters are applied (filtered books < all indexed books), search only in filtered books
    if (filteredIndexedBooks.length < allIndexedBooks.length) {
      // Search only in filtered books
      // If user has selected specific books from filtered list, use those
      // Otherwise, use all filtered books
      if (selectedBookPaths.isNotEmpty &&
          selectedBookPaths.length < filteredIndexedBooks.length) {
        print(
          "SearchExecutor: Searching in ${selectedBookPaths.length} selected books from ${filteredIndexedBooks.length} filtered books",
        );
        return selectedBookPaths;
      } else {
        // User selected all filtered books (or didn't deselect any), search in all filtered books
        final booksToSearch = filteredIndexedBooks
            .map((book) => book['book_path'] as String)
            .toList();
        print(
          "SearchExecutor: Searching in all ${booksToSearch.length} filtered books (from ${allIndexedBooks.length} total indexed books)",
        );
        return booksToSearch;
      }
    } else {
      // No filters applied - search in all indexed books or selected books
      if (selectedBookPaths.isNotEmpty &&
          selectedBookPaths.length < allIndexedBooks.length) {
        print(
          "SearchExecutor: Searching in ${selectedBookPaths.length} selected books from ${allIndexedBooks.length} total indexed books",
        );
        return selectedBookPaths;
      } else {
        // Search in all indexed books
        print(
          "SearchExecutor: Searching in all ${allIndexedBooks.length} indexed books (no filters)",
        );
        return null;
      }
    }
  }

  /// Perform page-level search with groups (AND, OR, NOT)
  Future<SearchResult> performPageSearch({
    required Map<String, List<TextEditingController>> groupControllers,
    required String searchGrouping,
    required List<String>? bookPaths,
    required List<String>? sectionTypes,
    required bool morphologicalSearch,
    required bool affixSearch,
    required bool considerHamzas,
    required bool considerDiacritics,
    required bool considerNumbers,
    required bool allPhrasesRequired,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
    int limit = 100,
  }) async {
    await _engine.initialize();

    // Process groups
    final groups = _pageSearchLogic.processSearchGroups(groupControllers);

    // Check if any group has queries
    final hasQueries = groups.values.any((queries) => queries.isNotEmpty);
    if (!hasQueries) {
      return SearchResult(results: [], totalCount: 0);
    }

    // Build FTS query
    final ftsQuery = await _pageSearchLogic.buildPageSearchQuery(
      groups: groups,
      searchGrouping: searchGrouping,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      ordered: ordered,
      proximity: proximity,
      proximityDistance: proximityDistance,
      considerNumbers: considerNumbers,
      affixSearch: affixSearch,
    );

    if (ftsQuery.isEmpty) {
      return SearchResult(results: [], totalCount: 0);
    }

    // Search pages
    final pageResults = await _engine.searchPages(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      morphologicalSearch: morphologicalSearch,
      limit: limit,
    );

    // Convert page results to paragraph-like format for display
    // Show one result per matching page (first paragraph or aggregated page content)
    final List<Map<String, dynamic>> results = [];
    final Set<String> processedPages = {};

    for (var pageResult in pageResults) {
      final bookPath = pageResult['book_path'] as String;
      final pageNumber = pageResult['page_number'] as int;
      final pageKey = '$bookPath|$pageNumber';

      if (processedPages.contains(pageKey)) continue;
      processedPages.add(pageKey);

      // Get all paragraphs from this page
      final paragraphs = await _engine.getParagraphsByPage(
        bookPath,
        pageNumber,
      );

      // Filter by section types if specified
      final filteredParagraphs = sectionTypes != null && sectionTypes.isNotEmpty
          ? paragraphs
                .where((p) => sectionTypes.contains(p['section_type']))
                .toList()
          : paragraphs;

      if (filteredParagraphs.isNotEmpty) {
        // Use first paragraph as representative of the page
        // Or aggregate all paragraphs content for better display
        final firstPara = filteredParagraphs.first;

        // Aggregate content from all paragraphs for better snippet
        final aggregatedContent = filteredParagraphs
            .map((p) => p['content'] as String? ?? '')
            .where((c) => c.trim().isNotEmpty)
            .join(' ');

        // Add one result per page with aggregated content
        results.add({
          'id': firstPara['id'],
          'book_path': bookPath,
          'book_name': pageResult['book_name'] ?? firstPara['book_name'],
          'page_number': pageNumber,
          'section_type': firstPara['section_type'],
          'content': aggregatedContent.length > 500
              ? '${aggregatedContent.substring(0, 500)}...'
              : aggregatedContent,
          'raw_content': aggregatedContent,
          'estimatedTotalHits': pageResult['estimatedTotalHits'],
        });
      }
    }

    // totalCount should be the number of matching pages (from searchPages result)
    // This gives the total count of matching pages, not just the ones in current batch
    final totalCount = pageResults.isNotEmpty
        ? (pageResults.first['estimatedTotalHits'] as int? ??
              processedPages.length)
        : processedPages.length;

    return SearchResult(results: results, totalCount: totalCount);
  }

  /// Perform page-level search with streaming support
  /// Returns a stream that yields results in batches
  Stream<SearchResult> performPageSearchStream({
    required Map<String, List<TextEditingController>> groupControllers,
    required String searchGrouping,
    required List<String>? bookPaths,
    required List<String>? sectionTypes,
    required bool morphologicalSearch,
    required bool affixSearch,
    required bool considerHamzas,
    required bool considerDiacritics,
    required bool considerNumbers,
    required bool allPhrasesRequired,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
    int batchSize = 10,
    int? maxResults,
  }) async* {
    print(
      "===== [SearchExecutor.performPageSearchStream] ===== Starting stream search",
    );
    print("  searchGrouping: $searchGrouping");
    print("  bookPaths count: ${bookPaths?.length ?? 0}");
    print("  sectionTypes: $sectionTypes");
    print("  batchSize: $batchSize");

    await _engine.initialize();

    // Process groups
    final groups = _pageSearchLogic.processSearchGroups(groupControllers);

    print(
      "===== [SearchExecutor.performPageSearchStream] ===== Processed groups:",
    );
    groups.forEach((key, value) {
      print("  $key: ${value.length} queries");
    });

    // Check if any group has queries
    final hasQueries = groups.values.any((queries) => queries.isNotEmpty);
    if (!hasQueries) {
      print(
        "===== [SearchExecutor.performPageSearchStream] ===== No queries found, returning empty result",
      );
      yield SearchResult(results: [], totalCount: 0);
      return;
    }

    // Build FTS query
    // Build FTS query
    final ftsQuery = await _pageSearchLogic.buildPageSearchQuery(
      groups: groups,
      searchGrouping: searchGrouping,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      ordered: ordered,
      proximity: proximity,
      proximityDistance: proximityDistance,
      considerNumbers: considerNumbers,
      affixSearch: affixSearch,
    );

    print(
      "===== [SearchExecutor.performPageSearchStream] ===== Built FTS query: $ftsQuery",
    );

    if (ftsQuery.isEmpty) {
      print(
        "===== [SearchExecutor.performPageSearchStream] ===== Empty FTS query, returning empty result",
      );
      yield SearchResult(results: [], totalCount: 0);
      return;
    }

    // Stream page results
    final Set<String> processedPages = {};
    int? totalCount;
    int totalProcessed = 0;

    await for (final pageBatch in _engine.searchPagesStream(
      ftsQuery: ftsQuery,
      bookPaths: bookPaths,
      sectionTypes: sectionTypes,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      morphologicalSearch: morphologicalSearch,
      batchSize: batchSize,
      maxResults: maxResults,
    )) {
      if (totalCount == null && pageBatch.isNotEmpty) {
        totalCount = pageBatch.first['estimatedTotalHits'] as int? ?? 0;
      }

      final List<Map<String, dynamic>> batchResults = [];

      for (var pageResult in pageBatch) {
        final bookPath = pageResult['book_path'] as String;
        final pageNumber = pageResult['page_number'] as int;
        final pageKey = '$bookPath|$pageNumber';

        if (processedPages.contains(pageKey)) continue;
        processedPages.add(pageKey);

        final rawContent = pageResult['content'] as String? ?? '';
        if (rawContent.isEmpty) continue;

        final snippet = rawContent.length > 500
            ? '${rawContent.substring(0, 500)}...'
            : rawContent;

        batchResults.add({
          'book_path': bookPath,
          'book_name': pageResult['book_name'] ?? '',
          'page_number': pageNumber,
          'section_type': pageResult['section_type'] ?? '',
          'content': snippet,
          'raw_content': rawContent,
          'estimatedTotalHits': totalCount ?? 0,
        });
      }

      totalProcessed += batchResults.length;

      if (batchResults.isNotEmpty) {
        yield SearchResult(
          results: batchResults,
          totalCount: totalCount ?? totalProcessed,
        );
      }
    }

    print(
      "===== [SearchExecutor.performPageSearchStream] ===== Stream completed. Total processed: $totalProcessed",
    );
  }
}

/// Data class for search result
class SearchResult {
  final List<Map<String, dynamic>> results;
  final int totalCount;

  SearchResult({required this.results, required this.totalCount});
}
