import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:path/path.dart' as p;

/// Manages filter data loading and book filtering logic
class SearchStateManager {
  final BooksMetadataDatabase _metadataDb = BooksMetadataDatabase();

  /// Load authors, sections, and their metadata
  Future<FilterData> loadFilterData() async {
    print("SearchStateManager: Loading filter data...");
    
    // Ensure database is initialized and migrated
    await _metadataDb.initialize();
    print("SearchStateManager: Database initialized");
    
    // Check counts before migration
    final authorCountBefore = await _metadataDb.countAuthors();
    final sectionCountBefore = await _metadataDb.countSections();
    print("SearchStateManager: Before migration: $authorCountBefore authors, $sectionCountBefore sections");
    
    await _metadataDb.migrateFromSharedPreferences();
    
    // Check counts after migration
    final authorCountAfter = await _metadataDb.countAuthors();
    final sectionCountAfter = await _metadataDb.countSections();
    print("SearchStateManager: After migration: $authorCountAfter authors, $sectionCountAfter sections");
    
    final authorStorage = AuthorStorage();
    final sectionStorage = SectionStorage();
    
    // Load authors and sections with pagination (limit to 1000 for dropdown)
    var authors = await authorStorage.getAuthorsAsync(limit: 1000);
    var sections = await sectionStorage.getSectionsAsync(limit: 1000);
    
    print("SearchStateManager: Loaded ${authors.length} authors and ${sections.length} sections from database");
    
    // If no authors or sections exist, create default ones
    if (authors.isEmpty) {
      print("SearchStateManager: No authors found in database, creating default authors...");
      try {
        authors = await authorStorage.addDefaultAuthors();
        print("SearchStateManager: Created ${authors.length} default authors");
        // Reload to verify
        authors = await authorStorage.getAuthorsAsync(limit: 1000);
        print("SearchStateManager: After creating defaults, loaded ${authors.length} authors");
      } catch (e) {
        print("SearchStateManager: Error creating default authors: $e");
        print("SearchStateManager: Stack trace: ${StackTrace.current}");
      }
    }
    
    if (sections.isEmpty) {
      print("SearchStateManager: No sections found in database, creating default sections...");
      try {
        sections = await sectionStorage.addDefaultSections();
        print("SearchStateManager: Created ${sections.length} default sections");
        // Reload to verify
        sections = await sectionStorage.getSectionsAsync(limit: 1000);
        print("SearchStateManager: After creating defaults, loaded ${sections.length} sections");
      } catch (e) {
        print("SearchStateManager: Error creating default sections: $e");
        print("SearchStateManager: Stack trace: ${StackTrace.current}");
      }
    }
    
    // Load book counts for each author
    await _metadataDb.initialize();
    final bookCounts = <String, int>{};
    for (var author in authors) {
      final count = await _metadataDb.countBooks(authorId: author.id);
      bookCounts[author.id] = count;
    }
    
    // Extract death years from author descriptions
    final deathYears = _extractDeathYears(authors);
    
    print("SearchStateManager: Final filter data loaded: ${authors.length} authors, ${sections.length} sections");
    
    return FilterData(
      authors: authors,
      sections: sections,
      authorBookCounts: bookCounts,
      authorDeathYears: deathYears,
    );
  }

  /// Update filtered books based on selected authors and sections
  Future<FilteredBooksResult> updateFilteredBooks({
    required Set<String> selectedAuthorIds,
    required Set<String> selectedSectionIds,
    required List<Map<String, dynamic>> allIndexedBooks,
  }) async {
    try {
      print("SearchStateManager: Updating filtered books...");
      print("SearchStateManager: Selected author IDs: $selectedAuthorIds");
      print("SearchStateManager: Selected section IDs: $selectedSectionIds");
      
      await _metadataDb.initialize();
      
      // Get book paths filtered by author and/or section
      Set<String> filteredBookPaths = {};
      
      if (selectedAuthorIds.isEmpty && selectedSectionIds.isEmpty) {
        // No filters - get all book paths from metadata database
        filteredBookPaths = (await _metadataDb.getBookPaths()).toSet();
        print("SearchStateManager: No filters, got ${filteredBookPaths.length} book paths from metadata DB");
      } else {
        // Get paths for each selected author
        for (String authorId in selectedAuthorIds) {
          final paths = await _metadataDb.getBookPaths(authorId: authorId);
          filteredBookPaths.addAll(paths);
          print("SearchStateManager: Author $authorId has ${paths.length} books");
        }
        
        // Get paths for each selected section
        for (String sectionId in selectedSectionIds) {
          final paths = await _metadataDb.getBookPaths(sectionId: sectionId);
          filteredBookPaths.addAll(paths);
          print("SearchStateManager: Section $sectionId has ${paths.length} books");
        }
        
        // If both author and section filters are applied, we need intersection
        if (selectedAuthorIds.isNotEmpty && selectedSectionIds.isNotEmpty) {
          Set<String> authorPaths = {};
          for (String authorId in selectedAuthorIds) {
            authorPaths.addAll(await _metadataDb.getBookPaths(authorId: authorId));
          }
          
          Set<String> sectionPaths = {};
          for (String sectionId in selectedSectionIds) {
            sectionPaths.addAll(await _metadataDb.getBookPaths(sectionId: sectionId));
          }
          
          // Intersection: books that match both author AND section
          filteredBookPaths = authorPaths.intersection(sectionPaths);
          print("SearchStateManager: Intersection of ${authorPaths.length} author books and ${sectionPaths.length} section books = ${filteredBookPaths.length} books");
        }
      }
      
      print("SearchStateManager: Found ${filteredBookPaths.length} unique book paths matching filters");
      
      // Normalize paths for comparison (handle path separators)
      String normalizePath(String path) {
        return path.replaceAll('\\', '/').toLowerCase().trim();
      }
      
      final normalizedFilteredPaths = filteredBookPaths.map(normalizePath).toSet();
      
      // Filter indexed books based on author/section selection
      List<Map<String, dynamic>> filtered;
      if (selectedAuthorIds.isNotEmpty || selectedSectionIds.isNotEmpty) {
        // If filters are applied, only show books that match
        filtered = allIndexedBooks.where((book) {
          final bookPath = book['book_path'] as String;
          final normalizedPath = normalizePath(bookPath);
          final matches = normalizedFilteredPaths.contains(normalizedPath);
          if (!matches) {
            // Try matching by filename only (without full path)
            final fileName = p.basename(bookPath);
            final matchesByFileName = normalizedFilteredPaths.any((filteredPath) => 
              normalizePath(p.basename(filteredPath)) == normalizePath(fileName));
            if (matchesByFileName) {
              print("SearchStateManager: Matched by filename: $fileName");
              return true;
            }
          }
          return matches;
        }).toList();
        print("SearchStateManager: Filtered to ${filtered.length} books from ${allIndexedBooks.length} total");
      } else {
        // If no filters, show all books
        filtered = allIndexedBooks;
        print("SearchStateManager: No filters applied, showing all ${filtered.length} books");
      }
      
      return FilteredBooksResult(
        filteredBooks: filtered,
      );
    } catch (e) {
      print("SearchStateManager: Error updating filtered books: $e");
      print("SearchStateManager: Stack trace: ${StackTrace.current}");
      // On error, show all books
      return FilteredBooksResult(
        filteredBooks: allIndexedBooks,
      );
    }
  }

  /// Extract death years from author descriptions
  Map<String, String> _extractDeathYears(List<Author> authors) {
    final deathYears = <String, String>{};
    for (var author in authors) {
      // Try to extract death year from description
      // Common patterns: "ت 545 م", "ت 545", "545 م", etc.
      final description = author.description;
      if (description.isNotEmpty) {
        final regex = RegExp(r'ت\s*(\d+)\s*م?|(\d+)\s*م');
        final match = regex.firstMatch(description);
        if (match != null) {
          final year = match.group(1) ?? match.group(2);
          if (year != null) {
            deathYears[author.id] = year;
          }
        }
      }
    }
    return deathYears;
  }
}

/// Data class for filter data
class FilterData {
  final List<Author> authors;
  final List<Section> sections;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;

  FilterData({
    required this.authors,
    required this.sections,
    required this.authorBookCounts,
    required this.authorDeathYears,
  });
}

/// Data class for filtered books result
class FilteredBooksResult {
  final List<Map<String, dynamic>> filteredBooks;

  FilteredBooksResult({
    required this.filteredBooks,
  });
}

