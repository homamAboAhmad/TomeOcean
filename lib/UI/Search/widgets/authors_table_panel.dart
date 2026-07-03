import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/Search/widgets/search_entity_books_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/search_book_selection_toolbar_state.dart';
import 'package:path/path.dart' as p;

class AuthorsTablePanel extends StatelessWidget {
  final List<Author> authors;
  final Set<String> selectedAuthorIds;
  final String? viewedAuthorId;
  final Function(String) onAuthorClicked;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final Map<String, String> bookAuthorMap;
  final bool isLoading;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(List<String>) onAuthorsAdded;
  final Function(List<String>) onAuthorsRemoved;
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

  const AuthorsTablePanel({
    super.key,
    required this.authors,
    required this.selectedAuthorIds,
    this.viewedAuthorId,
    required this.onAuthorClicked,
    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.bookAuthorMap,
    required this.isLoading,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onAuthorsAdded,
    required this.onAuthorsRemoved,
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
    if (authors.isEmpty) return const Center(child: Text('لا توجد مؤلفين'));
    return SearchEntityBooksPanel(
      rows: authors
          .map(
            (author) => LibraryEntityRow(
              id: author.id,
              title: author.name,
              secondary:
                  author.deathYear ?? authorDeathYears[author.id] ?? '',
              count: authorBookCounts[author.id] ?? 0,
            ),
          )
          .toList(),
      viewedEntityId: viewedAuthorId,
      selectedEntityIds: selectedAuthorIds,
      entityTitleHeader: 'المؤلف',
      entitySecondaryHeader: 'الوفاة',
      entitySearchHint: 'بحث في المؤلفين',
      showEntityCount: true,
      chooseEntityMessage: 'اختر مؤلفًا لعرض كتبه',
      booksTitle: 'كتب المؤلف',
      loadBooks: _getBooksForViewedAuthor,
      selectedBooks: selectedBooks,
      authors: authors,
      authorDeathYears: authorDeathYears,
      bookAuthorMap: bookAuthorMap,
      onEntitySelected: (id) => onAuthorClicked(id),
      onEntitiesAdded: onAuthorsAdded,
      onEntitiesRemoved: onAuthorsRemoved,
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

  Future<List<Map<String, dynamic>>> _getBooksForViewedAuthor() async {
    if (viewedAuthorId == null) return [];
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      final paths = await metadataDb.getBookPaths(authorId: viewedAuthorId);
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
