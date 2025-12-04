import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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


  final TextEditingController booksSearchController;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final List<Author> authors;
  final List<Section> sections;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final bool isLoadingFilters;
  final Function(String) onAuthorToggled;

  final Function() onClearSections;
  final Function() onClearAuthors;
  final Function() onClearBooks;
  final Function(String) onAuthorClicked;
  final Function(String) onSectionClicked;
  final Function(List<String>) onAuthorsAdded;
  final Function(List<String>) onAuthorsRemoved;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;
  final Function(List<String>) onSectionsAdded;
  final Function(List<String>) onSectionsRemoved;
  final String? viewedAuthorId;
  final String? viewedSectionId;
  final Map<String, String> bookAuthorMap;
  final VoidCallback? onSelectAll;
  final VoidCallback? onSelectAllAuthors;
  final VoidCallback? onSelectAllBooks;
  final VoidCallback? onSelectAllSections;
  
   MiddlePanelContent({
    Key? key,
    required this.selectedTab,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,

    required this.booksSearchController,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    required this.authors,
    required this.sections,
    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.isLoadingFilters,
    required this.onAuthorToggled,
    required this.onClearSections,
    required this.onClearAuthors,
    required this.onClearBooks,
    required this.onAuthorClicked,
    required this.onSectionClicked,
    required this.onAuthorsAdded,
    required this.onAuthorsRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    required this.onSectionsAdded,
    required this.onSectionsRemoved,
    this.viewedAuthorId,
    this.viewedSectionId,
    this.bookAuthorMap = const {},
    this.onSelectAll,
    this.onSelectAllAuthors,
    this.onSelectAllBooks,
    this.onSelectAllSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case 'الكتب':
        return _wrapWithShortcuts(
          onSelectAll: onSelectAll,
          child: BooksListPanel(
          filteredIndexedBooks: filteredIndexedBooks,
          allIndexedBooks: allIndexedBooks,
          selectedBooks: selectedBooks,
          onBookSelectionChanged: onBookSelectionChanged,


          searchController: booksSearchController,
          selectedAuthorIds: selectedAuthorIds,
          selectedSectionIds: selectedSectionIds,
          authors: authors,
          authorBookCounts: authorBookCounts,
          authorDeathYears: authorDeathYears,
          bookAuthorMap: bookAuthorMap,
          onAuthorToggled: onAuthorToggled,
          onBooksAdded: onBooksAdded,
          onBooksRemoved: onBooksRemoved,
          ),
        );
      case 'المؤلفون':
        return AuthorsTablePanel(
          authors: authors,
          selectedAuthorIds: selectedAuthorIds,
          viewedAuthorId: viewedAuthorId,
          onAuthorToggled: onAuthorToggled,
          onAuthorClicked: onAuthorClicked,
          authorBookCounts: authorBookCounts,
          authorDeathYears: authorDeathYears,
          isLoading: isLoadingFilters,
          filteredIndexedBooks: filteredIndexedBooks,
          allIndexedBooks: allIndexedBooks,
          selectedBooks: selectedBooks,
          onBookSelectionChanged: onBookSelectionChanged,
          onAuthorsAdded: onAuthorsAdded,
          onAuthorsRemoved: onAuthorsRemoved,
          onBooksAdded: onBooksAdded,
          onBooksRemoved: onBooksRemoved,
          onSelectAllAuthors: onSelectAllAuthors,
          onSelectAllBooks: onSelectAllBooks,
          );
      case 'التصنيف':
        return SectionsListPanel(
          sections: sections,
          selectedSectionIds: selectedSectionIds,
          viewedSectionId: viewedSectionId,
          onSectionToggled: onAuthorToggled, // Reusing onAuthorToggled as placeholder

          onSectionClicked: onSectionClicked,

          isLoading: isLoadingFilters,
          filteredIndexedBooks: filteredIndexedBooks,
          allIndexedBooks: allIndexedBooks,
          selectedBooks: selectedBooks,
          onBookSelectionChanged: onBookSelectionChanged,
          onSectionsAdded: onSectionsAdded,
          onSectionsRemoved: onSectionsRemoved,
          onBooksAdded: onBooksAdded,
          onBooksRemoved: onBooksRemoved,
          onSelectAllSections: onSelectAllSections,
          onSelectAllBooks: onSelectAllBooks,
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

  Widget _wrapWithShortcuts({required Widget child, VoidCallback? onSelectAll}) {
    if (onSelectAll == null) return child;
    
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
            const SelectAllIntent(),
      },
      child: Actions(
        actions: {
          SelectAllIntent: CallbackAction<SelectAllIntent>(
            onInvoke: (_) {
              onSelectAll();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: false,
          canRequestFocus: true,
          child: child,
        ),
      ),
    );
  }
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

