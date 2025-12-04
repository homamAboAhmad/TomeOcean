/// Class to represent a single search results tab
class SearchResultsTab {
  final String id;
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final String searchQueryString;

  SearchResultsTab({
    required this.id,
    required this.results,
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
  }) : searchQueryString = searchQueries.join(' | ');

  String get title => 'بحث عن: $searchQueryString';
}

