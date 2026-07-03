import 'dart:convert';
import 'dart:io';

import 'package:golden_shamela/Helpers/ShamelaSearchEngine.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';

class SearchResultSectionTitleResolver {
  final Map<String, Future<String?>> _cache = {};
  final Map<String, Future<List<_IndexTitle>>> _indexCache = {};

  SearchResultSectionTitleResolver(ShamelaSearchEngine _);

  Future<String?> resolve(String bookPath, int pageNumber) {
    final key = '$bookPath|$pageNumber';
    return _cache.putIfAbsent(
      key,
      () async {
        final index = await _indexForBook(bookPath).catchError(
          (_) => const <_IndexTitle>[],
        );
        return _nearestTitle(index, pageNumber);
      },
    );
  }

  String? _nearestTitle(List<_IndexTitle> index, int pageNumber) {
    if (index.isEmpty) return null;

    var low = 0;
    var high = index.length - 1;
    _IndexTitle? match;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final item = index[middle];
      if (item.page <= pageNumber) {
        match = item;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    return match?.title;
  }

  Future<List<_IndexTitle>> _indexForBook(String bookPath) {
    return _indexCache.putIfAbsent(bookPath, () async {
      final bookId = AppStoragePaths.bookIdFromPath(bookPath);
      final metadata = File(AppStoragePaths.bookMetadataPath(bookId));
      if (!await metadata.exists()) return const [];

      final json = jsonDecode(await metadata.readAsString())
          as Map<String, dynamic>;
      final rawIndex = json['index'];
      if (rawIndex is! List) return const [];

      final items = <_IndexTitle>[];
      for (final raw in rawIndex) {
        if (raw is! Map) continue;
        final title = raw['title']?.toString().trim() ?? '';
        final page = _asInt(raw['page']);
        if (title.isNotEmpty && page != null) {
          items.add(_IndexTitle(title: title, page: page));
        }
      }
      items.sort((a, b) => a.page.compareTo(b.page));
      return items;
    });
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _IndexTitle {
  final String title;
  final int page;

  const _IndexTitle({required this.title, required this.page});
}
