import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:path/path.dart' as p;

/// Widget that displays authors in a split view with their books.
/// 
/// This panel shows:
/// - Right panel: List of authors with selection capabilities
/// - Left panel: Books belonging to the selected author
/// 
/// Supports keyboard shortcuts:
/// - Ctrl+A: Select all authors/books
/// - Escape: Clear temporary selections
class AuthorsTablePanel extends StatefulWidget {
  final List<Author> authors;
  final Set<String> selectedAuthorIds;
  final String? viewedAuthorId;
  final Function(String) onAuthorToggled;
  final Function(String) onAuthorClicked;

  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final bool isLoading;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final Function(List<String>) onAuthorsAdded;
  final Function(List<String>) onAuthorsRemoved;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;
  final VoidCallback? onSelectAllAuthors;
  final VoidCallback? onSelectAllBooks;

  const AuthorsTablePanel({
    Key? key,
    required this.authors,
    required this.selectedAuthorIds,
    this.viewedAuthorId,
    required this.onAuthorToggled,
    required this.onAuthorClicked,

    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.isLoading,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.onAuthorsAdded,
    required this.onAuthorsRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    this.onSelectAllAuthors,
    this.onSelectAllBooks,
  }) : super(key: key);

  @override
  _AuthorsTablePanelState createState() => _AuthorsTablePanelState();
}

class _AuthorsTablePanelState extends State<AuthorsTablePanel> {
  Set<String> _temporarilySelectedAuthorIds = {};
  Set<String> _temporarilySelectedBookPaths = {};
  List<Map<String, dynamic>> _currentVisibleBooks = [];
  final FocusNode _authorsFocusNode = FocusNode();
  final FocusNode _booksFocusNode = FocusNode();

  @override
  void dispose() {
    _authorsFocusNode.dispose();
    _booksFocusNode.dispose();
    super.dispose();
  }

  /// Retrieves books for the currently viewed author.
  /// 
  /// Returns an empty list if no author is selected or if an error occurs.
  /// Filters books to only include those in [widget.allIndexedBooks].
  Future<List<Map<String, dynamic>>> _getBooksForViewedAuthor() async {
    if (widget.viewedAuthorId == null) {
      return [];
    }
    
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      final bookPaths = await metadataDb.getBookPaths(authorId: widget.viewedAuthorId);
      
      return widget.allIndexedBooks.where((book) {
        final bookPath = book['book_path'] as String;
        final bookBasename = p.basename(bookPath);
        
        return bookPaths.any((dbPath) {
          return dbPath == bookPath || p.basename(dbPath) == bookBasename;
        });
      }).toList();
    } catch (e) {
      // Error handling: Return empty list instead of crashing
      // In production, consider logging to a proper logging service
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (widget.authors.isEmpty) {
      return Center(
        child: Text(
          'لا توجد مؤلفين',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }
    
    return Row(
      children: [
        // Right Panel: Authors table (appears on right in RTL)
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: () => _authorsFocusNode.requestFocus(),
            child: Focus(
              focusNode: _authorsFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleAuthorsKeyEvent(event),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    // Table Header with Select All Checkbox
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: _temporarilySelectedAuthorIds.length == widget.authors.length && widget.authors.isNotEmpty,
                              tristate: true,
                              onChanged: (val) => _toggleSelectAllAuthors(),
                            ),
                          ),
                          Expanded(flex: 3, child: Text('المؤلف', style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('الوفاة', style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('الكتب', style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  Divider(height: 1),
                  
                  // Authors List
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.authors.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final author = widget.authors[index];
                        final isSelected = widget.selectedAuthorIds.contains(author.id);
                        final isTemporarilySelected = _temporarilySelectedAuthorIds.contains(author.id);
                        final isViewed = author.id == widget.viewedAuthorId;
                        
                        return Material(
                          color: isViewed 
                              ? Colors.blue.withOpacity(0.1) 
                              : (isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent),
                          child: InkWell(
                            onTap: () => widget.onAuthorClicked(author.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Checkbox(
                                      value: isTemporarilySelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _temporarilySelectedAuthorIds.add(author.id);
                                          } else {
                                            _temporarilySelectedAuthorIds.remove(author.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      author.name,
                                      style: normalStyle(fontSize: 14, fontWeight: isViewed ? FontWeight.bold : FontWeight.normal),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      author.deathYear ?? widget.authorDeathYears[author.id] ?? '',
                                      style: normalStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${widget.authorBookCounts[author.id] ?? 0}',
                                      style: normalStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  
                  // Bottom Selection Bar for Authors
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
                            if (_temporarilySelectedAuthorIds.isNotEmpty) {
                              widget.onAuthorsAdded(_temporarilySelectedAuthorIds.toList());
                              setState(() => _temporarilySelectedAuthorIds.clear());
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
                            if (_temporarilySelectedAuthorIds.isNotEmpty) {
                              widget.onAuthorsRemoved(_temporarilySelectedAuthorIds.toList());
                              setState(() => _temporarilySelectedAuthorIds.clear());
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
          ),
        ),
        ),
        
        // Left Panel: Books list for selected author
          Expanded(
            flex: 1,
            child: widget.viewedAuthorId == null
                ? Center(child: Text('اختر مؤلفاً لعرض كتبه', style: normalStyle(color: Colors.grey)))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getBooksForViewedAuthor(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('حدث خطأ أثناء تحميل الكتب', style: normalStyle(color: Colors.red)));
                      }
                      
                      final booksToShow = snapshot.data ?? [];
                      _currentVisibleBooks = booksToShow;
                      
                      if (booksToShow.isEmpty) {
                        return Center(child: Text('لا توجد كتب لهذا المؤلف', style: normalStyle(color: Colors.grey)));
                      }
                      
                      return GestureDetector(
                        onTap: () => _booksFocusNode.requestFocus(),
                        child: Focus(
                          focusNode: _booksFocusNode,
                          onKeyEvent: (node, event) => _handleBooksKeyEvent(event),
                          child: Column(
                            children: [
                              // Header with Select All Checkbox
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                color: Colors.grey.shade100,
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Checkbox(
                                        value: _temporarilySelectedBookPaths.length == booksToShow.length && booksToShow.isNotEmpty,
                                        tristate: true,
                                        onChanged: (val) => _toggleSelectAllBooks(booksToShow),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'كتب المؤلف (${booksToShow.length})',
                                        style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1),
                              
                              // Books List
                              Expanded(
                                child: ListView.separated(
                              itemCount: booksToShow.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final book = booksToShow[index];
                                final bookPath = book['book_path'] as String;
                                final bookName = p.basenameWithoutExtension(bookPath);
                                final isSelected = widget.selectedBooks[bookPath] ?? false;
                                final isTemporarilySelected = _temporarilySelectedBookPaths.contains(bookPath);
                                
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
                                            child: Text(
                                              bookName,
                                              style: normalStyle(fontSize: 14),
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
                          
                          // Bottom Selection Bar for Books
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
                    },
                  ),
        ),
      ],
    );
  }

  /// Handles keyboard events for the authors list.
  /// 
  /// Supports:
  /// - Ctrl+A: Toggle select all authors
  /// - Escape: Clear all temporary author selections
  KeyEventResult _handleAuthorsKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          HardwareKeyboard.instance.isControlPressed) {
        _toggleSelectAllAuthors();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _temporarilySelectedAuthorIds.clear());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Handles keyboard events for the books list.
  /// 
  /// Supports:
  /// - Ctrl+A: Toggle select all visible books
  /// - Escape: Clear all temporary book selections
  KeyEventResult _handleBooksKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          HardwareKeyboard.instance.isControlPressed) {
        _toggleSelectAllBooks(_currentVisibleBooks);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _temporarilySelectedBookPaths.clear());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Toggles selection of all authors.
  /// 
  /// If all authors are selected, deselects them all.
  /// Otherwise, selects all authors.
  void _toggleSelectAllAuthors() {
    setState(() {
      if (_temporarilySelectedAuthorIds.length == widget.authors.length) {
        _temporarilySelectedAuthorIds.clear();
      } else {
        _temporarilySelectedAuthorIds = widget.authors.map((a) => a.id).toSet();
      }
    });
  }

  /// Toggles selection of all books in the current view.
  /// 
  /// If all books are selected, deselects them all.
  /// Otherwise, selects all visible books.
  void _toggleSelectAllBooks(List<Map<String, dynamic>> booksToShow) {
    setState(() {
      if (_temporarilySelectedBookPaths.length == booksToShow.length) {
        _temporarilySelectedBookPaths.clear();
      } else {
        _temporarilySelectedBookPaths = booksToShow
            .map((b) => b['book_path'] as String)
            .toSet();
      }
    });
  }

}
