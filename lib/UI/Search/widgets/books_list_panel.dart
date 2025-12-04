import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:path/path.dart' as p;

/// Widget that displays a list of books with search and selection capabilities.
/// 
/// This panel allows users to:
/// - Search books by title or author name
/// - Select/deselect books individually or all at once (Ctrl+A)
/// - Add or remove selected books from the search list
class BooksListPanel extends StatefulWidget {
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final TextEditingController searchController;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final List<Author>? authors;
  final Map<String, int>? authorBookCounts;
  final Map<String, String>? authorDeathYears;
  final Function(String)? onAuthorToggled;
  final Map<String, String> bookAuthorMap;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;

  const BooksListPanel({
    Key? key,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.searchController,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    this.authors,
    this.authorBookCounts,
    this.authorDeathYears,
    this.onAuthorToggled,
    this.bookAuthorMap = const {},
    required this.onBooksAdded,
    required this.onBooksRemoved,
  }) : super(key: key);

  @override
  _BooksListPanelState createState() => _BooksListPanelState();
}

class _BooksListPanelState extends State<BooksListPanel> {
  Set<String> _temporarilySelectedBookPaths = {};
  final FocusNode _booksFocusNode = FocusNode();

  @override
  void dispose() {
    _booksFocusNode.dispose();
    super.dispose();
  }

  /// Filters books based on the search query.
  /// 
  /// Searches in both book titles and author names.
  /// Returns a list of books matching the search criteria.
  List<Map<String, dynamic>> _filterBooks(String searchQuery) {
    if (searchQuery.isEmpty) {
      return widget.filteredIndexedBooks;
    }
    
    return widget.filteredIndexedBooks.where((book) {
      final bookPath = book['book_path'] as String;
      final bookTitle = p.basenameWithoutExtension(bookPath).toLowerCase();
      
      String authorName = '';
      if (widget.authors != null) {
        final String? authorId = widget.bookAuthorMap[bookPath] ?? book['authorId'] as String?;
        
        if (authorId != null) {
          final author = widget.authors!.firstWhere(
            (a) => a.id == authorId,
            orElse: () => Author(id: '', name: '', description: ''),
          );
          authorName = author.name.toLowerCase();
        }
      }
      
      return bookTitle.contains(searchQuery) || authorName.contains(searchQuery);
    }).toList();
  }

  /// Gets the author information for a book.
  /// 
  /// Returns a map with 'name' and 'deathYear' keys.
  Map<String, String> _getAuthorInfo(String bookPath, Map<String, dynamic> book) {
    if (widget.authors == null) {
      return {'name': '', 'deathYear': ''};
    }
    
    final String? authorId = widget.bookAuthorMap[bookPath] ?? book['authorId'] as String?;
    
    if (authorId == null) {
      return {'name': '', 'deathYear': ''};
    }
    
    final author = widget.authors!.firstWhere(
      (a) => a.id == authorId,
      orElse: () => Author(id: '', name: '', description: ''),
    );
    
    if (author.id.isEmpty) {
      return {'name': '', 'deathYear': ''};
    }
    
    return {
      'name': author.name,
      'deathYear': author.deathYear ?? widget.authorDeathYears?[author.id] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = widget.searchController.text.toLowerCase();
    final filteredBooks = _filterBooks(searchQuery);
    
    return GestureDetector(
      onTap: () => _booksFocusNode.requestFocus(),
      child: Focus(
        focusNode: _booksFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _handleKeyEvent(event, filteredBooks),
        child: Column(
          children: [
            // Search bar with icons and Select All checkbox
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  // Select All Checkbox
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: filteredBooks.isNotEmpty && 
                             _temporarilySelectedBookPaths.length == filteredBooks.length,
                      tristate: true,
                      onChanged: (val) => _toggleSelectAllBooks(filteredBooks),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.folder, color: Colors.amber, size: 28),
                    onPressed: () {
                      // TODO: Folder action
                    },
                    tooltip: 'المجلدات',
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: Colors.brown, size: 24),
                    onPressed: () {
                      // TODO: Settings
                    },
                    tooltip: 'الإعدادات',
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: 'بحث في أسماء الكتب...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {}); // Rebuild to filter
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${filteredBooks.length} كتاب',
                    style: normalStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            // Books List
            Expanded(
              child: filteredBooks.isEmpty
                  ? Center(child: Text('لا توجد كتب مطابقة', style: normalStyle(color: Colors.grey)))
                  : ListView.separated(
                  itemCount: filteredBooks.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    final bookPath = book['book_path'] as String;
                    final bookName = p.basenameWithoutExtension(bookPath);
                    final isSelected = widget.selectedBooks[bookPath] ?? false;
                    final isTemporarilySelected = _temporarilySelectedBookPaths.contains(bookPath);
                    
                    final authorInfo = _getAuthorInfo(bookPath, book);
                    final authorName = authorInfo['name']!;
                    final deathYear = authorInfo['deathYear']!;
                    
                    return Material(
                      color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isTemporarilySelected) {
                              _temporarilySelectedBookPaths.remove(bookPath);
                            } else {
                              _temporarilySelectedBookPaths.add(bookPath);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isTemporarilySelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _temporarilySelectedBookPaths.add(bookPath);
                                    } else {
                                      _temporarilySelectedBookPaths.remove(bookPath);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bookName,
                                      style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    if (authorName.isNotEmpty)
                                      Text(
                                        '$authorName ${deathYear.isNotEmpty ? "($deathYear)" : ""}',
                                        style: normalStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        
            // Bottom Selection Bar
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_temporarilySelectedBookPaths.isNotEmpty) {
                        widget.onBooksAdded(_temporarilySelectedBookPaths.toList());
                        setState(() => _temporarilySelectedBookPaths.clear());
                      }
                    },
                    icon: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('اختيار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      elevation: 0,
                      side: BorderSide(color: Colors.green.shade200),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_temporarilySelectedBookPaths.isNotEmpty) {
                        widget.onBooksRemoved(_temporarilySelectedBookPaths.toList());
                        setState(() => _temporarilySelectedBookPaths.clear());
                      }
                    },
                    icon: Icon(Icons.remove_circle_outline, size: 18),
                    label: Text('إزالة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles keyboard events for the books list.
  /// 
  /// Supports:
  /// - Ctrl+A: Toggle select all visible books
  /// - Escape: Clear all temporary selections
  /// 
  /// Returns [KeyEventResult.handled] if the event was processed,
  /// [KeyEventResult.ignored] otherwise.
  KeyEventResult _handleKeyEvent(KeyEvent event, List<Map<String, dynamic>> filteredBooks) {
    if (event is KeyDownEvent) {
      if (HardwareKeyboard.instance.isControlPressed && 
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _toggleSelectAllBooks(filteredBooks);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _temporarilySelectedBookPaths.clear());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Toggles selection of all filtered books.
  /// 
  /// If all books are selected, deselects them all.
  /// Otherwise, selects all filtered books.
  void _toggleSelectAllBooks(List<Map<String, dynamic>> filteredBooks) {
    setState(() {
      if (_temporarilySelectedBookPaths.length == filteredBooks.length) {
        _temporarilySelectedBookPaths.clear();
      } else {
        _temporarilySelectedBookPaths = filteredBooks
            .map((book) => book['book_path'] as String)
            .toSet();
      }
    });
  }
}
