import 'package:golden_shamela/Helpers/StorageHelper.dart';
import 'package:golden_shamela/UI/Search/models/search_history_record.dart';

class SearchHistoryStore {
  static const _storageKey = 'shamela_search_history_v1';
  static const _maxRecords = 100;

  List<SearchHistoryRecord> loadRecords() {
    final rows = StorageHelper.getListOfMaps(_storageKey) ?? const [];
    return rows
        .map(SearchHistoryRecord.fromJson)
        .where((record) => record.id.isNotEmpty && record.queries.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<SearchHistoryRecord>> saveRecord(
    SearchHistoryRecord record,
  ) async {
    if (record.queries.isEmpty) return loadRecords();
    final records = loadRecords()
      ..removeWhere((oldRecord) => _sameSearch(oldRecord, record))
      ..insert(0, record);
    final trimmed = records.take(_maxRecords).toList();
    await _persist(trimmed);
    return trimmed;
  }

  Future<List<SearchHistoryRecord>> deleteRecord(String id) async {
    final records = loadRecords()..removeWhere((record) => record.id == id);
    await _persist(records);
    return records;
  }

  Future<void> _persist(List<SearchHistoryRecord> records) {
    return StorageHelper.saveListOfMaps(
      _storageKey,
      records.map((record) => record.toJson()).toList(),
    );
  }

  bool _sameSearch(SearchHistoryRecord left, SearchHistoryRecord right) {
    return left.title == right.title &&
        left.searchGrouping == right.searchGrouping &&
        left.scopeItems.toString() == right.scopeItems.toString() &&
        left.searchSections.toString() == right.searchSections.toString() &&
        left.options.toString() == right.options.toString();
  }
}
