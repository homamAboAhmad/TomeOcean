import 'package:golden_shamela/Helpers/StorageHelper.dart';
import 'package:golden_shamela/UI/Search/models/saved_search_scope.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class SavedSearchScopeStore {
  static const _storageKey = 'saved_search_scopes_v1';

  List<SavedSearchScope> loadScopes() {
    final rows = StorageHelper.getListOfMaps(_storageKey) ?? const [];
    return rows
        .map(SavedSearchScope.fromJson)
        .where((scope) => scope.id.isNotEmpty && scope.name.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<SavedSearchScope>> saveScope({
    required String name,
    required List<Map<String, dynamic>> items,
    required SearchStateSnapshot searchSnapshot,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || items.isEmpty) return loadScopes();

    final now = DateTime.now().millisecondsSinceEpoch;
    final nextScope = SavedSearchScope(
      id: now.toString(),
      name: trimmedName,
      items: _copyItems(items),
      createdAt: now,
      searchSnapshot: searchSnapshot,
    );

    final scopes = loadScopes()
      ..removeWhere((scope) => scope.name.trim() == trimmedName)
      ..insert(0, nextScope);
    await _persist(scopes);
    return scopes;
  }

  Future<List<SavedSearchScope>> deleteScope(String id) async {
    final scopes = loadScopes()..removeWhere((scope) => scope.id == id);
    await _persist(scopes);
    return scopes;
  }

  Future<void> _persist(List<SavedSearchScope> scopes) {
    return StorageHelper.saveListOfMaps(
      _storageKey,
      scopes.map((scope) => scope.toJson()).toList(),
    );
  }

  List<Map<String, dynamic>> _copyItems(List<Map<String, dynamic>> items) {
    return items.map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
