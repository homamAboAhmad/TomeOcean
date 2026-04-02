import 'package:golden_shamela/Helpers/TextProcessor.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';

/// نتيجة بحث داخل الكتاب
class InBookSearchResult {
  final int pageIndex;
  final int paragraphIndex; // الفقرة الأولى التي تحتوي على الكلمة
  final String snippet;
  final int occurrences;

  InBookSearchResult({
    required this.pageIndex,
    required this.paragraphIndex,
    required this.snippet,
    required this.occurrences,
  });
}

/// محرك البحث داخل الكتاب المفتوح
class InBookSearchHelper {
  final WordDocument wordDocument;
  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');

  InBookSearchHelper(this.wordDocument);

  /// البحث في جميع صفحات الكتاب مع بث النتائج تدريجياً
  Stream<InBookSearchResult> searchStream({
    required String query,
    bool ignoreDiacritics = true,
    bool ignoreHamzas = true,
  }) async* {
    if (query.trim().isEmpty) return;

    final normalizedQuery = _normalizeForSearch(
      query.trim(),
      ignoreDiacritics: ignoreDiacritics,
      ignoreHamzas: ignoreHamzas,
    );

    for (int i = 0; i < wordDocument.pageFilePaths.length; i++) {
      try {
        final WordPage page = await wordDocument.getPage(i);
        final pageText = page.ps.map((p) => p.text).join(' ').replaceAll(_pgMarkerRegex, '');

        final normalizedText = _normalizeForSearch(
          pageText,
          ignoreDiacritics: ignoreDiacritics,
          ignoreHamzas: ignoreHamzas,
        );

        final count = _countOccurrences(normalizedText, normalizedQuery);
        if (count > 0) {
          // ابحث عن أول فقرة تحتوي على الكلمة
          int firstParagraphIndex = 0;
          for (int pIdx = 0; pIdx < page.ps.length; pIdx++) {
            final pText = _normalizeForSearch(
              page.ps[pIdx].text.replaceAll(_pgMarkerRegex, ''),
              ignoreDiacritics: ignoreDiacritics,
              ignoreHamzas: ignoreHamzas,
            );
            if (pText.contains(normalizedQuery)) {
              firstParagraphIndex = pIdx;
              break;
            }
          }

          yield InBookSearchResult(
            pageIndex: i,
            paragraphIndex: firstParagraphIndex,
            snippet: _extractSnippet(pageText, query, ignoreDiacritics, ignoreHamzas),
            occurrences: count,
          );
        }
      } catch (e) {
        // تخطي الصفحات التي لا يمكن تحميلها
        continue;
      }
    }
  }


  /// البحث الكامل (غير متدفق) - يُستخدم للبحث السريع في كتب صغيرة
  Future<List<InBookSearchResult>> search({
    required String query,
    bool ignoreDiacritics = true,
    bool ignoreHamzas = true,
  }) async {
    final results = <InBookSearchResult>[];
    await for (final result in searchStream(
      query: query,
      ignoreDiacritics: ignoreDiacritics,
      ignoreHamzas: ignoreHamzas,
    )) {
      results.add(result);
    }
    return results;
  }

  String _normalizeForSearch(
    String text, {
    required bool ignoreDiacritics,
    required bool ignoreHamzas,
  }) {
    String result = text;
    if (ignoreDiacritics) {
      result = TextProcessor.removeDiacritics(result);
    }
    if (ignoreHamzas) {
      result = TextProcessor.unifyHamzas(result);
    }
    return result;
  }

  int _countOccurrences(String text, String query) {
    if (query.isEmpty) return 0;
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(query, index)) != -1) {
      count++;
      index += query.length;
    }
    return count;
  }

  String _extractSnippet(
    String pageText,
    String query,
    bool ignoreDiacritics,
    bool ignoreHamzas,
  ) {
    final normalizedText = _normalizeForSearch(
      pageText,
      ignoreDiacritics: ignoreDiacritics,
      ignoreHamzas: ignoreHamzas,
    );
    final normalizedQuery = _normalizeForSearch(
      query,
      ignoreDiacritics: ignoreDiacritics,
      ignoreHamzas: ignoreHamzas,
    );

    final matchIndex = normalizedText.indexOf(normalizedQuery);
    if (matchIndex == -1) {
      return pageText.length > 100 ? '${pageText.substring(0, 100)}...' : pageText;
    }

    // استخراج مقتطف حول النتيجة مع سياق
    const contextChars = 40;
    final start = (matchIndex - contextChars).clamp(0, pageText.length);
    final end = (matchIndex + query.length + contextChars).clamp(0, pageText.length);

    String snippet = pageText.substring(start, end).trim();
    if (start > 0) snippet = '...$snippet';
    if (end < pageText.length) snippet = '$snippet...';

    return snippet;
  }
}
