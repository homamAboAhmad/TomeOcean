import 'dart:convert';
import 'dart:io';

import 'package:golden_shamela/Helpers/StorageHelper.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';
import 'package:path/path.dart' as p;

class SavedSearchResultsStore {
  static const _storageKey = 'saved_search_results_v1';
  static const _resultsFolderName = 'saved_search_results';

  List<SavedSearchResultsRecord> loadResults() {
    final rows = StorageHelper.getListOfMaps(_storageKey) ?? const [];
    return rows
        .map(SavedSearchResultsRecord.fromJson)
        .where((item) =>
            item.id.isNotEmpty &&
            (item.resultsFileName.isNotEmpty || item.results.isNotEmpty))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  Future<List<SavedSearchResultsRecord>> saveResult(
    SavedSearchResultsRecord result,
  ) async {
    final trimmedName = result.name.trim();
    if (trimmedName.isEmpty || result.results.isEmpty) return loadResults();

    final results = loadResults()
      ..removeWhere((item) => item.name.trim() == trimmedName);
    await _deleteFilesForName(trimmedName);
    final nextOrder = _nextOrder(results);
    final fileName = await _writeResultsFile(result.id, result.results);
    results.insert(0, result.copyWith(
      orderIndex: nextOrder,
      results: const [],
      resultsFileName: fileName,
    ));
    await _persist(results);
    return results;
  }

  Future<SavedSearchResultsRecord> loadResultData(
    SavedSearchResultsRecord result,
  ) async {
    if (result.results.isNotEmpty || result.resultsFileName.isEmpty) {
      return result;
    }
    final file = _resultsFile(result.resultsFileName);
    if (!await file.exists()) return result;
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    final rows = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return result.copyWith(results: rows);
  }

  Future<List<SavedSearchResultsRecord>> renameResult(
    String id,
    String name,
  ) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return loadResults();

    final results = loadResults();
    final duplicates = results.where(
      (item) => item.id != id && item.name.trim() == trimmedName,
    );
    for (final item in duplicates) {
      await _deleteResultsFile(item.resultsFileName);
    }
    results.removeWhere(
      (item) => item.id != id && item.name.trim() == trimmedName,
    );
    final index = results.indexWhere((item) => item.id == id);
    if (index == -1) return results;

    results[index] = results[index].copyWith(name: trimmedName);
    await _persist(results);
    return results;
  }

  Future<List<SavedSearchResultsRecord>> deleteResult(String id) async {
    final results = loadResults();
    final removed = results.where((item) => item.id == id).toList();
    for (final item in removed) {
      await _deleteResultsFile(item.resultsFileName);
    }
    results.removeWhere((item) => item.id == id);
    await _persist(results);
    return results;
  }

  Future<List<SavedSearchResultsRecord>> moveResult(
    String id,
    int direction,
  ) async {
    final results = loadResults();
    final index = results.indexWhere((item) => item.id == id);
    final newIndex = index + direction;
    if (index == -1 || newIndex < 0 || newIndex >= results.length) {
      return results;
    }

    final item = results.removeAt(index);
    results.insert(newIndex, item);
    final reordered = [
      for (var i = 0; i < results.length; i++)
        results[i].copyWith(orderIndex: i),
    ];
    await _persist(reordered);
    return reordered;
  }

  Future<void> _persist(List<SavedSearchResultsRecord> results) {
    return StorageHelper.saveListOfMaps(
      _storageKey,
      results.map((item) => item.toJson()).toList(),
    );
  }

  int _nextOrder(List<SavedSearchResultsRecord> results) {
    if (results.isEmpty) return 0;
    final minOrder = results
        .map((item) => item.orderIndex)
        .reduce((value, next) => value < next ? value : next);
    return minOrder - 1;
  }

  Future<String> _writeResultsFile(
    String id,
    List<Map<String, dynamic>> rows,
  ) async {
    await AppStoragePaths.ensureBaseDirectories();
    final dir = Directory(p.join(
      AppStoragePaths.systemStorePath,
      _resultsFolderName,
    ));
    await dir.create(recursive: true);
    final fileName = '${id}_results.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonEncode(rows));
    return fileName;
  }

  File _resultsFile(String fileName) {
    return File(p.join(
      AppStoragePaths.systemStorePath,
      _resultsFolderName,
      fileName,
    ));
  }

  Future<void> _deleteResultsFile(String fileName) async {
    if (fileName.isEmpty) return;
    final file = _resultsFile(fileName);
    if (await file.exists()) await file.delete();
  }

  Future<void> _deleteFilesForName(String name) async {
    final removed = loadResults().where((item) => item.name.trim() == name);
    for (final item in removed) {
      await _deleteResultsFile(item.resultsFileName);
    }
  }
}
