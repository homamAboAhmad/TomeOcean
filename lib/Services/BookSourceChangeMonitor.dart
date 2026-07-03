import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Services/BookSourceFingerprint.dart';

class BookSourceChangeMonitor {
  const BookSourceChangeMonitor._();

  static const _watchInterval = Duration(seconds: 5);
  static const _saveSettleDelay = Duration(seconds: 10);

  static final _active = <String>{};
  static final _watchers = <String, Timer>{};
  static final _debounce = <String, Timer>{};
  static final _debounceFingerprints = <String, String?>{};
  static final _oneShotCallbackKeys = <String, Set<Object>>{};
  static final _completionCallbacks =
      <String, Map<Object, FutureOr<void> Function()>>{};
  static bool _scanning = false;

  static Future<void> runBackgroundCheck() async {
    if (_scanning) return;
    _scanning = true;
    try {
      final db = BooksMetadataDatabase();
      await db.initialize();
      final database = await db.database;
      final rows = await database.query('books', columns: _bookColumns);
      for (final row in rows) {
        await _checkRow(row);
      }
    } catch (e) {
      debugPrint('BookSourceChangeMonitor: scan failed: $e');
    } finally {
      _scanning = false;
    }
  }

  static void watchBook(String bookPath) {
    _watchers[bookPath]?.cancel();
    unawaited(_checkPath(bookPath));
    // ponytail: poll only opened books; use persistent watchers if external edits become common.
    _watchers[bookPath] = Timer.periodic(_watchInterval, (_) => _checkPath(bookPath));
  }

  static void scheduleReprocess(
    String bookPath, {
    FutureOr<void> Function()? onCompleted,
    String? fingerprint,
  }) {
    final tempCallbackKey = Object();
    if (onCompleted != null) {
      registerCompletionCallback(bookPath, tempCallbackKey, onCompleted);
      _oneShotCallbackKeys
          .putIfAbsent(bookPath, () => <Object>{})
          .add(tempCallbackKey);
    }
    if (_debounce[bookPath]?.isActive == true &&
        _debounceFingerprints[bookPath] == fingerprint) {
      return;
    }
    _debounce[bookPath]?.cancel();
    _debounceFingerprints[bookPath] = fingerprint;
    late Timer timer;
    timer = Timer(
      _saveSettleDelay,
      () async {
        try {
          final completed = await _reprocessIfStillChanged(bookPath);
          if (!completed) return;
          final callbacks = List<FutureOr<void> Function()>.from(
            _completionCallbacks[bookPath]?.values ?? const [],
          );
          for (final callback in callbacks) {
            try {
              await callback();
            } catch (e) {
              debugPrint('BookSourceChangeMonitor: completion callback failed: $e');
            }
          }
        } finally {
          final oneShotKeys = _oneShotCallbackKeys.remove(bookPath);
          if (oneShotKeys != null) {
            for (final key in oneShotKeys) {
              unregisterCompletionCallback(bookPath, key);
            }
          }
          if (_debounce[bookPath] == timer) {
            _debounce.remove(bookPath);
            _debounceFingerprints.remove(bookPath);
          }
        }
      },
    );
    _debounce[bookPath] = timer;
  }

  static void registerCompletionCallback(
    String bookPath,
    Object owner,
    FutureOr<void> Function() onCompleted,
  ) {
    _completionCallbacks
        .putIfAbsent(bookPath, () => <Object, FutureOr<void> Function()>{})
        [owner] = onCompleted;
  }

  static void unregisterCompletionCallback(String bookPath, Object owner) {
    final callbacks = _completionCallbacks[bookPath];
    callbacks?.remove(owner);
    if (callbacks != null && callbacks.isEmpty) {
      _completionCallbacks.remove(bookPath);
    }
  }

  static Future<void> _checkPath(String bookPath) async {
    try {
      final db = BooksMetadataDatabase();
      final database = await db.database;
      final rows = await database.query(
        'books',
        columns: _bookColumns,
        where: 'book_path = ?',
        whereArgs: [bookPath],
        limit: 1,
      );
      if (rows.isNotEmpty) await _checkRow(rows.first);
    } catch (e) {
      debugPrint('BookSourceChangeMonitor: watch failed: $e');
    }
  }

  static Future<void> _checkRow(Map<String, Object?> row) async {
    final path = row['book_path']?.toString();
    if (path == null || path.isEmpty) return;

    final current = await BookSourceFingerprint.fromFile(path);
    if (current == null) return;

    final saved = row['source_hash']?.toString();
    if (saved == null || saved.isEmpty) {
      await _saveFingerprint(path, current);
      return;
    }
    if (saved == current) return;

    scheduleReprocess(path, fingerprint: current);
  }

  static Future<bool> _reprocessIfStillChanged(String path) async {
    if (_active.contains(path)) return false;
    _active.add(path);
    try {
      final db = BooksMetadataDatabase();
      final database = await db.database;
      final rows = await database.query(
        'books',
        columns: _bookColumns,
        where: 'book_path = ?',
        whereArgs: [path],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final row = rows.first;
      final current = await BookSourceFingerprint.fromFile(path);
      if (current == null || current == row['source_hash']?.toString()) {
        return false;
      }

      final service = BookProcessingService();
      if (service.activeTasksNotifier.value.isEmpty) {
        service.startBatch([path]);
      }
      await service.processBook(path, bookCard: BookCard.fromDatabaseRow(row))
          .drain<void>();
      return true;
    } catch (e) {
      debugPrint('BookSourceChangeMonitor: reprocess failed: $e');
      return false;
    } finally {
      _active.remove(path);
    }
  }

  static Future<void> _saveFingerprint(String path, String fingerprint) async {
    final db = BooksMetadataDatabase();
    final database = await db.database;
    await database.update(
      'books',
      {'source_hash': fingerprint},
      where: 'book_path = ?',
      whereArgs: [path],
    );
  }

  static Future<void> markCurrentFingerprint(String path) async {
    final fingerprint = await BookSourceFingerprint.fromFile(path);
    if (fingerprint != null) await _saveFingerprint(path, fingerprint);
  }

  static const _bookColumns = [
    'id',
    'book_path',
    'book_name',
    'author_id',
    'section_id',
    'description',
    'book_type',
    'matches_printed',
    'publisher',
    'edition',
    'page_count',
    'source_hash',
  ];
}
