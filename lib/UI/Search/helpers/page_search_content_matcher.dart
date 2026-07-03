import 'package:golden_shamela/UI/Search/helpers/fts_query_builder.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_term_processor.dart';

class PageSearchContentMatcher {
  static Future<bool> matchesConditions({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required String pageContent,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool ordered,
    required bool proximity,
    bool affixSearch = false,
    int proximityDistance = 5,
  }) async {
    final activeGroups = groups.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    if (activeGroups.isEmpty) return false;

    final searchableContent = await PageSearchTermProcessor.searchableContent(
      pageContent,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
    );

    if (searchGrouping == 'all') {
      for (final group in activeGroups) {
        final satisfied = await _groupMatches(
          group.key,
          group.value,
          searchableContent,
          morphologicalSearch: morphologicalSearch,
          considerDiacritics: considerDiacritics,
          considerHamzas: considerHamzas,
          considerNumbers: considerNumbers,
          ordered: ordered,
          proximity: proximity,
          affixSearch: affixSearch,
          proximityDistance: proximityDistance,
          allGroupsMode: true,
        );
        if (!satisfied) return false;
      }
      return true;
    }

    for (final group in activeGroups) {
      final satisfied = await _groupMatches(
        group.key,
        group.value,
        searchableContent,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        ordered: ordered,
        proximity: proximity,
        affixSearch: affixSearch,
        proximityDistance: proximityDistance,
        allGroupsMode: false,
      );
      if (satisfied) return true;
    }
    return false;
  }

  static Future<bool> _groupMatches(
    String groupKey,
    List<String> rawTerms,
    String searchableContent, {
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool ordered,
    required bool proximity,
    required bool affixSearch,
    required int proximityDistance,
    required bool allGroupsMode,
  }) async {
    final terms = await PageSearchTermProcessor.processTerms(
      rawTerms,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
    );
    if (terms.isEmpty) return false;

    if (groupKey == 'and') {
      return _andTermsMatch(
        searchableContent,
        terms,
        ordered: ordered,
        proximity: proximity,
        affixSearch: affixSearch,
        proximityDistance: proximityDistance,
      );
    }
    if (groupKey == 'or') {
      return terms.any(
        (term) => _termPresent(
          searchableContent,
          term,
          affixSearch: affixSearch,
        ),
      );
    }

    final allNotTermsPresent = terms.every(
      (term) => _termPresent(
        searchableContent,
        term,
        affixSearch: affixSearch,
      ),
    );
    if (!allGroupsMode) return !allNotTermsPresent;
    return !terms.any(
      (term) => _termPresent(
        searchableContent,
        term,
        affixSearch: affixSearch,
      ),
    );
  }

  static bool _andTermsMatch(
    String content,
    List<String> terms, {
    required bool ordered,
    required bool proximity,
    required bool affixSearch,
    required int proximityDistance,
  }) {
    if (!terms.every(
      (term) => _termPresent(content, term, affixSearch: affixSearch),
    )) {
      return false;
    }
    if (ordered && proximity) {
      return _termsInOrder(
        content,
        terms,
        affixSearch: affixSearch,
        maxGap: proximityDistance,
      );
    }
    if (ordered) {
      return _termsInOrder(content, terms, affixSearch: affixSearch);
    }
    if (proximity) {
      return _termsWithinWindow(
        content,
        terms,
        proximityDistance,
        affixSearch: affixSearch,
      );
    }
    return true;
  }

  static bool _termPresent(
    String content,
    String term, {
    required bool affixSearch,
  }) {
    return _phrasePositions(
      _tokens(content),
      FtsQueryBuilder.tokens(term),
      affixSearch: affixSearch,
    )
        .isNotEmpty;
  }

  static bool _termsInOrder(
    String content,
    List<String> terms, {
    required bool affixSearch,
    int? maxGap,
  }) {
    final tokens = _tokens(content);
    var previousStart = -1;
    var previousLength = 0;

    for (final term in terms) {
      final termTokens = FtsQueryBuilder.tokens(term);
      final nextStart = _phrasePositions(
        tokens,
        termTokens,
        affixSearch: affixSearch,
      ).firstWhere(
        (position) {
          final afterPrevious = position > previousStart;
          final closeEnough = maxGap == null ||
              previousStart < 0 ||
              position - (previousStart + previousLength) <= maxGap;
          return afterPrevious && closeEnough;
        },
        orElse: () => -1,
      );
      if (nextStart < 0) return false;
      previousStart = nextStart;
      previousLength = termTokens.length;
    }
    return true;
  }

  static bool _termsWithinWindow(
    String content,
    List<String> terms,
    int proximityDistance, {
    required bool affixSearch,
  }) {
    final tokens = _tokens(content);
    final positions = <_TermPosition>[];
    for (var i = 0; i < terms.length; i++) {
      final termPositions = _phrasePositions(
        tokens,
        FtsQueryBuilder.tokens(terms[i]),
        affixSearch: affixSearch,
      );
      if (termPositions.isEmpty) return false;
      positions.addAll(
        termPositions.map((position) => _TermPosition(i, position)),
      );
    }

    positions.sort((a, b) => a.position.compareTo(b.position));
    final counts = <int, int>{};
    var covered = 0;
    var left = 0;

    for (var right = 0; right < positions.length; right++) {
      final rightTerm = positions[right].termIndex;
      counts[rightTerm] = (counts[rightTerm] ?? 0) + 1;
      if (counts[rightTerm] == 1) covered++;

      while (covered == terms.length && left <= right) {
        final span = positions[right].position - positions[left].position;
        if (span <= proximityDistance) return true;

        final leftTerm = positions[left].termIndex;
        counts[leftTerm] = counts[leftTerm]! - 1;
        if (counts[leftTerm] == 0) covered--;
        left++;
      }
    }
    return false;
  }

  static List<int> _phrasePositions(
    List<String> contentTokens,
    List<String> phrase, {
    required bool affixSearch,
  }) {
    if (phrase.isEmpty || contentTokens.length < phrase.length) return const [];
    final positions = <int>[];
    for (var i = 0; i <= contentTokens.length - phrase.length; i++) {
      var matched = true;
      for (var j = 0; j < phrase.length; j++) {
        if (!_tokenMatches(contentTokens[i + j], phrase[j], affixSearch)) {
          matched = false;
          break;
        }
      }
      if (matched) positions.add(i);
    }
    return positions;
  }

  static List<String> _tokens(String content) {
    return content.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  static bool _tokenMatches(
    String contentToken,
    String phraseToken,
    bool affixSearch,
  ) {
    if (!affixSearch) return contentToken == phraseToken;
    return contentToken.startsWith(phraseToken);
  }
}

class _TermPosition {
  final int termIndex;
  final int position;

  const _TermPosition(this.termIndex, this.position);
}
