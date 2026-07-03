Set<String> searchScopeItemIds(
  List<Map<String, dynamic>> items, {
  required String type,
  required String key,
}) {
  return items
      .where((item) => item['type'] == type && item[key] != null)
      .map((item) => item[key].toString())
      .where((value) => value.isNotEmpty)
      .toSet();
}
