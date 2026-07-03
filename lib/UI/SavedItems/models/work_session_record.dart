import 'package:golden_shamela/Services/OpenTabsStore.dart';
import 'package:golden_shamela/UI/Search/models/search_results_tab.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class WorkSessionBookRecord {
  final String bookPath;
  final int pageIndex;
  final String source;
  final String title;

  const WorkSessionBookRecord({
    required this.bookPath,
    required this.pageIndex,
    required this.source,
    this.title = '',
  });

  factory WorkSessionBookRecord.fromOpenTab(OpenTabRecord record) {
    return WorkSessionBookRecord(
      bookPath: record.bookPath,
      pageIndex: record.pageIndex,
      source: record.source,
    );
  }

  factory WorkSessionBookRecord.fromJson(Map<String, dynamic> json) {
    return WorkSessionBookRecord(
      bookPath: json['bookPath'] as String? ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookPath': bookPath,
      'pageIndex': pageIndex,
      'source': source,
      'title': title,
    };
  }
}

class WorkSessionSearchRecord {
  final String title;
  final List<Map<String, dynamic>> results;
  final String resultsFileName;
  final int totalCount;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final SearchStateSnapshot searchSnapshot;

  const WorkSessionSearchRecord({
    required this.title,
    required this.results,
    this.resultsFileName = '',
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.searchSnapshot = const SearchStateSnapshot(),
  });

  factory WorkSessionSearchRecord.fromTab(SearchResultsTab tab) {
    return WorkSessionSearchRecord(
      title: tab.title,
      results: _copyRows(tab.results),
      totalCount: tab.totalCount,
      searchQueries: List<String>.from(tab.searchQueries),
      morphologicalSearch: tab.morphologicalSearch,
      searchSnapshot: tab.searchSnapshot,
    );
  }

  WorkSessionSearchRecord copyWith({
    List<Map<String, dynamic>>? results,
    String? resultsFileName,
  }) {
    return WorkSessionSearchRecord(
      title: title,
      results: results ?? this.results,
      resultsFileName: resultsFileName ?? this.resultsFileName,
      totalCount: totalCount,
      searchQueries: searchQueries,
      morphologicalSearch: morphologicalSearch,
      searchSnapshot: searchSnapshot,
    );
  }

  factory WorkSessionSearchRecord.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List? ?? const [];
    final rawQueries = json['searchQueries'] as List? ?? const [];
    return WorkSessionSearchRecord(
      title: json['title'] as String? ?? '',
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
      'title': title,
      if (resultsFileName.isEmpty) 'results': _copyRows(results),
      if (resultsFileName.isNotEmpty) 'resultsFileName': resultsFileName,
      'totalCount': totalCount,
      'searchQueries': List<String>.from(searchQueries),
      'morphologicalSearch': morphologicalSearch,
      'searchSnapshot': searchSnapshot.toJson(),
    };
  }

  static List<Map<String, dynamic>> _copyRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

class WorkSessionRecord {
  static const previousKind = 'previous';
  static const savedKind = 'saved';

  final String id;
  final String name;
  final int createdAt;
  final int orderIndex;
  final String kind;
  final int selectedIndex;
  final List<WorkSessionBookRecord> books;
  final List<WorkSessionSearchRecord> searchTabs;

  const WorkSessionRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.orderIndex,
    required this.kind,
    required this.selectedIndex,
    required this.books,
    required this.searchTabs,
  });

  int get tabCount => books.length + searchTabs.length;

  WorkSessionRecord copyWith({
    String? name,
    int? orderIndex,
  }) {
    return WorkSessionRecord(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
      kind: kind,
      selectedIndex: selectedIndex,
      books: books,
      searchTabs: searchTabs,
    );
  }

  factory WorkSessionRecord.previousFromOpenTabs(
    List<OpenTabRecord> records,
    int createdAt,
  ) {
    return WorkSessionRecord(
      id: createdAt.toString(),
      name: _previousName(createdAt),
      createdAt: createdAt,
      orderIndex: -createdAt,
      kind: previousKind,
      selectedIndex: 0,
      books: records.map(WorkSessionBookRecord.fromOpenTab).toList(),
      searchTabs: const [],
    );
  }

  factory WorkSessionRecord.fromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'] as List? ?? const [];
    final rawSearchTabs = json['searchTabs'] as List? ?? const [];
    return WorkSessionRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? savedKind,
      selectedIndex: (json['selectedIndex'] as num?)?.toInt() ?? 0,
      books: rawBooks
          .whereType<Map>()
          .map((item) => WorkSessionBookRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((book) => book.bookPath.isNotEmpty)
          .toList(),
      searchTabs: rawSearchTabs
          .whereType<Map>()
          .map((item) => WorkSessionSearchRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'orderIndex': orderIndex,
      'kind': kind,
      'selectedIndex': selectedIndex,
      'books': books.map((book) => book.toJson()).toList(),
      'searchTabs': searchTabs.map((tab) => tab.toJson()).toList(),
    };
  }

  String signature() {
    final bookPart = books
        .map((book) => '${book.source}|${book.bookPath}|${book.pageIndex}')
        .join(';');
    final searchPart = searchTabs
        .map((tab) => '${tab.searchQueries.join('|')}|${tab.totalCount}')
        .join(';');
    return '$bookPart#$searchPart';
  }

  static String _previousName(int createdAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'جلسة $day/$month $hour:$minute';
  }
}
