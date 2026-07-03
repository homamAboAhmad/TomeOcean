import 'dart:convert';
import 'dart:io';

import 'package:golden_shamela/Helpers/StorageHelper.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/OpenTabsStore.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';
import 'package:path/path.dart' as p;

class WorkSessionStore {
  static const _previousKey = 'previous_work_sessions_v1';
  static const _savedKey = 'saved_work_sessions_v1';
  static const _maxPreviousSessions = 50;
  static const _searchTabsFolderName = 'saved_work_session_search_tabs';

  List<WorkSessionRecord> loadPreviousSessions() {
    return _load(_previousKey);
  }

  List<WorkSessionRecord> loadSavedSessions() {
    return _load(_savedKey);
  }

  Future<List<WorkSessionRecord>> archivePreviousOpenTabs(
    List<OpenTabRecord> records,
  ) async {
    final validRecords = records.where((record) => record.bookPath.isNotEmpty);
    if (validRecords.isEmpty) return loadPreviousSessions();

    final sessions = loadPreviousSessions();
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = WorkSessionRecord.previousFromOpenTabs(
      validRecords.toList(growable: false),
      now,
    );
    if (sessions.isNotEmpty && sessions.first.signature() == next.signature()) {
      return sessions;
    }

    final updated = [next, ...sessions].take(_maxPreviousSessions).toList();
    await _persist(_previousKey, updated);
    return updated;
  }

  Future<List<WorkSessionRecord>> clearPreviousSessions() async {
    await StorageHelper.removeKey(_previousKey);
    return const [];
  }

  Future<List<WorkSessionRecord>> deletePreviousSession(String id) {
    return _delete(_previousKey, id);
  }

  Future<List<WorkSessionRecord>> saveSession(WorkSessionRecord session) async {
    final trimmedName = session.name.trim();
    if (trimmedName.isEmpty || session.tabCount == 0) return loadSavedSessions();

    final sessions = loadSavedSessions();
    final replaced = sessions.where((item) => item.name.trim() == trimmedName);
    for (final item in replaced) {
      await _deleteSearchTabFiles(item);
    }
    sessions.removeWhere((item) => item.name.trim() == trimmedName);
    final nextOrder = _nextOrder(sessions);
    final saved = await _externalizeSearchTabs(
      session.copyWith(orderIndex: nextOrder),
    );
    sessions.insert(0, saved);
    await _persist(_savedKey, sessions);
    return sessions;
  }

  Future<WorkSessionSearchRecord> loadSearchTabResults(
    WorkSessionSearchRecord tab,
  ) async {
    if (tab.results.isNotEmpty || tab.resultsFileName.isEmpty) return tab;
    final file = _searchTabFile(tab.resultsFileName);
    if (!await file.exists()) return tab;
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    final rows = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return tab.copyWith(results: rows);
  }

  Future<List<WorkSessionRecord>> renameSavedSession(
    String id,
    String name,
  ) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return loadSavedSessions();

    final sessions = loadSavedSessions();
    final duplicates = sessions.where(
      (item) => item.id != id && item.name.trim() == trimmedName,
    );
    for (final item in duplicates) {
      await _deleteSearchTabFiles(item);
    }
    sessions.removeWhere(
      (item) => item.id != id && item.name.trim() == trimmedName,
    );
    final index = sessions.indexWhere((item) => item.id == id);
    if (index == -1) return sessions;

    sessions[index] = sessions[index].copyWith(name: trimmedName);
    await _persist(_savedKey, sessions);
    return sessions;
  }

  Future<List<WorkSessionRecord>> deleteSavedSession(String id) {
    return _deleteSavedSession(id);
  }

  Future<List<WorkSessionRecord>> moveSavedSession(
    String id,
    int direction,
  ) async {
    final sessions = loadSavedSessions();
    final index = sessions.indexWhere((item) => item.id == id);
    final newIndex = index + direction;
    if (index == -1 || newIndex < 0 || newIndex >= sessions.length) {
      return sessions;
    }

    final item = sessions.removeAt(index);
    sessions.insert(newIndex, item);
    final reordered = _withOrderIndexes(sessions);
    await _persist(_savedKey, reordered);
    return reordered;
  }

  List<WorkSessionRecord> _load(String key) {
    final rows = StorageHelper.getListOfMaps(key) ?? const [];
    return rows
        .map(WorkSessionRecord.fromJson)
        .where((session) => session.id.isNotEmpty && session.tabCount > 0)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  Future<List<WorkSessionRecord>> _delete(String key, String id) async {
    final sessions = _load(key)..removeWhere((item) => item.id == id);
    await _persist(key, sessions);
    return sessions;
  }

  Future<List<WorkSessionRecord>> _deleteSavedSession(String id) async {
    final sessions = _load(_savedKey);
    final removed = sessions.where((item) => item.id == id);
    for (final session in removed) {
      await _deleteSearchTabFiles(session);
    }
    sessions.removeWhere((item) => item.id == id);
    await _persist(_savedKey, sessions);
    return sessions;
  }

  Future<void> _persist(String key, List<WorkSessionRecord> sessions) {
    return StorageHelper.saveListOfMaps(
      key,
      sessions.map((session) => session.toJson()).toList(),
    );
  }

  int _nextOrder(List<WorkSessionRecord> sessions) {
    if (sessions.isEmpty) return 0;
    final minOrder = sessions
        .map((session) => session.orderIndex)
        .reduce((value, next) => value < next ? value : next);
    return minOrder - 1;
  }

  List<WorkSessionRecord> _withOrderIndexes(List<WorkSessionRecord> sessions) {
    return [
      for (var i = 0; i < sessions.length; i++)
        sessions[i].copyWith(orderIndex: i),
    ];
  }

  Future<WorkSessionRecord> _externalizeSearchTabs(
    WorkSessionRecord session,
  ) async {
    if (session.searchTabs.every((tab) => tab.results.isEmpty)) {
      return session;
    }
    await AppStoragePaths.ensureBaseDirectories();
    final dir = Directory(p.join(
      AppStoragePaths.systemStorePath,
      _searchTabsFolderName,
    ));
    await dir.create(recursive: true);

    final tabs = <WorkSessionSearchRecord>[];
    for (var i = 0; i < session.searchTabs.length; i++) {
      final tab = session.searchTabs[i];
      if (tab.results.isEmpty || tab.resultsFileName.isNotEmpty) {
        tabs.add(tab);
        continue;
      }
      final fileName = '${session.id}_search_$i.json';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(jsonEncode(tab.results));
      tabs.add(tab.copyWith(results: const [], resultsFileName: fileName));
    }

    return WorkSessionRecord(
      id: session.id,
      name: session.name,
      createdAt: session.createdAt,
      orderIndex: session.orderIndex,
      kind: session.kind,
      selectedIndex: session.selectedIndex,
      books: session.books,
      searchTabs: tabs,
    );
  }

  File _searchTabFile(String fileName) {
    return File(p.join(
      AppStoragePaths.systemStorePath,
      _searchTabsFolderName,
      fileName,
    ));
  }

  Future<void> _deleteSearchTabFiles(WorkSessionRecord session) async {
    for (final tab in session.searchTabs) {
      if (tab.resultsFileName.isEmpty) continue;
      final file = _searchTabFile(tab.resultsFileName);
      if (await file.exists()) await file.delete();
    }
  }
}
