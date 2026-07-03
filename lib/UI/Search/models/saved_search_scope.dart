import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class SavedSearchScope {
  final String id;
  final String name;
  final List<Map<String, dynamic>> items;
  final int createdAt;
  final SearchStateSnapshot searchSnapshot;

  const SavedSearchScope({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.searchSnapshot = const SearchStateSnapshot(),
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => Map<String, dynamic>.from(item)).toList(),
      'createdAt': createdAt,
      'searchSnapshot': searchSnapshot.toJson(),
    };
  }

  factory SavedSearchScope.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return SavedSearchScope(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      items: rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      searchSnapshot: SearchStateSnapshot.fromJson(
        json['searchSnapshot'] is Map
            ? Map<String, dynamic>.from(json['searchSnapshot'] as Map)
            : null,
      ),
    );
  }
}
