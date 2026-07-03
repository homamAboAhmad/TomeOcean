String searchScopeItemKey(Map<String, dynamic> item) {
  final type = item['type'] as String? ?? '';
  return switch (type) {
    'book' => 'book:${item['bookPath'] ?? ''}',
    'author' => 'author:${item['authorId'] ?? ''}',
    'section' => 'section:${item['sectionId'] ?? ''}',
    'period' => 'period:${item['periodId'] ?? ''}',
    _ => '',
  };
}
