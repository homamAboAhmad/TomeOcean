import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_fragment.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_fragment.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';

class LibrarySectionsView extends StatelessWidget {
  final List<Section> sections;
  final List<LibraryBookItem> books;
  final Map<String, int> counts;
  final String? selectedSectionId;
  final String? selectedBookPath;
  final Set<String> favoritePaths;
  final ValueChanged<String> onSectionSelected;
  final ValueChanged<LibraryBookItem> onBookSelected;
  final ValueChanged<LibraryBookItem> onBookOpened;
  final void Function(LibraryBookItem, bool) onFavoriteChanged;
  final LibrarySplitController splitController;
  final TextEditingController booksSearchController;
  final ValueChanged<String> onBooksSearchChanged;
  final TextEditingController entitiesSearchController;
  final ValueChanged<String> onEntitiesSearchChanged;
  final List<Widget> booksLeadingActions;
  final String booksSearchScope;
  final ValueChanged<String> onBooksSearchScopeChanged;

  const LibrarySectionsView({
    super.key,
    required this.sections,
    required this.books,
    required this.counts,
    required this.selectedSectionId,
    required this.selectedBookPath,
    required this.favoritePaths,
    required this.onSectionSelected,
    required this.onBookSelected,
    required this.onBookOpened,
    required this.onFavoriteChanged,
    required this.splitController,
    required this.booksSearchController,
    required this.onBooksSearchChanged,
    required this.entitiesSearchController,
    required this.onEntitiesSearchChanged,
    required this.booksLeadingActions,
    required this.booksSearchScope,
    required this.onBooksSearchScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LibrarySplitPane(
      axis: Axis.horizontal,
      controller: splitController,
      first: LibraryBooksFragment(
            searchController: booksSearchController,
            searchHint: 'بحث في كتب التصنيف',
            books: books,
            selectedPath: selectedBookPath,
            favoritePaths: favoritePaths,
            onSelected: onBookSelected,
            onDoubleTap: onBookOpened,
            onFavoriteChanged: onFavoriteChanged,
            onSearchChanged: onBooksSearchChanged,
            leadingActions: booksLeadingActions,
            searchScope: booksSearchScope,
            onSearchScopeChanged: onBooksSearchScopeChanged,
      ),
      second: LibraryEntitiesFragment(
            searchController: entitiesSearchController,
            searchHint: 'بحث في التصنيفات',
            onSearchChanged: onEntitiesSearchChanged,
            rows: sections
                .map(
                  (section) => LibraryEntityRow(
                    id: section.id,
                    title: section.title,
                    count: counts[section.id] ?? 0,
                  ),
                )
                .toList(),
            selectedId: selectedSectionId,
            titleHeader: 'القسم',
            secondaryHeader: '',
            onSelected: onSectionSelected,
      ),
    );
  }
}

class LibraryAuthorsView extends StatelessWidget {
  final List<Author> authors;
  final List<LibraryBookItem> books;
  final Map<String, int> counts;
  final String? selectedAuthorId;
  final String? selectedBookPath;
  final Set<String> favoritePaths;
  final ValueChanged<String> onAuthorSelected;
  final VoidCallback onAuthorHeaderTap;
  final VoidCallback onDeathHeaderTap;
  final ValueChanged<LibraryBookItem> onBookSelected;
  final ValueChanged<LibraryBookItem> onBookOpened;
  final void Function(LibraryBookItem, bool) onFavoriteChanged;
  final LibrarySplitController splitController;
  final TextEditingController booksSearchController;
  final ValueChanged<String> onBooksSearchChanged;
  final TextEditingController entitiesSearchController;
  final ValueChanged<String> onEntitiesSearchChanged;
  final List<Widget> booksLeadingActions;
  final String booksSearchScope;
  final ValueChanged<String> onBooksSearchScopeChanged;

  const LibraryAuthorsView({
    super.key,
    required this.authors,
    required this.books,
    required this.counts,
    required this.selectedAuthorId,
    required this.selectedBookPath,
    required this.favoritePaths,
    required this.onAuthorSelected,
    required this.onAuthorHeaderTap,
    required this.onDeathHeaderTap,
    required this.onBookSelected,
    required this.onBookOpened,
    required this.onFavoriteChanged,
    required this.splitController,
    required this.booksSearchController,
    required this.onBooksSearchChanged,
    required this.entitiesSearchController,
    required this.onEntitiesSearchChanged,
    required this.booksLeadingActions,
    required this.booksSearchScope,
    required this.onBooksSearchScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LibrarySplitPane(
      axis: Axis.horizontal,
      controller: splitController,
      first: LibraryBooksFragment(
            searchController: booksSearchController,
            searchHint: 'بحث في كتب المؤلف',
            books: books,
            selectedPath: selectedBookPath,
            favoritePaths: favoritePaths,
            onSelected: onBookSelected,
            onDoubleTap: onBookOpened,
            onFavoriteChanged: onFavoriteChanged,
            onSearchChanged: onBooksSearchChanged,
            leadingActions: booksLeadingActions,
            searchScope: booksSearchScope,
            onSearchScopeChanged: onBooksSearchScopeChanged,
      ),
      second: LibraryEntitiesFragment(
            searchController: entitiesSearchController,
            searchHint: 'بحث في المؤلفين',
            onSearchChanged: onEntitiesSearchChanged,
            rows: authors
                .map(
                  (author) => LibraryEntityRow(
                    id: author.id,
                    title: author.name,
                    secondary: author.deathYear ?? 'غير محدد',
                    count: counts[author.id] ?? 0,
                  ),
                )
                .toList(),
            selectedId: selectedAuthorId,
            titleHeader: 'المؤلف',
            secondaryHeader: 'الوفاة',
            onSelected: onAuthorSelected,
            onTitleHeaderTap: onAuthorHeaderTap,
            onSecondaryHeaderTap: onDeathHeaderTap,
      ),
    );
  }
}
