import 'package:flutter/foundation.dart';

class DebugLogEntry {
  final String source;
  final String message;
  final DateTime timestamp;

  DebugLogEntry({
    required this.source,
    required this.message,
    required this.timestamp,
  });
}

/// خدمة مركزية لتجميع رسائل Debug الخام من pageRender
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  static const int _maxEntries = 2000;

  final ValueNotifier<List<DebugLogEntry>> logsNotifier = ValueNotifier([]);

  void log(String source, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final entry = DebugLogEntry(
      source: source,
      message: trimmed,
      timestamp: DateTime.now(),
    );

    final current = List<DebugLogEntry>.from(logsNotifier.value)..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    logsNotifier.value = current;
  }

  void clear() => logsNotifier.value = [];
}
