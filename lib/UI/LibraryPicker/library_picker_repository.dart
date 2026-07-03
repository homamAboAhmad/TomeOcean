import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_details_loader.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_full_book_search.dart';
import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';

class LibraryPickerRepository {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();
  final LibraryBookDetailsLoader _detailsLoader = LibraryBookDetailsLoader();
  final LibraryFullBookSearch _fullBookSearch = LibraryFullBookSearch();

  Future<List<LibraryBookItem>> loadBooks() async {
    _detailsLoader.clear();
    await _db.initialize();
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.id, b.book_name, b.book_path, b.author_id, b.section_id,
             b.book_type, b.matches_printed, b.description, b.publisher,
             b.edition, b.page_count,
             a.name AS author_name, a.death_year AS author_death_year,
             s.title AS section_title
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      ORDER BY b.book_name ASC
    ''');
    final items = <LibraryBookItem>[];
    for (final row in rows) {
      final path = row['book_path'] as String? ?? '';
      if (path.isEmpty) continue;
      items.add(_itemFromRow(row, path));
    }
    items.sort(LibraryBookItem.compareByAuthorDeathThenTitle);
    return items;
  }

  Future<List<Author>> loadAuthors() async {
    final authors = await _db.getAuthors();
    authors.sort(_compareAuthorsByDeathYear);
    return authors;
  }

  Future<List<Section>> loadSections() => _db.getSections(limit: 10000);

  Future<Set<String>> loadFavorites() => _db.getFavoriteBookPaths();

  Future<List<String>> loadRecentPaths() => _db.getRecentBookPaths();

  Future<Set<String>> searchFullBookPaths(String query) =>
      _fullBookSearch.findPaths(query);

  Future<LibraryBookItem?> loadBookDetails(LibraryBookItem item) =>
      _detailsLoader.load(item);

  Future<void> setFavorite(String path, bool value) =>
      _db.setFavoriteBook(path, value);

  Future<void> removeRecent(String path) => _db.removeRecentBook(path);

  LibraryBookItem _itemFromRow(Map<String, Object?> row, String path) {
    return LibraryBookItem(
      bookPath: path,
      book: BookCard(
        id: row['id'] as String,
        title: row['book_name'] as String,
        authorId: row['author_id'] as String? ?? '',
        sectionId: row['section_id'] as String? ?? '',
        description: row['description'] as String? ?? '',
        bookType: row['book_type'] as String? ?? '',
        matchesPrinted: row['matches_printed'] == 1,
        publisher: row['publisher'] as String? ?? '',
        edition: row['edition'] as String? ?? '',
        pageCount: row['page_count']?.toString() ?? '',
      ),
      authorName: row['author_name'] as String? ?? '',
      authorDeathYear: row['author_death_year'] as String? ?? '',
      sectionTitle: row['section_title'] as String? ?? '',
    );
  }

  int _compareAuthorsByDeathYear(Author a, Author b) {
    final death = AuthorDeathDateParser.compare(a.deathYear, b.deathYear);
    if (death != 0) return death;
    return a.name.compareTo(b.name);
  }
}
