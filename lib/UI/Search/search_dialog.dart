import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/BookCardStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/database/search_database_helper.dart';

class SearchDialog extends StatefulWidget {
  final Function(SearchResult result) onResultTapped;

  const SearchDialog({super.key, required this.onResultTapped});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final dbHelper = SearchDatabaseHelper.instance;
  
  SearchType _searchType = SearchType.normalized;
  List<SearchResult> _searchResults = [];
  int _totalResults = 0;
  int _currentPage = 0;
  final int _pageSize = 50;

  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _error;

  // State for filters
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  String? _selectedAuthorId;
  String? _selectedSectionId;
  List<String> _filteredBookTitles = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    setState(() {
      _allAuthors = AuthorStorage().getAuthors();
      _allSections = SectionStorage().getSections();
      _updateFilteredBooks(); // Initial load
    });
  }

  void _updateFilteredBooks() {
    final allBookCards = BookCardStorage().getBookCardList();
    Iterable<BookCard> filtered = allBookCards;

    if (_selectedAuthorId != null) {
      filtered = filtered.where((card) => card.authorId == _selectedAuthorId);
    }
    if (_selectedSectionId != null) {
      filtered = filtered.where((card) => card.sectionId == _selectedSectionId);
    }

    setState(() {
      _filteredBookTitles = filtered.map((card) => card.title).toList();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreResults();
    }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    // Reset state for a new search
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _totalResults = 0;
      _currentPage = 0;
      _error = null;
    });

    try {
      final paginatedResults = await dbHelper.search(
        _searchController.text,
        _searchType,
        limit: _pageSize,
        offset: 0,
        authorId: _selectedAuthorId,
        sectionId: _selectedSectionId,
      );
      setState(() {
        _searchResults = paginatedResults.results;
        _totalResults = paginatedResults.totalCount;
      });
    } catch (e) {
      setState(() {
        _error = "An error occurred during search: $e";
      });
      print("Search error: $e");
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || _searchResults.length >= _totalResults) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final paginatedResults = await dbHelper.search(
        _searchController.text,
        _searchType,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        authorId: _selectedAuthorId,
        sectionId: _selectedSectionId,
      );
      setState(() {
        _searchResults.addAll(paginatedResults.results);
      });
    } catch (e) {
      // Optionally handle error for subsequent loads
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 600, // Adjust width as needed for desktop dialog
          height: 800, // Adjust height as needed
          decoration: BoxDecoration(
            color: bgColor,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              AppBar(
                title: Text('بحث في الكتب', style: normalStyle(color: Colors.black)),
                backgroundColor: primaryColor,
                automaticallyImplyLeading: false, // No back button
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              _buildSearchBar(),
              _buildFilterDropdowns(),
              _buildFilteredBooksList(), // New widget to show filtered books
              _buildSearchOptions(),
              const Divider(),
              _buildSearchResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredBooksList() {
    if (_filteredBookTitles.isEmpty && (_selectedAuthorId != null || _selectedSectionId != null)) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'لا توجد كتب تطابق هذا الفلتر.',
          style: normalStyle(color: Colors.red),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8.0),
      constraints: const BoxConstraints(maxHeight: 100),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _filteredBookTitles
              .map((title) => Chip(label: Text(title, style: normalStyle(fontSize: 10))))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFilterDropdowns() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(child: _buildAuthorDropdown()),
          const SizedBox(width: 8),
          Expanded(child: _buildSectionDropdown()),
        ],
      ),
    );
  }

  Widget _buildAuthorDropdown() {
    return DropdownButton<String>(
      isExpanded: true,
      value: _selectedAuthorId,
      hint: Text('كل المؤلفين', style: normalStyle(color: Colors.black)),
      onChanged: (String? newValue) {
        setState(() {
          _selectedAuthorId = newValue;
          _updateFilteredBooks();
        });
      },
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('كل المؤلفين', style: normalStyle(color: Colors.black)),
        ),
        ..._allAuthors.map<DropdownMenuItem<String>>((Author author) {
          return DropdownMenuItem<String>(
            value: author.id,
            child: Text(author.name, style: normalStyle(color: Colors.black)),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSectionDropdown() {
    return DropdownButton<String>(
      isExpanded: true,
      value: _selectedSectionId,
      hint: Text('كل الأقسام', style: normalStyle(color: Colors.black)),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSectionId = newValue;
          _updateFilteredBooks();
        });
      },
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('كل الأقسام', style: normalStyle(color: Colors.black)),
        ),
        ..._allSections.map<DropdownMenuItem<String>>((Section section) {
          return DropdownMenuItem<String>(
            value: section.id,
            child: Text(section.title, style: normalStyle(color: Colors.black)),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: normalStyle(color: Colors.black),
              decoration: const InputDecoration(
                hintText: 'ابحث هنا...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<SearchType>(
          title: Text('بحث عادي', style: normalStyle(color: Colors.black)),
          value: SearchType.normalized,
          groupValue: _searchType,
          onChanged: (SearchType? value) {
            setState(() {
              _searchType = value!;
            });
          },
        ),
        RadioListTile<SearchType>(
          title: Text('مطابقة تامة (مع التشكيل)', style: normalStyle(color: Colors.black)),
          value: SearchType.exact,
          groupValue: _searchType,
          onChanged: (SearchType? value) {
            setState(() {
              _searchType = value!;
            });
          },
        ),
        RadioListTile<SearchType>(
          title: Text('بحث بالجذر', style: normalStyle(color: Colors.black)),
          value: SearchType.stemmed,
          groupValue: _searchType,
          onChanged: (SearchType? value) {
            setState(() {
              _searchType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_error != null) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText( 
              _error!,
              style: normalStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_isSearching) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_searchResults.isEmpty) {
      return Expanded(child: Center(child: Text('لا توجد نتائج', style: normalStyle(color: Colors.black))));
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '$_totalResults نتيجة',
              style: normalStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _searchResults.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final result = _searchResults[index];
                return ListTile(
                  title: Text(result.bookName, style: normalStyle(color: Colors.black, fontSize: 14)),
                  subtitle: Text.rich(
                    _highlightSnippet(result.snippet),
                    style: normalStyle(color: Colors.black, fontSize: 12),
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () {
                    widget.onResultTapped(result);
                    Navigator.of(context).pop(); // Close dialog on tap
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _highlightSnippet(String snippet) {
    final List<TextSpan> spans = [];
    final parts = snippet.split(RegExp(r'<b>|</b>'));
    bool isBold = snippet.startsWith('<b>');

    for (final part in parts) {
      if (part.isEmpty) continue;
      spans.add(TextSpan(
        text: part,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isBold ? Colors.red : Colors.black54,
        ),
      ));
      isBold = !isBold;
    }
    return TextSpan(children: spans);
  }
}
