import 'dart:convert';
import 'dart:io';

import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_content_matcher.dart';
import 'package:golden_shamela/UI/LibraryCommon/grouped_search_panel.dart';
import 'package:path/path.dart' as p;

class RecitedTextRepository {
  Future<RecitedTextSnapshot> loadSnapshot() async {
    await AppStoragePaths.ensureBaseDirectories();
    final chapters = await _readList(
      AppStoragePaths.recitedTextChaptersPath,
      ChapterInfo.fromJson,
    );
    final passages = await _readList(
      AppStoragePaths.recitedTextPassagesPath,
      PassageUnit.fromJson,
    );
    final resources = await _readList(
      AppStoragePaths.recitedTextTafsirIndexPath,
      TafsirResource.fromJson,
    );
    return RecitedTextSnapshot(
      chapters: chapters,
      passages: passages,
      tafsirResources: resources,
    );
  }

  Future<Map<String, String>> loadTafsir(TafsirResource resource) async {
    final file = File(p.join(AppStoragePaths.recitedTextTafsirPath, resource.fileName));
    final json = await _readJson(file);
    final rawItems = json['tafsirs'] as List? ?? const [];
    final result = <String, String>{};
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final key = raw['passageKey']?.toString() ?? raw['verse_key']?.toString();
      final text = raw['text']?.toString();
      if (key == null || key.isEmpty || text == null) continue;
      result[key] = _stripHtml(text);
    }
    return result;
  }

  Future<List<RecitedTextSearchResult>> search({
    required RecitedTextSnapshot snapshot,
    required GroupedSearchRequest request,
  }) async {
    if (!request.hasActiveTerms) return const [];
    final chaptersByNumber = {
      for (final chapter in snapshot.chapters) chapter.number: chapter,
    };
    final results = <RecitedTextSearchResult>[];
    final firstTerm = request.firstTerm;
    for (final passage in snapshot.passages) {
      final matched = await PageSearchContentMatcher.matchesConditions(
        groups: request.groups,
        searchGrouping: request.searchGrouping,
        pageContent: passage.text,
        morphologicalSearch: request.morphologicalSearch,
        considerDiacritics: request.considerDiacritics,
        considerHamzas: request.considerHamzas,
        considerNumbers: request.considerNumbers,
        ordered: request.ordered,
        proximity: request.proximity,
        affixSearch: request.affixSearch,
      );
      if (!matched) continue;
      final chapter = chaptersByNumber[passage.chapterNumber];
      if (chapter == null) continue;
      results.add(
        RecitedTextSearchResult(
          passage: passage,
          chapter: chapter,
          snippet: _snippet(passage.text, firstTerm),
        ),
      );
      if (results.length >= 600) return results;
    }
    return results;
  }

  Future<List<T>> _readList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final file = File(path);
    final json = await _readJson(file);
    final list = json is List ? json : const [];
    return list
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<dynamic> _readJson(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('ملفات النص المقروء غير موجودة', file.path);
    }
    final text = await file.readAsString();
    return jsonDecode(text.replaceFirst('\uFEFF', ''));
  }

  String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }

  String _snippet(String source, String query) {
    if (source.length <= 180 || query.trim().isEmpty) return source;
    final normalizedText = LibraryTextNormalizer.normalize(source);
    final normalizedQuery = LibraryTextNormalizer.normalize(query);
    final index = normalizedText.indexOf(normalizedQuery);
    if (index < 0) return '${source.substring(0, 180)}...';
    final start = (index - 60).clamp(0, source.length).toInt();
    final end = (index + normalizedQuery.length + 110)
        .clamp(start, source.length)
        .toInt();
    final prefix = start > 0 ? '...' : '';
    final suffix = end < source.length ? '...' : '';
    return '$prefix${source.substring(start, end)}$suffix';
  }
}
