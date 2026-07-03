import 'package:golden_shamela/UI/Search/helpers/search_scope_item_ids.dart';
import 'package:golden_shamela/UI/Search/helpers/search_scope_item_key.dart';

class SearchScopeItemsMergeResult {
  final List<Map<String, dynamic>> items;
  final Set<String> authorIds;
  final Set<String> sectionIds;

  const SearchScopeItemsMergeResult({
    required this.items,
    required this.authorIds,
    required this.sectionIds,
  });
}

abstract final class SearchScopeItemsMerger {
  static SearchScopeItemsMergeResult merge({
    required List<Map<String, dynamic>> currentItems,
    required List<Map<String, dynamic>> incomingItems,
  }) {
    final mergedItems = currentItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final existingKeys = mergedItems.map(searchScopeItemKey).toSet();

    for (final item in incomingItems) {
      final itemCopy = Map<String, dynamic>.from(item);
      final key = searchScopeItemKey(itemCopy);
      if (key.isEmpty || existingKeys.contains(key)) continue;
      mergedItems.add(itemCopy);
      existingKeys.add(key);
    }

    return SearchScopeItemsMergeResult(
      items: mergedItems,
      authorIds: searchScopeItemIds(
        mergedItems,
        type: 'author',
        key: 'authorId',
      ),
      sectionIds: searchScopeItemIds(
        mergedItems,
        type: 'section',
        key: 'sectionId',
      ),
    );
  }
}
