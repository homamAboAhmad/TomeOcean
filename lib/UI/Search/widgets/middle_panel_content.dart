import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Search/widgets/books_list_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/authors_table_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/sections_list_panel.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:path/path.dart' as p;

/// Middle panel content widget that switches based on selected tab
class MiddlePanelContent extends StatelessWidget {
  final String selectedTab;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final Function() onSelectAllBooks;
  final Function() onInvertSelection;
  final TextEditingController booksSearchController;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final List<Author> authors;
  final List<Section> sections;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final bool isLoadingFilters;
  final Function(String) onAuthorToggled;
  final Function() onSelectAllAuthors;
  final Function(String) onSectionToggled;
  final Function() onSelectAllSections;
  final Function() onClearSections;

  const MiddlePanelContent({
    Key? key,
    required this.selectedTab,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.onSelectAllBooks,
    required this.onInvertSelection,
    required this.booksSearchController,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    required this.authors,
    required this.sections,
    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.isLoadingFilters,
    required this.onAuthorToggled,
    required this.onSelectAllAuthors,
    required this.onSectionToggled,
    required this.onSelectAllSections,
    required this.onClearSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case 'الكتب':
        return BooksListPanel(
          filteredIndexedBooks: filteredIndexedBooks,
          allIndexedBooks: allIndexedBooks,
          selectedBooks: selectedBooks,
          onBookSelectionChanged: onBookSelectionChanged,
          onSelectAll: onSelectAllBooks,
          onInvertSelection: onInvertSelection,
          searchController: booksSearchController,
          selectedAuthorIds: selectedAuthorIds,
          selectedSectionIds: selectedSectionIds,
          authors: authors,
          authorBookCounts: authorBookCounts,
          authorDeathYears: authorDeathYears,
          onAuthorToggled: onAuthorToggled,
        );
      case 'المؤلفون':
        return AuthorsTablePanel(
          authors: authors,
          selectedAuthorIds: selectedAuthorIds,
          onAuthorToggled: onAuthorToggled,
          onSelectAllAuthors: onSelectAllAuthors,
          authorBookCounts: authorBookCounts,
          authorDeathYears: authorDeathYears,
          isLoading: isLoadingFilters,
        );
      case 'التصنيف':
        return SectionsListPanel(
          sections: sections,
          selectedSectionIds: selectedSectionIds,
          onSectionToggled: onSectionToggled,
          onSelectAllSections: onSelectAllSections,
          onClearSelection: onClearSections,
          isLoading: isLoadingFilters,
        );
      default:
        return Center(
          child: Text(
            'قريباً: $selectedTab',
            style: normalStyle(color: Colors.grey),
          ),
        );
    }
  }
}

