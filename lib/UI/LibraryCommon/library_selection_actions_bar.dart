import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

class LibrarySelectionActionsBar extends StatelessWidget {
  final bool hasSelection;
  final int selectedCount;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const LibrarySelectionActionsBar({
    super.key,
    required this.hasSelection,
    this.selectedCount = 0,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            selectedCount == 0 ? 'لا توجد كتب محددة' : 'المحدد: $selectedCount',
          ),
          _button(
            enabled: hasSelection,
            onPressed: onAdd,
            icon: Icons.check_circle_outline,
            label: 'اختيار',
            color: Colors.green.shade700,
            borderColor: Colors.green.shade200,
          ),
          _button(
            enabled: hasSelection,
            onPressed: onRemove,
            icon: Icons.remove_circle_outline,
            label: 'إزالة',
            color: Colors.red.shade700,
            borderColor: Colors.red.shade200,
          ),
        ],
      ),
    );
  }

  Widget _button({
    required bool enabled,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: LibraryIcon.fromIcon(
        icon,
        size: 18,
        color: enabled ? color : color.withOpacity(0.35),
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: borderColor),
      ),
    );
  }
}
