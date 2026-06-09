import 'package:flutter/material.dart';
import 'library_entities_table.dart';
import 'library_design_tokens.dart';
import 'library_search_field.dart';

class LibraryEntitiesFragment extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final List<LibraryEntityRow> rows;
  final String? selectedId;
  final String titleHeader;
  final String secondaryHeader;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelected;
  final VoidCallback? onTitleHeaderTap;
  final VoidCallback? onSecondaryHeaderTap;

  const LibraryEntitiesFragment({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.rows,
    required this.selectedId,
    required this.titleHeader,
    required this.secondaryHeader,
    required this.onSearchChanged,
    required this.onSelected,
    this.onTitleHeaderTap,
    this.onSecondaryHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: LibraryDesignTokens.toolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: LibraryDesignTokens.surface,
            border: const Border(
              bottom: BorderSide(color: LibraryDesignTokens.divider),
            ),
          ),
          child: LibrarySearchField(
            controller: searchController,
            hint: searchHint,
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: LibraryEntitiesTable(
            rows: rows,
            selectedId: selectedId,
            titleHeader: titleHeader,
            secondaryHeader: secondaryHeader,
            onSelected: onSelected,
            onTitleHeaderTap: onTitleHeaderTap,
            onSecondaryHeaderTap: onSecondaryHeaderTap,
          ),
        ),
      ],
    );
  }
}
