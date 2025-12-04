import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:path/path.dart' as p;

/// Widget that displays sections in a split view with their books.
/// 
/// This panel shows:
/// - Right panel: List of sections with selection capabilities
/// - Left panel: Books belonging to the selected section
/// 
/// Supports keyboard shortcuts:
/// - Ctrl+A: Select all sections/books
/// - Escape: Clear temporary selections
class SectionsListPanel extends StatefulWidget {
  final List<Section> sections;
  final Set<String> selectedSectionIds;
  final String? viewedSectionId;
  final Function(String) onSectionToggled;
  final Function(String) onSectionClicked;

  final bool isLoading;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final List<Map<String, dynamic>> allIndexedBooks;
  final Map<String, bool> selectedBooks;
  final Function(String, bool) onBookSelectionChanged;
  final Function(List<String>) onSectionsAdded;
  final Function(List<String>) onSectionsRemoved;
  final Function(List<String>) onBooksAdded;
  final Function(List<String>) onBooksRemoved;
  final VoidCallback? onSelectAllSections;
  final VoidCallback? onSelectAllBooks;

  const SectionsListPanel({
    Key? key,
    required this.sections,
    required this.selectedSectionIds,
    this.viewedSectionId,
    required this.onSectionToggled,
    required this.onSectionClicked,

    required this.isLoading,
    required this.filteredIndexedBooks,
    required this.allIndexedBooks,
    required this.selectedBooks,
    required this.onBookSelectionChanged,
    required this.onSectionsAdded,
    required this.onSectionsRemoved,
    required this.onBooksAdded,
    required this.onBooksRemoved,
    this.onSelectAllSections,
    this.onSelectAllBooks,
  }) : super(key: key);

  @override
  _SectionsListPanelState createState() => _SectionsListPanelState();
}

class _SectionsListPanelState extends State<SectionsListPanel> {
  Set<String> _temporarilySelectedSectionIds = {};
  Set<String> _temporarilySelectedBookPaths = {};
  List<Map<String, dynamic>> _currentVisibleBooks = [];
  final FocusNode _sectionsFocusNode = FocusNode();
  final FocusNode _booksFocusNode = FocusNode();

  @override
  void dispose() {
    _sectionsFocusNode.dispose();
    _booksFocusNode.dispose();
    super.dispose();
  }

  /// Retrieves books for the currently viewed section.
  /// 
  /// Returns an empty list if no section is selected or if an error occurs.
  /// Filters books to only include those in [widget.allIndexedBooks].
  Future<List<Map<String, dynamic>>> _getBooksForViewedSection() async {
    if (widget.viewedSectionId == null) {
      return [];
    }
    
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      final bookPaths = await metadataDb.getBookPaths(sectionId: widget.viewedSectionId);
      
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
    
    if (widget.sections.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أقسام',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }
    
    return Row(
      children: [
        // Right Panel: Sections list (appears on right in RTL)
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: () => _sectionsFocusNode.requestFocus(),
            child: Focus(
              focusNode: _sectionsFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleSectionsKeyEvent(event),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    // Table header with Select All Checkbox
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: _temporarilySelectedSectionIds.length == widget.sections.length && widget.sections.isNotEmpty,
                              tristate: true,
                              onChanged: (val) => _toggleSelectAllSections(),
                            ),
                          ),
                          Expanded(child: Text('القسم', style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  
                  // Sections List
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.sections.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final section = widget.sections[index];
                        final isSelected = widget.selectedSectionIds.contains(section.id);
                        final isTemporarilySelected = _temporarilySelectedSectionIds.contains(section.id);
                        final isViewed = section.id == widget.viewedSectionId;
                        
                        return Material(
                          color: isViewed 
                              ? Colors.blue.withOpacity(0.1) 
                              : (isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent),
                          child: InkWell(
                            onTap: () => widget.onSectionClicked(section.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Checkbox(
                                      value: isTemporarilySelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _temporarilySelectedSectionIds.add(section.id);
                                          } else {
                                            _temporarilySelectedSectionIds.remove(section.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      section.title,
                                      style: normalStyle(fontSize: 14, fontWeight: isViewed ? FontWeight.bold : FontWeight.normal),
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
                  
                  // Bottom Selection Bar for Sections
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
                            if (_temporarilySelectedSectionIds.isNotEmpty) {
                              widget.onSectionsAdded(_temporarilySelectedSectionIds.toList());
                              setState(() => _temporarilySelectedSectionIds.clear());
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
                            if (_temporarilySelectedSectionIds.isNotEmpty) {
                              widget.onSectionsRemoved(_temporarilySelectedSectionIds.toList());
                              setState(() => _temporarilySelectedSectionIds.clear());
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
        
        // Left Panel: Books list for selected section
          Expanded(
            flex: 1,
            child: widget.viewedSectionId == null
                ? Center(child: Text('اختر قسماً لعرض كتبه', style: normalStyle(color: Colors.grey)))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getBooksForViewedSection(),
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
                        return Center(child: Text('لا توجد كتب لهذا القسم', style: normalStyle(color: Colors.grey)));
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
                                        'كتب القسم (${booksToShow.length})',
                                        style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1),
                          
                          // Books List
                          Expanded(
                            child: Focus(
                              canRequestFocus: true,
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

  /// Handles keyboard events for the sections list.
  /// 
  /// Supports:
  /// - Ctrl+A: Toggle select all sections
  /// - Escape: Clear all temporary section selections
  KeyEventResult _handleSectionsKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          HardwareKeyboard.instance.isControlPressed) {
        _toggleSelectAllSections();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _temporarilySelectedSectionIds.clear());
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

  /// Toggles selection of all sections.
  /// 
  /// If all sections are selected, deselects them all.
  /// Otherwise, selects all sections.
  void _toggleSelectAllSections() {
    setState(() {
      if (_temporarilySelectedSectionIds.length == widget.sections.length) {
        _temporarilySelectedSectionIds.clear();
      } else {
        _temporarilySelectedSectionIds = widget.sections.map((s) => s.id).toSet();
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
