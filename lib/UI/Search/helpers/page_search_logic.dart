import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';

/// Handles page-level search logic with group conditions (AND, OR, NOT)
class PageSearchLogic {
  final ShamelaSearchEngine _engine;

  PageSearchLogic(this._engine);

  /// Process search groups and build query conditions
  Map<String, List<String>> processSearchGroups(
    Map<String, List<TextEditingController>> groupControllers,
  ) {
    final Map<String, List<String>> groups = {
      'and': [],
      'or': [],
      'not': [],
    };

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
    return queries.every((query) => 
        normalizedContent.contains(query.toLowerCase()));
  }

  /// Check if any query is in content
  bool _anyQueryInContent(List<String> queries, String content) {
    final normalizedContent = content.toLowerCase();
    return queries.any((query) => 
        normalizedContent.contains(query.toLowerCase()));
  }

  /// Build FTS query for page search
  String buildPageSearchQuery({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool ordered,
    required bool proximity,
    int proximityDistance = 5,
  }) {
    final activeGroups = groups.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (activeGroups.isEmpty) return '';

    // Separate NOT groups from others
    final List<String> positiveQueries = [];
    final List<String> notQueries = [];

    for (var group in activeGroups) {
      final groupType = group.key;
      final queries = group.value;

      if (groupType == 'and') {
        // All queries must match (AND within group)
        String andQuery;
        final terms = queries.map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
        
        if (terms.isEmpty) continue;
        
        // Helper function to format query (phrase or word)
        String formatQuery(String q) {
          if (q.contains(' ')) {
            // It's a phrase - use quotes
            return '"$q"';
          } else {
            // Single word - use prefix search
            return '$q*';
          }
        }
        
        if (ordered && proximity) {
          // Ordered and proximity: use NEAR with distance
          // NEAR maintains order and enforces proximity
          if (terms.length >= 2) {
            final normalizedTerms = terms.map(formatQuery).toList();
            andQuery = 'NEAR(${normalizedTerms.join(', ')}, $proximityDistance)';
          } else {
            andQuery = formatQuery(terms.first);
          }
        } else if (ordered) {
          // Ordered: phrases must appear in order (not necessarily adjacent)
          // Use NEAR with large distance to ensure order while allowing separation
          // Large distance (1000) allows phrases to be far apart but maintains order
          if (terms.length >= 2) {
            final normalizedTerms = terms.map(formatQuery).toList();
            // Use large distance to allow phrases to be separated but maintain order
            andQuery = 'NEAR(${normalizedTerms.join(', ')}, 1000)';
          } else {
            andQuery = formatQuery(terms.first);
          }
        } else {
          // Regular AND - all phrases/words must exist (order doesn't matter)
          final phraseQueries = terms.map(formatQuery).toList();
          andQuery = phraseQueries.join(' AND ');
        }
        positiveQueries.add('($andQuery)');
      } else if (groupType == 'or') {
        // Any query can match (OR within group)
        // Note: ordered/proximity don't make sense for OR groups
        final terms = queries.map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
        if (terms.isEmpty) continue;
        
        final orQuery = terms.map((q) {
          if (q.contains(' ')) {
            return '"$q"';
          } else {
            return '$q*';
          }
        }).join(' OR ');
        positiveQueries.add('($orQuery)');
      } else if (groupType == 'not') {
        // NOT queries - collect separately
        final terms = queries.map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
        if (terms.isEmpty) continue;
        
        final notQuery = terms.map((q) {
          if (q.contains(' ')) {
            return '"$q"';
          } else {
            return '$q*';
          }
        }).join(' OR ');
        notQueries.add('($notQuery)');
      }
    }

    // Build final query
    // FTS5 syntax: NOT must come before the term, not after AND
    // Correct: "term NOT (term2 OR term3)" not "term AND NOT (term2 OR term3)"
    String finalQuery = '';
    
    if (searchGrouping == 'all') {
      // All positive groups must match
      if (positiveQueries.isNotEmpty) {
        finalQuery = positiveQueries.join(' AND ');
      }
      // Add NOT conditions - FTS5: NOT without AND before it
      if (notQueries.isNotEmpty) {
        final notTerms = notQueries.join(' OR ');
        if (finalQuery.isNotEmpty) {
          // FTS5 format: "term1 AND term2 NOT (term3 OR term4)"
          finalQuery = '$finalQuery NOT ($notTerms)';
        } else {
          finalQuery = 'NOT ($notTerms)';
        }
      }
    } else {
      // One or more groups must match
      if (positiveQueries.isNotEmpty) {
        finalQuery = positiveQueries.join(' OR ');
      }
      // For "one or more", NOT groups are handled separately
      if (notQueries.isNotEmpty && finalQuery.isNotEmpty) {
        final notTerms = notQueries.join(' OR ');
        // Group positive queries, then add NOT
        finalQuery = '($finalQuery) NOT ($notTerms)';
      }
    }

    return finalQuery;
  }
}

