import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:path/path.dart' as p;

/// Books list panel widget
class BooksListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final Function() onSelectAll;
  final Function() onInvertSelection;
  final TextEditingController searchController;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final List<Author>? authors;
  final Map<String, int>? authorBookCounts;
  final Map<String, String>? authorDeathYears;
  final Function(String)? onAuthorToggled;

  const BooksListPanel({
    Key? key,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.onSelectAll,
    required this.onInvertSelection,
    required this.searchController,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    this.authors,
    this.authorBookCounts,
    this.authorDeathYears,
    this.onAuthorToggled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter books based on search query
    final searchQuery = searchController.text.toLowerCase();
    final filteredBooks = searchQuery.isEmpty
        ? filteredIndexedBooks
        : filteredIndexedBooks.where((book) {
            final bookPath = book['book_path'] as String;
            final bookTitle = p.basenameWithoutExtension(bookPath).toLowerCase();
            return bookTitle.contains(searchQuery);
          }).toList();
    
    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Column(
      children: [
        // Search bar with icons
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.settings, size: 20),
                onPressed: () {
                  // TODO: Settings
                },
              ),
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'يمكن البحث بجزء من اسم الكتاب أو المؤلف أو كليهما',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: normalStyle(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 20),
                onPressed: () {
                  // TODO: Edit
                },
              ),
            ],
          ),
        ),
        // Dual column view: Authors (left) and Books (right)
        Expanded(
          child: Row(
            children: [
              // Authors column (left)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: _buildAuthorsList(),
                ),
              ),
              // Books column (right)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: _buildBooksList(filteredBooks, searchQuery),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildAuthorsList() {
    if (authors == null || authors!.isEmpty) {
      return Center(
        child: Text(
          'لا توجد مؤلفين',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: authors!.length,
      itemBuilder: (context, index) {
        final author = authors![index];
        final authorId = author.id;
        final authorName = author.name;
        final bookCount = (authorBookCounts?[authorId] ?? 0);
        final deathYear = authorDeathYears?[authorId] ?? '';
        final isSelected = selectedAuthorIds.contains(authorId);
        
        return InkWell(
          onTap: () => onAuthorToggled?.call(authorId),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              deathYear.isNotEmpty 
                  ? '$authorName (ت $deathYear م)'
                  : authorName,
              style: normalStyle(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBooksList(List<Map<String, dynamic>> filteredBooks, String searchQuery) {
    if (filteredBooks.isEmpty) {
      return Center(
        child: Text(
          searchQuery.isNotEmpty
              ? 'لا توجد كتب تطابق البحث'
              : 'لا توجد كتب',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        final bookPath = book['book_path'] as String;
        final bookTitle = p.basenameWithoutExtension(bookPath);
        final isSelected = selectedBooks[bookPath] ?? false;
        
        return InkWell(
          onTap: () => onBookSelectionChanged(bookPath, !isSelected),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (val) => onBookSelectionChanged(bookPath, val!),
                ),
                Icon(Icons.book, size: 18, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookTitle,
                    style: normalStyle(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

