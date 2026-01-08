import 'package:sqflite/sqflite.dart';
import '../ArabicMorphologicalAnalyzer.dart';
import '../page_content_aggregator.dart';
import 'text_normalization.dart';

/// Indexing operations for the search engine
class IndexingOperations {
  final Database database;

  IndexingOperations(this.database);

  /// Index pages by aggregating paragraph content
  Future<void> indexPages(
    String bookPath,
    String bookName,
    List<Map<String, dynamic>> paragraphs,
  ) async {
    final pageGroups = PageContentAggregator.groupByPage(paragraphs);
    final pageBatch = database.batch();

    for (var entry in pageGroups.entries) {
      final pageParagraphs = entry.value;
      if (pageParagraphs.isEmpty) continue;

      final pageNumber = pageParagraphs.first['page_number'] as int? ?? 0;
      final aggregatedContent = PageContentAggregator.aggregatePageContent(
        pageParagraphs,
      );
      if (aggregatedContent.trim().isEmpty) continue;

      final normalized = TextNormalization.normalizeText(
        aggregatedContent,
        removeDiacritics: true,
        unifyHamzas: true,
      );
      final hamzaPreserved = TextNormalization.normalizeText(
        aggregatedContent,
        removeDiacritics: true,
        unifyHamzas: false,
      );
      final diacriticsPreserved = TextNormalization.normalizeText(
        aggregatedContent,
        removeDiacritics: false,
        unifyHamzas: true,
      );

      // New: Normalized without numbers
      final normalizedNoNumbers = TextNormalization.normalizeText(
        aggregatedContent,
        removeDiacritics: true,
        unifyHamzas: true,
        removeNumbers: true,
      );

      String? noDiacriticsContent;
      if (!TextNormalization.hasDiacritics(aggregatedContent)) {
        noDiacriticsContent = TextNormalization.normalizeText(
          aggregatedContent,
          removeDiacritics: true,
          unifyHamzas: true,
        );
      }

      final morphological = await createMorphologicalContent(aggregatedContent);

      pageBatch.insert('pages_fts', {
        'book_path': bookPath,
        'book_name': bookName,
        'page_number': pageNumber,
        'content': aggregatedContent,
        'normalized_content': normalized,
        'hamza_preserved_content': hamzaPreserved,
        'diacritics_preserved_content': diacriticsPreserved,
        'no_diacritics_content': noDiacriticsContent ?? '',
        'morphological_content': morphological,
        'normalized_no_numbers_content': normalizedNoNumbers,
      });
    }

    await pageBatch.commit(noResult: true);
  }

  /// Index words for morphological search using ISRI stemmer
  Future<void> indexWordsForMorphology(
    String id,
    String bookPath,
    int pageNumber,
    String sectionType,
    String content,
    Batch batch,
  ) async {
    final words = TextNormalization.extractArabicWords(content);

    if (words.isEmpty) {
      return;
    }

    for (String word in words) {
      if (word.length < 2) continue;

      final root = await ArabicMorphologicalAnalyzer.stem(word);
      final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(
        word,
        unifyHamzas: false,
      );

      try {
        batch.insert('morphological_index', {
          'id': id,
          'book_path': bookPath,
          'page_number': pageNumber,
          'section_type': sectionType,
          'word': word,
          'root': root,
          'normalized_word': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e) {
        // Ignore duplicate key errors
      }
    }
  }

  /// Create morphological content using ISRI stemmer
  Future<String> createMorphologicalContent(String text) async {
    final words = TextNormalization.extractArabicWords(text);
    final List<String> morphological = [];

    for (String word in words) {
      if (word.length < 2) continue;

      final normalized = ArabicMorphologicalAnalyzer.normalizeForMorphology(
        word,
      );
      morphological.add(normalized);

      final root = await ArabicMorphologicalAnalyzer.stem(normalized);
      if (root.length >= 2 && root != normalized) {
        morphological.add(root);
      }
    }

    return morphological.join(' ');
  }
}
