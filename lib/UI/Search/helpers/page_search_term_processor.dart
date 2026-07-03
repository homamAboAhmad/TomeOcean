import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';
import 'package:golden_shamela/Helpers/search_engine/text_normalization.dart';
import 'package:golden_shamela/UI/Search/helpers/fts_query_builder.dart';

class PageSearchTermProcessor {
  static Future<List<String>> processTerms(
    List<String> rawTerms, {
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
  }) async {
    final terms = <String>[];
    for (final rawTerm in rawTerms) {
      final term = await processTerm(
        rawTerm,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
      );
      if (term.isNotEmpty) terms.add(term);
    }
    return terms;
  }

  static Future<String> processTerm(
    String term, {
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
  }) async {
    if (morphologicalSearch) {
      final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(
        term,
      );
      final root = await ArabicMorphologicalAnalyzer.stem(normalized);
      return FtsQueryBuilder.clean(root.isEmpty ? normalized : root);
    }

    return FtsQueryBuilder.clean(
      TextNormalization.normalizeText(
        term,
        removeDiacritics: !considerDiacritics,
        unifyHamzas: !considerHamzas,
        removeNumbers: !considerNumbers,
      ),
    );
  }

  static Future<String> searchableContent(
    String content, {
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
  }) async {
    if (!morphologicalSearch) {
      return FtsQueryBuilder.clean(
        TextNormalization.normalizeText(
          content,
          removeDiacritics: !considerDiacritics,
          unifyHamzas: !considerHamzas,
          removeNumbers: !considerNumbers,
        ),
      );
    }

    final parts = <String>[];
    for (final word in TextNormalization.extractArabicWords(content)) {
      if (word.length < 2) continue;
      final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(
        word,
      );
      parts.add(normalized);
      final root = await ArabicMorphologicalAnalyzer.stem(normalized);
      if (root.length >= 2 && root != normalized) parts.add(root);
    }
    return FtsQueryBuilder.clean(parts.join(' '));
  }
}
