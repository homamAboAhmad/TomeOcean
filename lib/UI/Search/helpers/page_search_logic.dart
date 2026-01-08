import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';
import 'package:golden_shamela/Helpers/search_engine/text_normalization.dart';
import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';

/// Handles page-level search logic with group conditions (AND, OR, NOT)
class PageSearchLogic {
  final ShamelaSearchEngine _engine;

  PageSearchLogic(this._engine);

  /// Process search groups and build query conditions
  Map<String, List<String>> processSearchGroups(
    Map<String, List<TextEditingController>> groupControllers,
  ) {
    final Map<String, List<String>> groups = {'and': [], 'or': [], 'not': []};

    for (var entry in groupControllers.entries) {
      final groupType = entry.key;
      final controllers = entry.value;

      final queries = controllers
          .map((c) => c.text.trim())
          .where((q) => q.isNotEmpty)
          .toList();

      if (queries.isNotEmpty) {
        groups[groupType] = queries;
      }
    }

    return groups;
  }

  /// Evaluate if a page meets all conditions based on search grouping
  bool evaluatePageConditions({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required String pageContent,
  }) {
    // Filter out empty groups
    final activeGroups = groups.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (activeGroups.isEmpty) return false;

    if (searchGrouping == 'all') {
      // All groups must be satisfied
      return _evaluateAllGroups(activeGroups, pageContent);
    } else {
      // One or more groups must be satisfied
      return _evaluateOneOrMoreGroups(activeGroups, pageContent);
    }
  }

  /// Check if page satisfies all group conditions
  bool _evaluateAllGroups(
    List<MapEntry<String, List<String>>> groups,
    String pageContent,
  ) {
    for (var group in groups) {
      final groupType = group.key;
      final queries = group.value;

      if (groupType == 'and') {
        // All queries must be in page content
        if (!_allQueriesInContent(queries, pageContent)) {
          return false;
        }
      } else if (groupType == 'or') {
        // At least one query must be in page content
        if (!_anyQueryInContent(queries, pageContent)) {
          return false;
        }
      } else if (groupType == 'not') {
        // None of the queries should be in page content
        if (_anyQueryInContent(queries, pageContent)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Check if page satisfies at least one group condition
  bool _evaluateOneOrMoreGroups(
    List<MapEntry<String, List<String>>> groups,
    String pageContent,
  ) {
    for (var group in groups) {
      final groupType = group.key;
      final queries = group.value;

      bool groupSatisfied = false;

      if (groupType == 'and') {
        groupSatisfied = _allQueriesInContent(queries, pageContent);
      } else if (groupType == 'or') {
        groupSatisfied = _anyQueryInContent(queries, pageContent);
      } else if (groupType == 'not') {
        groupSatisfied = !_anyQueryInContent(queries, pageContent);
      }

      if (groupSatisfied) {
        return true;
      }
    }
    return false;
  }

  /// Check if all queries are in content
  bool _allQueriesInContent(List<String> queries, String content) {
    final normalizedContent = content.toLowerCase();
    return queries.every(
      (query) => normalizedContent.contains(query.toLowerCase()),
    );
  }

  /// Check if any query is in content
  bool _anyQueryInContent(List<String> queries, String content) {
    final normalizedContent = content.toLowerCase();
    return queries.any(
      (query) => normalizedContent.contains(query.toLowerCase()),
    );
  }

  /// Build FTS query for page search
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
    final activeGroups = groups.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (activeGroups.isEmpty) return '';

    // Separate NOT groups from others
    final List<String> positiveQueries = [];
    final List<String> notQueries = [];

    // Helper to normalize or stem a single term
    Future<String> processTerm(String term) async {
      if (morphologicalSearch) {
        // For morphological search, we stem the word
        // TextNormalization is applied internally by the stemmer or before it
        // Note: The database morphological_content contains space-separated roots/stems
        // e.g. "ktb ktb" or "ktb"
        final normalized = TextNormalization.normalizeText(
          term,
          removeDiacritics: true,
          unifyHamzas: false, // Keep hamzas for accurate stemming if possible
          removeNumbers: !considerNumbers,
        ).trim();

        final root = await ArabicMorphologicalAnalyzer.stem(normalized);
        print(
          '===== [PageSearchLogic] Morphological: "$term" -> normalized: "$normalized" -> root: "$root"',
        );
        return root;
      } else {
        // Standard normalization
        return TextNormalization.normalizeText(
          term,
          removeDiacritics: !considerDiacritics,
          unifyHamzas: !considerHamzas,
          removeNumbers: !considerNumbers,
        ).trim();
      }
    }

    // Helper to format query (phrase vs word, affix vs exact)
    String formatQuery(String q) {
      if (q.contains(' ')) {
        // It's a phrase - use quotes
        return '"$q"';
      } else {
        // Single word
        if (affixSearch) {
          // Prefix search for affix (supports suffixes like "wal-")
          // Standard FTS5 prefix search is term*
          return '$q*';
        } else {
          // Exact match
          return q;
        }
      }
    }

    for (var group in activeGroups) {
      final groupType = group.key;
      final queryStrings = group.value;

      if (groupType == 'and') {
        // Process all terms
        List<String> terms = [];
        for (var q in queryStrings) {
          final processed = await processTerm(q);
          if (processed.isNotEmpty) terms.add(processed);
        }

        if (terms.isEmpty) continue;

        String andQuery;

        if (ordered && proximity) {
          if (terms.length >= 2) {
            final formattedTerms = terms.map(formatQuery).toList();
            andQuery = 'NEAR(${formattedTerms.join(', ')}, $proximityDistance)';
          } else {
            andQuery = formatQuery(terms.first);
          }
        } else if (ordered) {
          if (terms.length >= 2) {
            final formattedTerms = terms.map(formatQuery).toList();
            andQuery = 'NEAR(${formattedTerms.join(', ')}, 1000)';
          } else {
            andQuery = formatQuery(terms.first);
          }
        } else {
          final phraseQueries = terms.map(formatQuery).toList();
          andQuery = phraseQueries.join(' AND ');
        }
        positiveQueries.add('($andQuery)');
      } else if (groupType == 'or') {
        List<String> terms = [];
        for (var q in queryStrings) {
          final processed = await processTerm(q);
          if (processed.isNotEmpty) terms.add(processed);
        }

        if (terms.isEmpty) continue;

        final orQuery = terms.map(formatQuery).join(' OR ');
        positiveQueries.add('($orQuery)');
      } else if (groupType == 'not') {
        List<String> terms = [];
        for (var q in queryStrings) {
          final processed = await processTerm(q);
          if (processed.isNotEmpty) terms.add(processed);
        }

        if (terms.isEmpty) continue;

        final notQuery = terms.map(formatQuery).join(' OR ');
        notQueries.add('($notQuery)');
      }
    }

    // Build final query
    String finalQuery = '';

    if (searchGrouping == 'all') {
      if (positiveQueries.isNotEmpty) {
        finalQuery = positiveQueries.join(' AND ');
      }
      if (notQueries.isNotEmpty) {
        final notTerms = notQueries.join(' OR ');
        if (finalQuery.isNotEmpty) {
          finalQuery = '$finalQuery NOT ($notTerms)';
        } else {
          finalQuery = 'NOT ($notTerms)';
        }
      }
    } else {
      if (positiveQueries.isNotEmpty) {
        finalQuery = positiveQueries.join(' OR ');
      }
      if (notQueries.isNotEmpty && finalQuery.isNotEmpty) {
        final notTerms = notQueries.join(' OR ');
        finalQuery = '($finalQuery) NOT ($notTerms)';
      }
    }

    return finalQuery;
  }
}
