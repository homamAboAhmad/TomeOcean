import 'package:flutter/material.dart';
import 'library_book_item.dart';
import 'library_books_table.dart';
import 'library_search_scope_menu.dart';
import 'library_design_tokens.dart';
import 'library_search_field.dart';

class LibraryBooksFragment extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final List<LibraryBookItem> books;
  final String? selectedPath;
  final Set<String> favoritePaths;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryBookItem> onSelected;
  final ValueChanged<LibraryBookItem> onDoubleTap;
  final void Function(LibraryBookItem, bool) onFavoriteChanged;
  final List<Widget> leadingActions;
  final String searchScope;
  final ValueChanged<String> onSearchScopeChanged;

  const LibraryBooksFragment({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.books,
    required this.selectedPath,
    required this.favoritePaths,
    required this.onSearchChanged,
    required this.onSelected,
    required this.onDoubleTap,
    required this.onFavoriteChanged,
    required this.searchScope,
    required this.onSearchScopeChanged,
    this.leadingActions = const [],
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              ...leadingActions,
              LibrarySearchScopeMenu(
                selectedScope: searchScope,
                onSelected: onSearchScopeChanged,
              ),
              Expanded(
                child: LibrarySearchField(
                  controller: searchController,
                  hint: libraryBookSearchHint(searchScope, context: searchHint),
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LibraryBooksTable(
            books: books,
            selectedPath: selectedPath,
            favoritePaths: favoritePaths,
            onSelected: onSelected,
            onDoubleTap: onDoubleTap,
            onFavoriteChanged: onFavoriteChanged,
          ),
        ),
      ],
    );
  }
}
