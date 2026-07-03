import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/Search/widgets/search_entity_books_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/search_book_selection_toolbar_state.dart';
import 'package:path/path.dart' as p;

class SectionsListPanel extends StatelessWidget {
  final List<Section> sections;
  final Set<String> selectedSectionIds;
  final String? viewedSectionId;
  final Function(String) onSectionClicked;
  final bool isLoading;
  final List<Author> authors;
  final Map<String, String> authorDeathYears;
  final Map<String, String> bookAuthorMap;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(List<String>) onSectionsAdded;
  final Function(List<String>) onSectionsRemoved;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;
  final String bookSearchQuery;
  final String bookSearchScope;
  final Set<String> fullSearchPaths;
  final String? focusedBookPath;
  final ValueChanged<LibraryBookItem> onBookFocused;
  final SearchBookSelectionStateChanged? onBookSelectionStateChanged;
  final int selectAllRequest;
  final Widget? booksToolbar;
  final bool showBookCard;
  final Widget? bookCard;

  const SectionsListPanel({
    super.key,
    required this.sections,
    required this.selectedSectionIds,
    this.viewedSectionId,
    required this.onSectionClicked,
    required this.isLoading,
    required this.authors,
    required this.authorDeathYears,
    required this.bookAuthorMap,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onSectionsAdded,
    required this.onSectionsRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    required this.bookSearchQuery,
    required this.bookSearchScope,
    required this.fullSearchPaths,
    required this.focusedBookPath,
    required this.onBookFocused,
    this.onBookSelectionStateChanged,
    this.selectAllRequest = 0,
    this.booksToolbar,
    this.showBookCard = false,
    this.bookCard,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (sections.isEmpty) return const Center(child: Text('لا توجد أقسام'));
    return SearchEntityBooksPanel(
      rows: sections
          .map(
            (section) => LibraryEntityRow(
              id: section.id,
              title: section.title,
              count: 0,
            ),
          )
          .toList(),
      viewedEntityId: viewedSectionId,
      selectedEntityIds: selectedSectionIds,
      entityTitleHeader: 'القسم',
      entitySecondaryHeader: '',
      entitySearchHint: 'بحث في التصنيفات',
      showEntityCount: false,
      chooseEntityMessage: 'اختر قسمًا لعرض كتبه',
      booksTitle: 'كتب القسم',
      loadBooks: _getBooksForViewedSection,
      selectedBooks: selectedBooks,
      authors: authors,
      authorDeathYears: authorDeathYears,
      bookAuthorMap: bookAuthorMap,
      onEntitySelected: (id) => onSectionClicked(id),
      onEntitiesAdded: onSectionsAdded,
      onEntitiesRemoved: onSectionsRemoved,
      onBooksAdded: onBooksAdded,
      onBooksRemoved: onBooksRemoved,
      bookSearchQuery: bookSearchQuery,
      bookSearchScope: bookSearchScope,
      fullSearchPaths: fullSearchPaths,
      focusedBookPath: focusedBookPath,
      onBookFocused: onBookFocused,
      onBookSelectionStateChanged: onBookSelectionStateChanged,
      selectAllRequest: selectAllRequest,
      booksToolbar: booksToolbar,
      showBookCard: showBookCard,
      bookCard: bookCard,
    );
  }

  Future<List<Map<String, dynamic>>> _getBooksForViewedSection() async {
    if (viewedSectionId == null) return [];
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      final paths = await metadataDb.getBookPaths(sectionId: viewedSectionId);
      return _matchingBooks(paths);
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _matchingBooks(List<String> paths) {
    final normalizedPaths =
        paths.map((path) => p.normalize(path).toLowerCase()).toSet();
    return allIndexedBooks.where((book) {
      final path = p.normalize(book['book_path'] as String).toLowerCase();
      return normalizedPaths.contains(path);
    }).toList();
  }
}
