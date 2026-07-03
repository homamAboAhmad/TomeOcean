import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Helpers/ArabicSearchEngine.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:golden_shamela/Helpers/BookCardStorage.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

// Data model for a single search result
class ArabicSearchHit {
  final String id;
  final String bookPath;
  final String bookName;
  final int pageNumber;
  final String sectionType;
  final String content;
  final String? rawContent;
  final double rank;

  ArabicSearchHit({
    required this.id,
    required this.bookPath,
    required this.bookName,
    required this.pageNumber,
    required this.sectionType,
    required this.content,
    this.rawContent,
    required this.rank,
  });

  factory ArabicSearchHit.fromJson(Map<String, dynamic> json) {
    return ArabicSearchHit(
      id: json['id'],
      bookPath: json['book_path'],
      bookName: json['book_name'],
      pageNumber: json['page_number'],
      sectionType: json['section_type'],
      content: json['content'],
      rawContent: json['raw_content'],
      rank: (json['rank'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get snippet {
    // Extract snippet with context (first 150 chars)
    final text = rawContent ?? content;
    return text.length > 150 ? '${text.substring(0, 150)}...' : text;
  }
}

class ArabicSearchDialog extends StatefulWidget {
  final Function(String, int) onResultTapped;
  final List<Map<String, dynamic>> indexedBooks;
  const ArabicSearchDialog({
    Key? key,
    required this.onResultTapped,
    required this.indexedBooks,
  }) : super(key: key);

  @override
  _ArabicSearchDialogState createState() => _ArabicSearchDialogState();
}

class _ArabicSearchDialogState extends State<ArabicSearchDialog> {
  final _queryController = TextEditingController();
  final Map<String, bool> _searchSections = {
    'main': true,
    'footnote': false,
    'comment': false,
    'title': false,
  };

  bool _isExactMatch = false;
  bool _isLoading = false;
  List<ArabicSearchHit> _results = [];
  int _totalCount = 0;
  String? _errorMessage;

  late Map<String, bool> _selectedBooks;
  List<Map<String, dynamic>> _filteredIndexedBooks = [];
  final ArabicSearchEngine _engine = ArabicSearchEngine();
  
  // Filter state
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  String? _selectedAuthorId;
  String? _selectedSectionId;
  bool _isLoadingFilters = false;

  @override
  void initState() {
    super.initState();
    _filteredIndexedBooks = widget.indexedBooks;
    _selectedBooks = {
      for (var book in widget.indexedBooks) book['book_path'] as String: true
    };
    _loadFilterData();
  }
  
  Future<void> _loadFilterData() async {
    setState(() {
      _isLoadingFilters = true;
    });
    
    try {
      final authorStorage = AuthorStorage();
      final sectionStorage = SectionStorage();
      
      // Ensure database is initialized and migrated
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      print("Database initialized");
      
      // Check counts before migration
      final authorCountBefore = await metadataDb.countAuthors();
      final sectionCountBefore = await metadataDb.countSections();
      print("Before migration: $authorCountBefore authors, $sectionCountBefore sections");
      
      await metadataDb.migrateFromSharedPreferences();
      
      // Check counts after migration
      final authorCountAfter = await metadataDb.countAuthors();
      final sectionCountAfter = await metadataDb.countSections();
      print("After migration: $authorCountAfter authors, $sectionCountAfter sections");
      
      // Load authors and sections with pagination (limit to 1000 for dropdown)
      var authors = await authorStorage.getAuthorsAsync(limit: 1000);
      var sections = await sectionStorage.getSectionsAsync(limit: 1000);
      
      print("Loaded ${authors.length} authors and ${sections.length} sections from database");
      
      // If no authors or sections exist, create default ones
      if (authors.isEmpty) {
        print("No authors found in database, creating default authors...");
        try {
          authors = await authorStorage.addDefaultAuthors();
          print("Created ${authors.length} default authors");
          // Reload to verify
          authors = await authorStorage.getAuthorsAsync(limit: 1000);
          print("After creating defaults, loaded ${authors.length} authors");
        } catch (e) {
          print("Error creating default authors: $e");
          print("Stack trace: ${StackTrace.current}");
        }
      }
      
      if (sections.isEmpty) {
        print("No sections found in database, creating default sections...");
        try {
          sections = await sectionStorage.addDefaultSections();
          print("Created ${sections.length} default sections");
          // Reload to verify
          sections = await sectionStorage.getSectionsAsync(limit: 1000);
          print("After creating defaults, loaded ${sections.length} sections");
        } catch (e) {
          print("Error creating default sections: $e");
          print("Stack trace: ${StackTrace.current}");
        }
      }
      
      setState(() {
        _allAuthors = authors;
        _allSections = sections;
        _isLoadingFilters = false;
      });
      
      print("Final filter data loaded: ${_allAuthors.length} authors, ${_allSections.length} sections");
      
      // Debug: Print first few items
      if (_allAuthors.isNotEmpty) {
        print("First author: ${_allAuthors.first.name} (id: ${_allAuthors.first.id})");
      }
      if (_allSections.isNotEmpty) {
        print("First section: ${_allSections.first.title} (id: ${_allSections.first.id})");
      }
    } catch (e) {
      print("Error loading filter data: $e");
      setState(() {
        _isLoadingFilters = false;
      });
    }
  }

  Future<void> _updateFilteredBooks() async {
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      
      // Get book paths filtered by author and/or section
      final filteredBookPaths = await metadataDb.getBookPaths(
        authorId: _selectedAuthorId,
        sectionId: _selectedSectionId,
      );
      
      // Convert to Set for faster lookup
      final filteredPathsSet = filteredBookPaths.toSet();
      
      // Filter indexed books based on author/section selection
      List<Map<String, dynamic>> filtered;
      if (_selectedAuthorId != null || _selectedSectionId != null) {
        // If filters are applied, only show books that match
        filtered = widget.indexedBooks.where((book) {
          final bookPath = book['book_path'] as String;
          return filteredPathsSet.contains(bookPath);
        }).toList();
      } else {
        // If no filters, show all books
        filtered = widget.indexedBooks;
      }
      
      setState(() {
        _filteredIndexedBooks = filtered;
        // Update selected books - keep selection for books that are still in filtered list
        final newSelectedBooks = <String, bool>{};
        for (var book in _filteredIndexedBooks) {
          final bookPath = book['book_path'] as String;
          // Keep previous selection if book was selected, otherwise default to true
          newSelectedBooks[bookPath] = _selectedBooks[bookPath] ?? true;
        }
        _selectedBooks = newSelectedBooks;
      });
    } catch (e) {
      print("Error updating filtered books: $e");
      // On error, show all books
      setState(() {
        _filteredIndexedBooks = widget.indexedBooks;
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _performSearch() async {
    String query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
    });

    try {
      await _engine.initialize();

      // Get selected books from filtered list
      final selectedBookPaths = _selectedBooks.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Get selected sections
      final selectedSections = _searchSections.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Apply filters at database level
      final results = await _engine.search(
        query: query,
        bookPaths: selectedBookPaths.length < _filteredIndexedBooks.length
            ? selectedBookPaths
            : null,
        sectionTypes: selectedSections.length < _searchSections.length
            ? selectedSections
            : null,
        // Note: authorId and sectionId filters are already applied via _filteredIndexedBooks
        // So we don't need to pass them again to the search engine
        exactMatch: _isExactMatch,
        limit: 100,
      );

      setState(() {
        _results = results.map((r) => ArabicSearchHit.fromJson(r)).toList();
        _totalCount = results.isNotEmpty
            ? (results.first['estimatedTotalHits'] as int? ?? 0)
            : 0;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Search error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('بحث عربي متقدم (SQLite FTS5)', style: bigStyle()),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterDropdowns(),
                const SizedBox(height: 20),
                _buildSearchQueryInput(),
                const SizedBox(height: 20),
                _buildSearchScope(),
                const SizedBox(height: 20),
                _buildAdvancedOptions(),
                const SizedBox(height: 20),
                Divider(),
                _buildResultsView(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء', style: normalStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('بحث', style: normalStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchQueryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2. ماذا تريد أن تبحث عنه؟', style: mediumStyle()),
        const SizedBox(height: 10),
        TextField(
          controller: _queryController,
          decoration: InputDecoration(
            labelText: 'كلمة أو عبارة البحث',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
            suffixIcon: IconButton(
              icon: const LibraryIcon(LibraryIconType.search),
              onPressed: _performSearch,
            ),
          ),
          style: normalStyle(),
          onSubmitted: (_) => _performSearch(),
        ),
      ],
    );
  }

  Widget _buildSearchScope() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3. أين تريد البحث؟', style: mediumStyle()),
        if (_selectedAuthorId != null || _selectedSectionId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'الكتب المفلترة: ${_filteredIndexedBooks.length} من ${widget.indexedBooks.length}',
              style: smallStyle(color: primaryColor),
            ),
          ),
        const SizedBox(height: 10),
        Text('حدد الكتب:', style: normalStyle()),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
          ),
          child: _filteredIndexedBooks.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد كتب تطابق الفلترة المحددة',
                    style: normalStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredIndexedBooks.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CheckboxListTile(
                        title: Text('كلها', style: normalStyle()),
                        value: _filteredIndexedBooks.isNotEmpty &&
                            _filteredIndexedBooks.every((book) {
                              final bookPath = book['book_path'] as String;
                              return _selectedBooks[bookPath] == true;
                            }),
                        onChanged: (val) {
                          setState(() {
                            for (var book in _filteredIndexedBooks) {
                              final bookPath = book['book_path'] as String;
                              _selectedBooks[bookPath] = val!;
                            }
                          });
                        },
                      );
                    }
                    if (index == 1) {
                      return CheckboxListTile(
                        title: Text('عكس التحديد', style: normalStyle()),
                        value: false,
                        onChanged: (val) {
                          setState(() {
                            for (var book in _filteredIndexedBooks) {
                              final bookPath = book['book_path'] as String;
                              _selectedBooks[bookPath] = !(_selectedBooks[bookPath] ?? false);
                            }
                          });
                        },
                      );
                    }
                    final book = _filteredIndexedBooks[index - 2];
                    final bookPath = book['book_path'] as String;
                    final bookTitle =
                        AppStoragePaths.displayTitleFromPath(bookPath);
                    return CheckboxListTile(
                      title: Text(bookTitle, style: normalStyle()),
                      value: _selectedBooks[bookPath] ?? false,
                      onChanged: (val) => setState(() => _selectedBooks[bookPath] = val!),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        Text('حدد أقسام النص:', style: normalStyle()),
        Wrap(
          spacing: 4.0,
          runSpacing: 0.0,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                  value: _searchSections['main'],
                  onChanged: (val) =>
                      setState(() => _searchSections['main'] = val!)),
              Text('المتن', style: normalStyle()),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                  value: _searchSections['footnote'],
                  onChanged: (val) =>
                      setState(() => _searchSections['footnote'] = val!)),
              Text('الحواشي', style: normalStyle()),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                  value: _searchSections['comment'],
                  onChanged: (val) =>
                      setState(() => _searchSections['comment'] = val!)),
              Text('التعليقات', style: normalStyle()),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                  value: _searchSections['title'],
                  onChanged: (val) =>
                      setState(() => _searchSections['title'] = val!)),
              Text('العناوين', style: normalStyle()),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdowns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. اختر القسم أو المؤلف:', style: mediumStyle()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAuthorDropdown(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSectionDropdown(),
            ),
          ],
        ),
        if (_selectedAuthorId != null || _selectedSectionId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              icon: const LibraryIcon(LibraryIconType.close, size: 16),
              label: Text('إزالة الفلترة', style: smallStyle()),
              onPressed: () {
                setState(() {
                  _selectedAuthorId = null;
                  _selectedSectionId = null;
                });
                _updateFilteredBooks();
              },
            ),
          ),
      ],
    );
  }
  
  Widget _buildAuthorDropdown() {
    if (_isLoadingFilters) {
      return DropdownButton<String>(
        isExpanded: true,
        hint: Text('جاري التحميل...', style: normalStyle()),
        items: [],
        onChanged: null,
      );
    }
    
    print("Building author dropdown with ${_allAuthors.length} authors");
    if (_allAuthors.isEmpty) {
      return DropdownButton<String>(
        isExpanded: true,
        hint: Text('لا توجد مؤلفين', style: normalStyle(color: Colors.red)),
        items: [],
        onChanged: null,
      );
    }
    
    return DropdownButton<String>(
      isExpanded: true,
      value: _selectedAuthorId,
      hint: Text('كل المؤلفين (${_allAuthors.length})', style: normalStyle()),
      onChanged: (String? newValue) {
        setState(() {
          _selectedAuthorId = newValue;
        });
        _updateFilteredBooks();
      },
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('كل المؤلفين', style: normalStyle()),
        ),
        ..._allAuthors.map<DropdownMenuItem<String>>((Author author) {
          return DropdownMenuItem<String>(
            value: author.id,
            child: Text(author.name, style: normalStyle()),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildSectionDropdown() {
    if (_isLoadingFilters) {
      return DropdownButton<String>(
        isExpanded: true,
        hint: Text('جاري التحميل...', style: normalStyle()),
        items: [],
        onChanged: null,
      );
    }
    
    print("Building section dropdown with ${_allSections.length} sections");
    if (_allSections.isEmpty) {
      return DropdownButton<String>(
        isExpanded: true,
        hint: Text('لا توجد أقسام', style: normalStyle(color: Colors.red)),
        items: [],
        onChanged: null,
      );
    }
    
    return DropdownButton<String>(
      isExpanded: true,
      value: _selectedSectionId,
      hint: Text('كل الأقسام (${_allSections.length})', style: normalStyle()),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSectionId = newValue;
        });
        _updateFilteredBooks();
      },
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('كل الأقسام', style: normalStyle()),
        ),
        ..._allSections.map<DropdownMenuItem<String>>((Section section) {
          return DropdownMenuItem<String>(
            value: section.id,
            child: Text(section.title, style: normalStyle()),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('4. خيارات البحث المتقدمة', style: mediumStyle()),
        SwitchListTile(
          title: Text('بحث مطابق تماماً', style: normalStyle()),
          subtitle: Text(
            'إذا تم التفعيل، سيتم البحث بشكل دقيق مطابق للهمزات والتشكيل.',
            style: smallStyle(),
          ),
          value: _isExactMatch,
          onChanged: (bool value) {
            setState(() {
              _isExactMatch = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
          child: Text('حدث خطأ: $_errorMessage', style: normalStyle(color: Colors.red)));
    }

    if (_results.isEmpty) {
      return Center(child: Text('لا توجد نتائج', style: normalStyle()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'النتائج: ${_totalCount}${(_selectedAuthorId != null || _selectedSectionId != null) ? ' (مفلترة)' : ''}',
              style: mediumStyle(),
            ),
            if (_selectedAuthorId != null || _selectedSectionId != null)
              TextButton.icon(
                icon: const LibraryIcon(LibraryIconType.close, size: 16),
                label: Text('إزالة الفلترة', style: smallStyle()),
                onPressed: () {
                  setState(() {
                    _selectedAuthorId = null;
                    _selectedSectionId = null;
                  });
                  _updateFilteredBooks();
                  // Re-search without filters if there's an active search
                  if (_queryController.text.trim().isNotEmpty) {
                    _performSearch();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final result = _results[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(result.bookName,
                    style: normalStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(result.snippet, style: smallStyle()),
                leading: Text('ص ${result.pageNumber + 1}',
                    style: normalStyle(color: primaryColor)),
                onTap: () {
                  widget.onResultTapped(result.bookPath, result.pageNumber);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

