import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';

class LibraryTypeFilterGroup extends StatelessWidget {
  final String label;
  final List<String> types;
  final Set<String> selectedTypes;
  final ValueChanged<bool> onGroupChanged;
  final ValueChanged<String> onTypeToggled;
  final List<Widget> trailingChecks;

  const LibraryTypeFilterGroup({
    super.key,
    required this.label,
    required this.types,
    required this.selectedTypes,
    required this.onGroupChanged,
    required this.onTypeToggled,
    this.trailingChecks = const [],
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = types.where(selectedTypes.contains).length;
    final bool? groupValue = selectedCount == 0
        ? false
        : selectedCount == types.length
        ? true
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      decoration: BoxDecoration(
        border: Border.all(color: LibraryDesignTokens.handle),
        color: const Color(0xFFFAFAFA),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Transform.translate(
              offset: const Offset(0, -2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(label),
                  Checkbox(
                    tristate: true,
                    value: groupValue,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => onGroupChanged(groupValue != true),
                  ),
                ],
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                ...types.map(
                  (type) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _TypeChip(
                      selected: selectedTypes.contains(type),
                      label: BookMetadataOptions.typeLabel(type),
                      icon: _typeIcon(type),
                      onTap: () => onTypeToggled(type),
                    ),
                  ),
                ),
                ...trailingChecks.map(
                  (check) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: check,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case BookMetadataOptions.magazine:
        return Icons.menu_book_outlined;
      case BookMetadataOptions.manuscript:
        return Icons.history_edu;
      case BookMetadataOptions.thesis:
        return Icons.school_outlined;
      case BookMetadataOptions.electronic:
        return Icons.storage_outlined;
      case BookMetadataOptions.transcription:
        return Icons.album_outlined;
      default:
        return Icons.book_outlined;
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected ? LibraryDesignTokens.chipSelected : Colors.white,
          border: Border.all(
            color: selected
                ? LibraryDesignTokens.chipBorder
                : LibraryDesignTokens.divider,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: LibraryDesignTokens.icon),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}
