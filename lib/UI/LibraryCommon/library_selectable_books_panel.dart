import 'package:flutter/material.dart';
import 'library_book_item.dart';
import 'library_books_table.dart';
import 'library_selection_actions_bar.dart';

class LibrarySelectableBooksPanel extends StatelessWidget {
  final Widget? topBar;
  final List<LibraryBookItem> books;
  final Set<String> checkedPaths;
  final Set<String> highlightedPaths;
  final String? selectedPath;
  final ValueChanged<LibraryBookItem>? onSelected;
  final void Function(LibraryBookItem, bool) onCheckedChanged;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const LibrarySelectableBooksPanel({
    super.key,
    this.topBar,
    required this.books,
    required this.checkedPaths,
    required this.highlightedPaths,
    this.selectedPath,
    this.onSelected,
    required this.onCheckedChanged,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (topBar != null) topBar!,
        Expanded(
          child: LibraryBooksTable(
            books: books,
            selectedPath: selectedPath ??
                (checkedPaths.isEmpty ? null : checkedPaths.first),
            favoritePaths: const {},
            checkedPaths: checkedPaths,
            highlightedPaths: highlightedPaths,
            showCheckboxes: true,
            onSelected: onSelected ?? (_) {},
            onCheckedChanged: onCheckedChanged,
          ),
        ),
        LibrarySelectionActionsBar(
          hasSelection: checkedPaths.isNotEmpty,
          selectedCount: checkedPaths.length,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
      ],
    );
  }
}
