import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';
import 'package:golden_shamela/UI/Search/helpers/fts_query_builder.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_content_matcher.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_term_processor.dart';

class PageSearchQueryPlan {
  final String ftsQuery;
  final bool searchAllPages;
  final bool requiresContentFilter;

  const PageSearchQueryPlan({
    required this.ftsQuery,
    required this.searchAllPages,
    required this.requiresContentFilter,
  });

  bool get isEmpty => !searchAllPages && ftsQuery.isEmpty;
}

/// Builds page-level search plans from Shamela-style groups.
class PageSearchLogic {
  PageSearchLogic(ShamelaSearchEngine engine);

  Map<String, List<String>> processSearchGroups(
    Map<String, List<TextEditingController>> groupControllers,
  ) {
    final groups = {'and': <String>[], 'or': <String>[], 'not': <String>[]};

    for (final entry in groupControllers.entries) {
      final queries = entry.value
          .map((controller) => controller.text.trim())
          .where((query) => query.isNotEmpty)
          .toList();
      if (queries.isNotEmpty) groups[entry.key] = queries;
    }

    return groups;
  }

  Future<PageSearchQueryPlan> buildPageSearchPlan({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
    bool considerNumbers = true,
    bool affixSearch = false,
  }) async {
    final activeGroups = groups.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    if (activeGroups.isEmpty) return _emptyPlan;

    final positiveQueries = <String>[];
    final notQueries = <String>[];

    for (final group in activeGroups) {
      final terms = await PageSearchTermProcessor.processTerms(
        group.value,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
      );
      if (terms.isEmpty) continue;

      final query = _groupQuery(
        terms,
        group.key,
        searchGrouping,
        affixSearch: affixSearch,
      );
      if (query.isEmpty) continue;

      if (group.key == 'not') {
        notQueries.add('($query)');
      } else {
        positiveQueries.add('($query)');
      }
    }

    if (searchGrouping != 'all' && notQueries.isNotEmpty) {
      return _filterAllPagesPlan;
    }

    var finalQuery = '';
    if (positiveQueries.isNotEmpty) {
      finalQuery = searchGrouping == 'all'
          ? positiveQueries.join(' AND ')
          : positiveQueries.join(' OR ');
    }

    if (searchGrouping == 'all' && notQueries.isNotEmpty) {
      if (finalQuery.isEmpty) return _filterAllPagesPlan;
      finalQuery = '$finalQuery NOT (${notQueries.join(' OR ')})';
    }

    return PageSearchQueryPlan(
      ftsQuery: finalQuery,
      searchAllPages: false,
      requiresContentFilter: ordered || proximity,
    );
  }

  Future<String> buildPageSearchQuery({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
    bool considerNumbers = true,
    bool affixSearch = false,
  }) async {
    final plan = await buildPageSearchPlan(
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
    return plan.ftsQuery;
  }

  Future<bool> pageMatchesConditions({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required String pageContent,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
  }) {
    return PageSearchContentMatcher.matchesConditions(
      groups: groups,
      searchGrouping: searchGrouping,
      pageContent: pageContent,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      ordered: ordered,
      proximity: proximity,
      proximityDistance: proximityDistance,
    );
  }

  String _groupQuery(
    List<String> terms,
    String groupKey,
    String searchGrouping, {
    required bool affixSearch,
  }) {
    final operator = switch (groupKey) {
      'and' => 'AND',
      'or' => 'OR',
      'not' => searchGrouping == 'all' ? 'OR' : 'AND',
      _ => 'AND',
    };
    return FtsQueryBuilder.joinTerms(
      terms,
      operator,
      affixSearch: affixSearch,
    );
  }

  static const _emptyPlan = PageSearchQueryPlan(
    ftsQuery: '',
    searchAllPages: false,
    requiresContentFilter: false,
  );

  static const _filterAllPagesPlan = PageSearchQueryPlan(
    ftsQuery: '',
    searchAllPages: true,
    requiresContentFilter: true,
  );
}
