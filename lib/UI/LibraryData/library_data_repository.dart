import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_models.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_picker_repository.dart';
import 'package:golden_shamela/UI/Search/helpers/page_search_content_matcher.dart';

class LibraryDataRepository {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();
  final LibraryPickerRepository _pickerRepository = LibraryPickerRepository();

  Future<LibraryDataSnapshot> loadSnapshot() async {
    final books = await _pickerRepository.loadBooks();
    final authors = await _pickerRepository.loadAuthors();
    final counts = <String, int>{};
    for (final item in books) {
      final authorId = item.book.authorId;
      if (authorId.isEmpty) continue;
      counts[authorId] = (counts[authorId] ?? 0) + 1;
    }
    final briefBooks = await loadBriefBooks();
    return LibraryDataSnapshot(
      authors: authors,
      books: books,
      briefBooks: briefBooks,
      authorBookCounts: counts,
    );
  }

  Future<LibraryBookItem?> loadBookDetails(LibraryBookItem item) {
    return _pickerRepository.loadBookDetails(item);
  }

  Future<List<LibraryBookItem>> loadBriefBooks() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.id, b.book_name, b.book_path, b.author_id, b.section_id,
             b.book_type, b.matches_printed, b.description, b.publisher,
             b.edition, b.page_count,
             a.name AS author_name,
             a.death_year AS author_death_year,
             s.title AS section_title
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      WHERE TRIM(b.description) <> ''
      ORDER BY b.book_name ASC
    ''');
    final books = rows.map(_bookItemFromRow).toList();
    books.sort(LibraryBookItem.compareByAuthorDeathThenTitle);
    return books;
  }

  Future<List<LibraryDataSearchResult>> searchWithGroups({
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool ordered,
    required bool proximity,
    required bool affixSearch,
  }) async {
    if (!_hasActiveTerms(groups)) return const [];

    final results = <LibraryDataSearchResult>[];
    final snippetTerm = _firstSearchTerm(groups);

    final authors = await _pickerRepository.loadAuthors();
    for (final author in authors) {
      final source = _authorSource(author);
      final matched = await _matchesMetadata(
        source,
        groups: groups,
        searchGrouping: searchGrouping,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        ordered: ordered,
        proximity: proximity,
        affixSearch: affixSearch,
      );
      if (!matched) continue;
      results.add(
        LibraryDataSearchResult(
          type: LibraryDataItemType.author,
          title: author.name,
          snippet: _snippet(source, snippetTerm, fallback: author.name),
          author: author,
        ),
      );
      if (results.length >= 600) return results;
    }

    final books = await _loadSearchableBooks();
    for (final item in books) {
      final bookSource = _bookSource(item);
      final bookMatched = await _matchesMetadata(
        bookSource,
        groups: groups,
        searchGrouping: searchGrouping,
        morphologicalSearch: morphologicalSearch,
        considerDiacritics: considerDiacritics,
        considerHamzas: considerHamzas,
        considerNumbers: considerNumbers,
        ordered: ordered,
        proximity: proximity,
        affixSearch: affixSearch,
      );
      if (bookMatched) {
        results.add(
          LibraryDataSearchResult(
            type: LibraryDataItemType.book,
            title: item.title,
            snippet: _snippet(bookSource, snippetTerm, fallback: item.title),
            book: item,
          ),
        );
      }

      final brief = item.book.description.trim();
      if (brief.isNotEmpty) {
        final briefSource = _briefSource(item);
        final briefMatched = await _matchesMetadata(
          briefSource,
          groups: groups,
          searchGrouping: searchGrouping,
          morphologicalSearch: morphologicalSearch,
          considerDiacritics: considerDiacritics,
          considerHamzas: considerHamzas,
          considerNumbers: considerNumbers,
          ordered: ordered,
          proximity: proximity,
          affixSearch: affixSearch,
        );
        if (briefMatched) {
          results.add(
            LibraryDataSearchResult(
              type: LibraryDataItemType.brief,
              title: item.title,
              snippet: _snippet(briefSource, snippetTerm, fallback: item.title),
              book: item,
            ),
          );
        }
      }

      if (results.length >= 600) return results.take(600).toList();
    }

    return results;
  }

  Future<bool> _matchesMetadata(
    String source, {
    required Map<String, List<String>> groups,
    required String searchGrouping,
    required bool morphologicalSearch,
    required bool considerDiacritics,
    required bool considerHamzas,
    required bool considerNumbers,
    required bool ordered,
    required bool proximity,
    required bool affixSearch,
  }) {
    return PageSearchContentMatcher.matchesConditions(
      groups: groups,
      searchGrouping: searchGrouping,
      pageContent: source,
      morphologicalSearch: morphologicalSearch,
      considerDiacritics: considerDiacritics,
      considerHamzas: considerHamzas,
      considerNumbers: considerNumbers,
      ordered: ordered,
      proximity: proximity,
      affixSearch: affixSearch,
    );
  }

  Future<List<LibraryBookItem>> _loadSearchableBooks() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT b.id, b.book_name, b.book_path, b.author_id, b.section_id,
             b.book_type, b.matches_printed, b.description, b.publisher,
             b.edition, b.page_count,
             a.name AS author_name,
             a.death_year AS author_death_year,
             s.title AS section_title,
             br.brief AS book_brief
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      LEFT JOIN book_briefs br ON br.book_path = b.book_path
      ORDER BY b.book_name ASC
    ''');
    final books = rows.map(_bookItemFromRow).toList();
    books.sort(LibraryBookItem.compareByAuthorDeathThenTitle);
    return books;
  }

  LibraryBookItem _bookItemFromRow(Map<String, Object?> row) {
    final path = row['book_path'] as String? ?? '';
    return LibraryBookItem(
      bookPath: path,
      book: BookCard(
        id: row['id'] as String? ?? path,
        title: row['book_name'] as String? ?? '',
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
      bookBrief: row['book_brief'] as String? ?? '',
    );
  }

  bool _hasActiveTerms(Map<String, List<String>> groups) {
    return groups.values.any(
      (terms) => terms.any((term) => term.trim().isNotEmpty),
    );
  }

  String _firstSearchTerm(Map<String, List<String>> groups) {
    for (final key in const ['and', 'or', 'not']) {
      for (final term in groups[key] ?? const <String>[]) {
        final trimmed = term.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return '';
  }

  String _authorSource(Author author) {
    return [
      author.name,
      author.deathYear ?? '',
      author.description,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _bookSource(LibraryBookItem item) {
    final book = item.book;
    return [
      item.title,
      item.authorDisplay,
      item.sectionTitle,
      BookMetadataOptions.typeLabel(book.bookType),
      book.matchesPrinted ? 'موافق للمطبوع' : 'غير موافق للمطبوع',
      book.publisher,
      book.edition,
      book.pageCount,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _briefSource(LibraryBookItem item) {
    return [
      item.title,
      item.authorDisplay,
      item.sectionTitle,
      item.book.description,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _snippet(String source, String query, {required String fallback}) {
    final text = source.trim().isEmpty ? fallback : source.trim();
    if (text.length <= 180) return text;
    final normalizedText = LibraryTextNormalizer.normalize(text);
    final normalizedQuery = LibraryTextNormalizer.normalize(query);
    final index = normalizedText.indexOf(normalizedQuery);
    if (index < 0) return '${text.substring(0, 180)}...';
    final start = (index - 60).clamp(0, text.length).toInt();
    final end = (index + normalizedQuery.length + 110)
        .clamp(start, text.length)
        .toInt();
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }
}
