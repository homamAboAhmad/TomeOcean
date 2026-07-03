import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class SavedSearchResultsRecord {
  final String id;
  final String name;
  final int createdAt;
  final int orderIndex;
  final List<Map<String, dynamic>> results;
  final String resultsFileName;
  final int totalCount;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final SearchStateSnapshot searchSnapshot;

  const SavedSearchResultsRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.orderIndex,
    required this.results,
    this.resultsFileName = '',
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.searchSnapshot = const SearchStateSnapshot(),
  });

  SavedSearchResultsRecord copyWith({
    String? name,
    int? orderIndex,
    List<Map<String, dynamic>>? results,
    String? resultsFileName,
  }) {
    return SavedSearchResultsRecord(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
      results: results ?? this.results,
      resultsFileName: resultsFileName ?? this.resultsFileName,
      totalCount: totalCount,
      searchQueries: searchQueries,
      morphologicalSearch: morphologicalSearch,
      searchSnapshot: searchSnapshot,
    );
  }

  factory SavedSearchResultsRecord.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List? ?? const [];
    final rawQueries = json['searchQueries'] as List? ?? const [];
    return SavedSearchResultsRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      resultsFileName: json['resultsFileName'] as String? ?? '',
      results: rawResults
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      searchQueries: rawQueries.map((item) => item.toString()).toList(),
      morphologicalSearch: json['morphologicalSearch'] == true,
      searchSnapshot: SearchStateSnapshot.fromJson(
        json['searchSnapshot'] is Map
            ? Map<String, dynamic>.from(json['searchSnapshot'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'orderIndex': orderIndex,
      if (resultsFileName.isEmpty)
        'results': results.map((row) => Map<String, dynamic>.from(row)).toList(),
      if (resultsFileName.isNotEmpty) 'resultsFileName': resultsFileName,
      'totalCount': totalCount,
      'searchQueries': List<String>.from(searchQueries),
      'morphologicalSearch': morphologicalSearch,
      'searchSnapshot': searchSnapshot.toJson(),
    };
  }
}
