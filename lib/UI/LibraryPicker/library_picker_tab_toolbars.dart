import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_type_filter_group.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';

class LibrarySectionsToolbar extends StatelessWidget {
  final Set<String> selectedTypes;
  final bool includeMatchingPrinted;
  final bool includeNotMatchingPrinted;
  final ValueChanged<String> onTypeToggled;
  final void Function(List<String> types, bool selected) onGroupChanged;
  final ValueChanged<bool> onMatchingPrintedChanged;
  final ValueChanged<bool> onNotMatchingPrintedChanged;

  const LibrarySectionsToolbar({
    super.key,
    required this.selectedTypes,
    required this.includeMatchingPrinted,
    required this.includeNotMatchingPrinted,
    required this.onTypeToggled,
    required this.onGroupChanged,
    required this.onMatchingPrintedChanged,
    required this.onNotMatchingPrintedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: LibraryDesignTokens.surface,
        border: const Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              flex: 6,
              child: LibraryTypeFilterGroup(
              label: 'المطبوعات',
              types: BookMetadataOptions.printedTypes,
              selectedTypes: selectedTypes,
              onGroupChanged: (selected) {
                onGroupChanged(BookMetadataOptions.printedTypes, selected);
              },
              onTypeToggled: onTypeToggled,
              trailingChecks: [
                _CheckFilter(
                  label: 'يوافق المطبوع',
                  value: includeMatchingPrinted,
                  onChanged: onMatchingPrintedChanged,
                ),
                _CheckFilter(
                  label: 'لا يوافق المطبوع',
                  value: includeNotMatchingPrinted,
                  onChanged: onNotMatchingPrintedChanged,
                ),
              ],
            ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: LibraryTypeFilterGroup(
              label: 'غير المطبوعات',
              types: BookMetadataOptions.unprintedTypes,
              selectedTypes: selectedTypes,
              onGroupChanged: (selected) {
                onGroupChanged(BookMetadataOptions.unprintedTypes, selected);
              },
              onTypeToggled: onTypeToggled,
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckFilter extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: (next) => onChanged(next ?? false),
          ),
          Text(label),
        ],
      ),
    );
  }
}
