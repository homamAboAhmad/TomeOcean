/// Aggregates paragraph content into page-level content for search indexing
class PageContentAggregator {
  /// Aggregate all paragraphs of a page into a single text
  /// 
  /// Groups paragraphs by (book_path, page_number) and combines their content
  static String aggregatePageContent(List<Map<String, dynamic>> paragraphs) {
    if (paragraphs.isEmpty) return '';
    
    // Combine all paragraph contents with a space separator
    final contents = paragraphs
        .map((para) => para['content'] as String? ?? '')
        .where((content) => content.trim().isNotEmpty)
        .toList();
    
    return contents.join(' ');
  }

  /// Group paragraphs by page (book_path + page_number)
  static Map<String, List<Map<String, dynamic>>> groupByPage(
    List<Map<String, dynamic>> paragraphs,
  ) {
    final Map<String, List<Map<String, dynamic>>> pageGroups = {};
    
    for (var para in paragraphs) {
      final bookPath = para['book_path'] as String? ?? '';
      final pageNumber = para['page_number'] as int? ?? 0;
      final key = '$bookPath|$pageNumber';
      
      pageGroups.putIfAbsent(key, () => []).add(para);
    }
    
    return pageGroups;
  }

  /// Get page key from paragraph
  static String getPageKey(Map<String, dynamic> paragraph) {
    final bookPath = paragraph['book_path'] as String? ?? '';
    final pageNumber = paragraph['page_number'] as int? ?? 0;
    return '$bookPath|$pageNumber';
  }
}

