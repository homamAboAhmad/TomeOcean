import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';  // Add this for primaryColor

/// Bottom bar widget for search dialog
class SearchBottomBar extends StatelessWidget {
  final String selectedTab;
  final Set<String> selectedAuthorIds;
  final Set<String> selectedSectionIds;
  final Map<String, bool> selectedBooks;
  final List<Map<String, dynamic>> filteredIndexedBooks;
  final Function() onDeselectAllBooks;
  final Function() onSelectAllBooks;
  final Function() onDeselectAllAuthors;
  final Function() onSelectAllAuthors;
  final Function()? onDeselectAllSections;
  final Function()? onSelectAllSections;
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
    required this.onSelectAllBooks,
    required this.onDeselectAllAuthors,
    required this.onSelectAllAuthors,
    this.onDeselectAllSections,
    this.onSelectAllSections,
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
        // Books tab buttons
        buttons.add(
          ElevatedButton.icon(
            onPressed: onSelectAllBooks,
            icon: Icon(Icons.check, size: 16, color: Colors.green),
            label: Text('اختيار الكتب المحددة', style: smallStyle(color: Colors.green)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        );
        if (selectedBooksCount > 0) {
          buttons.add(SizedBox(width: 8));
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
        // Authors tab buttons
        buttons.add(
          ElevatedButton.icon(
            onPressed: onSelectAllAuthors,
            icon: Icon(Icons.check, size: 16, color: Colors.green),
            label: Text('اختيار المؤلفين المحددين', style: smallStyle(color: Colors.green)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        );
        if (selectedAuthorIds.isNotEmpty) {
          buttons.add(SizedBox(width: 8));
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
        // Sections tab buttons
        if (onSelectAllSections != null) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: onSelectAllSections,
              icon: Icon(Icons.check, size: 16, color: Colors.green),
              label: Text('اختيار الأقسام المحددة', style: smallStyle(color: Colors.green)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );
        }
        if (selectedSectionIds.isNotEmpty && onDeselectAllSections != null) {
          buttons.add(SizedBox(width: 8));
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

