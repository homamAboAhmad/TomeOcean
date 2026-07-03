import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/PageCommentsRepository.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_logic.dart';
import 'package:golden_shamela/UI/Search/helpers/search_result_section_title_resolver.dart';

class SearchExecutor {
  final ShamelaSearchEngine _engine = ShamelaSearchEngine();
  final PageSearchLogic _pageSearchLogic = PageSearchLogic(
    ShamelaSearchEngine(),
  );
  late final SearchResultSectionTitleResolver _sectionTitleResolver =
      SearchResultSectionTitleResolver(_engine);

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
    bool includeComments = false,
    int proximityDistance = 5,
    int limit = 100,
  }) async {
    if (bookPaths != null && bookPaths.isEmpty) {
      return SearchResult(results: [], totalCount: 0);
    }
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

  List<String>? determineBooksToSearch({
    required List<Map<String, dynamic>> filteredIndexedBooks,
    required List<Map<String, dynamic>> allIndexedBooks,
    required Map<String, bool> selectedBooks,
  }) {
    final selectedBookPaths = selectedBooks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (filteredIndexedBooks.length < allIndexedBooks.length) {
      if (selectedBookPaths.isNotEmpty &&
          selectedBookPaths.length < filteredIndexedBooks.length) {
        print(
          "SearchExecutor: Searching in ${selectedBookPaths.length} selected books from ${filteredIndexedBooks.length} filtered books",
        );
        return selectedBookPaths;
      } else {
        final booksToSearch = filteredIndexedBooks
            .map((book) => book['book_path'] as String)
            .toList();
        print(
          "SearchExecutor: Searching in all ${booksToSearch.length} filtered books (from ${allIndexedBooks.length} total indexed books)",
        );
        return booksToSearch;
      }
    } else {
      if (selectedBookPaths.isNotEmpty &&
          selectedBookPaths.length < allIndexedBooks.length) {
        print(
          "SearchExecutor: Searching in ${selectedBookPaths.length} selected books from ${allIndexedBooks.length} total indexed books",
        );
        return selectedBookPaths;
      } else {
        print(
          "SearchExecutor: Searching in all ${allIndexedBooks.length} indexed books (no filters)",
        );
        return null;
      }
    }
  }

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
    bool includeComments = false,
    int proximityDistance = 5,
    int limit = 100,
  }) async {
    if (bookPaths != null && bookPaths.isEmpty) {
      return SearchResult(results: [], totalCount: 0);
    }

    final groups = _pageSearchLogic.processSearchGroups(groupControllers);

    final hasQueries = groups.values.any((queries) => queries.isNotEmpty);
    if (!hasQueries) {
      return SearchResult(results: [], totalCount: 0);
    }

    final queryPlan = await _pageSearchLogic.buildPageSearchPlan(
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

    if (queryPlan.isEmpty) {
      return SearchResult(results: [], totalCount: 0);
    }

    final normalSectionTypes = _normalSectionTypes(sectionTypes);
    if (normalSectionTypes == null || normalSectionTypes.isNotEmpty) {
      await _engine.initialize();
    }
    final pageResults = normalSectionTypes == null || normalSectionTypes.isNotEmpty
        ? queryPlan.searchAllPages
        ? await _engine.listPages(
            bookPaths: bookPaths,
            sectionTypes: normalSectionTypes,
            limit: limit,
          )
        : await _engine.searchPages(
            ftsQuery: queryPlan.ftsQuery,
            bookPaths: bookPaths,
            sectionTypes: normalSectionTypes,
            considerDiacritics: considerDiacritics,
            considerHamzas: considerHamzas,
            considerNumbers: considerNumbers,
            morphologicalSearch: morphologicalSearch,
            limit: limit,
          )
        : <Map<String, dynamic>>[];

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
      final filteredParagraphs =
          normalSectionTypes != null && normalSectionTypes.isNotEmpty
          ? paragraphs
                .where((p) => normalSectionTypes.contains(p['section_type']))
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

        if (queryPlan.requiresContentFilter) {
          final matches = await _pageSearchLogic.pageMatchesConditions(
            groups: groups,
            searchGrouping: searchGrouping,
            pageContent: aggregatedContent,
            morphologicalSearch: morphologicalSearch,
            considerDiacritics: considerDiacritics,
            considerHamzas: considerHamzas,
            considerNumbers: considerNumbers,
            ordered: ordered,
            proximity: proximity,
            proximityDistance: proximityDistance,
          );
          if (!matches) continue;
        }

        final sectionTitle = await _sectionTitleResolver.resolve(
          bookPath,
          pageNumber,
        );

        results.add({
          'id': firstPara['id'],
          'book_path': bookPath,
          'book_name': pageResult['book_name'] ?? firstPara['book_name'],
          'page_number': pageNumber,
          'section_type': firstPara['section_type'],
          'section_title': sectionTitle ?? '',
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
    var totalCount = queryPlan.requiresContentFilter
        ? results.length
        : pageResults.isNotEmpty
        ? (pageResults.first['estimatedTotalHits'] as int? ??
              processedPages.length)
        : processedPages.length;

    if (includeComments) {
      final comments = await _searchComments(
        queryPlan: queryPlan,
        groups: groups,
        searchGrouping: searchGrouping,
        bookPaths: bookPaths,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        morphologicalSearch: morphologicalSearch,
        ordered: ordered,
        proximity: proximity,
        proximityDistance: proximityDistance,
        limit: limit,
      );
      results.addAll(comments);
      totalCount += comments.length;
    }

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
    bool includeComments = false,
    int proximityDistance = 5,
    int batchSize = 10,
    int? maxResults,
  }) async* {
    if (bookPaths != null && bookPaths.isEmpty) {
      yield SearchResult(results: [], totalCount: 0);
      return;
    }

    final groups = _pageSearchLogic.processSearchGroups(groupControllers);

    final hasQueries = groups.values.any((queries) => queries.isNotEmpty);
    if (!hasQueries) {
      yield SearchResult(results: [], totalCount: 0);
      return;
    }

    final queryPlan = await _pageSearchLogic.buildPageSearchPlan(
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

    if (queryPlan.isEmpty) {
      yield SearchResult(results: [], totalCount: 0);
      return;
    }

    final Set<String> processedPages = {};
    int? totalCount;
    int totalProcessed = 0;

    final normalSectionTypes = _normalSectionTypes(sectionTypes);
    if (normalSectionTypes == null || normalSectionTypes.isNotEmpty) {
      await _engine.initialize();
    }
    final pageStream = normalSectionTypes == null || normalSectionTypes.isNotEmpty
        ? queryPlan.searchAllPages
        ? _engine.listPagesStream(
            bookPaths: bookPaths,
            sectionTypes: normalSectionTypes,
            batchSize: batchSize,
            maxResults: maxResults,
          )
        : _engine.searchPagesStream(
            ftsQuery: queryPlan.ftsQuery,
            bookPaths: bookPaths,
            sectionTypes: normalSectionTypes,
            considerDiacritics: considerDiacritics,
            considerHamzas: considerHamzas,
            considerNumbers: considerNumbers,
            morphologicalSearch: morphologicalSearch,
            batchSize: batchSize,
            maxResults: maxResults,
          )
        : Stream<List<Map<String, dynamic>>>.empty();

    await for (final pageBatch in pageStream) {
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

        if (queryPlan.requiresContentFilter) {
          final matches = await _pageSearchLogic.pageMatchesConditions(
            groups: groups,
            searchGrouping: searchGrouping,
            pageContent: rawContent,
            morphologicalSearch: morphologicalSearch,
            considerDiacritics: considerDiacritics,
            considerHamzas: considerHamzas,
            considerNumbers: considerNumbers,
            ordered: ordered,
            proximity: proximity,
            proximityDistance: proximityDistance,
          );
          if (!matches) continue;
        }

        final snippet = rawContent.length > 500
            ? '${rawContent.substring(0, 500)}...'
            : rawContent;
        final sectionTitle = await _sectionTitleResolver.resolve(
          bookPath,
          pageNumber,
        );

        batchResults.add({
          'book_path': bookPath,
          'book_name': pageResult['book_name'] ?? '',
          'page_number': pageNumber,
          'section_type': pageResult['section_type'] ?? '',
          'section_title': sectionTitle ?? '',
          'content': snippet,
          'raw_content': rawContent,
          'estimatedTotalHits': queryPlan.requiresContentFilter
              ? totalProcessed + batchResults.length + 1
              : totalCount ?? 0,
        });
      }

      totalProcessed += batchResults.length;

      if (batchResults.isNotEmpty) {
        yield SearchResult(
          results: batchResults,
          totalCount: queryPlan.requiresContentFilter
              ? totalProcessed
              : totalCount ?? totalProcessed,
        );
      }
    }

    if (includeComments) {
      final comments = await _searchComments(
        queryPlan: queryPlan,
        groups: groups,
        searchGrouping: searchGrouping,
        bookPaths: bookPaths,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        morphologicalSearch: morphologicalSearch,
        ordered: ordered,
        proximity: proximity,
        proximityDistance: proximityDistance,
        limit: maxResults ?? batchSize * 5,
      );
      if (comments.isNotEmpty) {
        yield SearchResult(
          results: comments,
          totalCount: (totalCount ?? totalProcessed) + comments.length,
        );
      }
    }
  }

  List<String>? _normalSectionTypes(List<String>? sectionTypes) {
    if (sectionTypes == null) return null;
    return sectionTypes.where((section) => section != 'comment').toList();
  }

  Future<List<Map<String, dynamic>>> _searchComments({
    required PageSearchQueryPlan queryPlan,
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required List<String>? bookPaths,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool morphologicalSearch,
    required bool ordered,
    required bool proximity,
    required int proximityDistance,
    required int limit,
  }) async {
    final results = await PageCommentsRepository.instance.search(
      ftsQuery: queryPlan.ftsQuery,
      searchAllComments: queryPlan.searchAllPages,
      contentColumn: _contentColumn(
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        morphologicalSearch: morphologicalSearch,
      ),
      bookPaths: bookPaths,
      limit: limit,
    );
    if (!queryPlan.requiresContentFilter) return results;
    final filtered = <Map<String, dynamic>>[];
    for (final result in results) {
      final content = result['raw_content']?.toString() ?? '';
      final matches = await _pageSearchLogic.pageMatchesConditions(
        groups: groups,
        searchGrouping: searchGrouping,
        pageContent: content,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        ordered: ordered,
        proximity: proximity,
        proximityDistance: proximityDistance,
      );
      if (matches) filtered.add(result);
    }
    return filtered;
  }

  String _contentColumn({
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool morphologicalSearch,
  }) {
    if (morphologicalSearch) return 'normalized_content';
    if (considerDiacritics && considerHamzas) {
      return considerNumbers
          ? 'fully_preserved_content'
          : 'fully_preserved_no_numbers_content';
    }
    if (considerDiacritics) {
      return considerNumbers
          ? 'diacritics_preserved_content'
          : 'diacritics_preserved_no_numbers_content';
    }
    if (considerHamzas) {
      return considerNumbers
          ? 'hamza_preserved_content'
          : 'hamza_preserved_no_numbers_content';
    }
    return considerNumbers
        ? 'normalized_content'
        : 'normalized_no_numbers_content';
  }
}

class SearchResult {
  final List<Map<String, dynamic>> results;
  final int totalCount;

  SearchResult({required this.results, required this.totalCount});
}
