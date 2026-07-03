import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_models.dart';

class LibraryDataSectionTabs extends StatelessWidget {
  final LibraryDataSection section;
  final ValueChanged<LibraryDataSection> onSelected;

  const LibraryDataSectionTabs({
    super.key,
    required this.section,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: LibraryDesignTokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        textDirection: TextDirection.rtl,
        children: LibraryDataSection.values.map(_tab).toList(),
      ),
    );
  }

  Widget _tab(LibraryDataSection item) {
    final selected = item == section;
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: InkWell(
          onTap: () => onSelected(item),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? LibraryDesignTokens.selected : Colors.white,
              border: Border.all(
                color: selected
                    ? LibraryDesignTokens.selectedBorder
                    : LibraryDesignTokens.divider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LibraryIcon.fromIcon(
                  item.icon,
                  size: 17,
                  color: LibraryDesignTokens.primary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
