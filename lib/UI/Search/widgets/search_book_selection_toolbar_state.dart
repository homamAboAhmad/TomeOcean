import 'package:flutter/material.dart';

typedef SearchBookSelectionStateChanged = void Function({
  required List<String> visibleBookPaths,
  required Set<String> checkedBookPaths,
  required VoidCallback onToggleAll,
});
