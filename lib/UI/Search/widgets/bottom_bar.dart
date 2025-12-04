import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';  // Add this for primaryColor

/// Bottom bar widget for search dialog.
/// 
/// Displays action buttons for deselecting items and ignoring selections.
/// Selection is handled directly in the panels, so only deselect buttons are shown here.
class SearchBottomBar extends StatelessWidget {
  final String selectedTab;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final Map<String, bool> selectedBooks;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final Function() onDeselectAllBooks;
  final Function() onDeselectAllAuthors;
  final Function()? onDeselectAllSections;
  final Function()? onIgnore;
  final int totalAuthors;

  const SearchBottomBar({
    Key? key,
    required this.selectedTab,
    required this.selectedAuthorIds,
    required this.selectedSectionIds,
    required this.selectedBooks,
    required this.filteredIndexedBooks,
    required this.onDeselectAllBooks,
    required this.onDeselectAllAuthors,
    this.onDeselectAllSections,
    this.onIgnore,
    required this.totalAuthors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Count selected items based on current tab
    final selectedBooksCount = selectedBooks.values.where((v) => v).length;
    final totalFilteredBooks = filteredIndexedBooks.length;
    
    return Container(

      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: _buildButtonsForCurrentTab(
          selectedBooksCount: selectedBooksCount,
          totalFilteredBooks: totalFilteredBooks,
        ),
      ),
    );
  }

  List<Widget> _buildButtonsForCurrentTab({
    required int selectedBooksCount,
    required int totalFilteredBooks,
  }) {
    final buttons = <Widget>[];
    
    switch (selectedTab) {
      case 'الكتب':
        // Books tab buttons - only show deselect if there are selected books
        if (selectedBooksCount > 0) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: onDeselectAllBooks,
              icon: Icon(Icons.close, size: 16, color: Colors.red),
              label: Text('إلغاء الكتب المحددة', style: smallStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );
        }
        break;
        
      case 'المؤلفون':
        // Authors tab buttons - only show deselect if there are selected authors
        if (selectedAuthorIds.isNotEmpty) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: onDeselectAllAuthors,
              icon: Icon(Icons.close, size: 16, color: Colors.red),
              label: Text('إلغاء المؤلفين المحددين', style: smallStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );
        }
        break;
        
      case 'التصنيف':
        // Sections tab buttons - only show deselect if there are selected sections
        if (selectedSectionIds.isNotEmpty && onDeselectAllSections != null) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: onDeselectAllSections,
              icon: Icon(Icons.close, size: 16, color: Colors.red),
              label: Text('إلغاء الأقسام المحددة', style: smallStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );
        }
        break;
    }
    
    // Add ignore button at the end
    if (onIgnore != null) {
      buttons.add(SizedBox(width: 8));
      buttons.add(
        ElevatedButton.icon(
          onPressed: onIgnore,
          icon: Icon(Icons.remove, size: 16, color: Colors.blue),
          label: Text('تجاهل', style: smallStyle(color: Colors.blue)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }
    
    return buttons;
  }
}

