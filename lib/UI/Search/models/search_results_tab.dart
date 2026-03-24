/// Class to represent a single search results tab
class SearchResultsTab {
  final String id;
  List<Map<String, dynamic>> results;
  int totalCount;
  List<String> searchQueries;
  bool morphologicalSearch;
  bool isSearching;
  bool cancelled;

  SearchResultsTab({
    required this.id,
    required this.results,
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.isSearching = true,
    this.cancelled = false,
  });

  String get searchQueryString => searchQueries.join(' | ');

  String get title => 'بحث عن: $searchQueryString';
}

