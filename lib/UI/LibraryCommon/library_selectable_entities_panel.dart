import 'package:flutter/material.dart';
import 'library_entities_table.dart';
import 'library_selection_actions_bar.dart';

class LibrarySelectableEntitiesPanel extends StatelessWidget {
  final List<LibraryEntityRow> rows;
  final String? selectedId;
  final Set<String> checkedIds;
  final Set<String> highlightedIds;
  final String titleHeader;
  final String secondaryHeader;
  final bool showCountColumn;
  final ValueChanged<String> onSelected;
  final void Function(String, bool) onCheckedChanged;
  final VoidCallback onToggleAll;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const LibrarySelectableEntitiesPanel({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.checkedIds,
    required this.highlightedIds,
    required this.titleHeader,
    required this.secondaryHeader,
    this.showCountColumn = true,
    required this.onSelected,
    required this.onCheckedChanged,
    required this.onToggleAll,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LibraryEntitiesTable(
            rows: rows,
            selectedId: selectedId,
            checkedIds: checkedIds,
            highlightedIds: highlightedIds,
            showCheckboxes: true,
            showCountColumn: showCountColumn,
            titleHeader: titleHeader,
            secondaryHeader: secondaryHeader,
            onSelected: onSelected,
            onCheckedChanged: onCheckedChanged,
            onToggleAll: onToggleAll,
          ),
        ),
        LibrarySelectionActionsBar(
          hasSelection: checkedIds.isNotEmpty,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
      ],
    );
  }
}
