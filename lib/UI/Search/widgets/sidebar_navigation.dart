import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';

/// Sidebar navigation widget for search dialog
class SidebarNavigation extends StatelessWidget {
  final String selectedTab;
  final Function(String) onTabSelected;

  const SidebarNavigation({
    Key? key,
    required this.selectedTab,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sidebarTabs = [
      {'id': 'الكتب', 'icon': Icons.library_books, 'label': 'الكتب'},
      {'id': 'التصنيف', 'icon': Icons.category, 'label': 'التصنيف'},
      {'id': 'المؤلفون', 'icon': Icons.person, 'label': 'المؤلفون'},
      {'id': 'فترة', 'icon': Icons.calendar_today, 'label': 'فترة'},
      {'id': 'المفضلة', 'icon': Icons.star, 'label': 'المفضلة'},
      {'id': 'مؤخرا', 'icon': Icons.access_time, 'label': 'مؤخرا'},
      {'id': 'التنزيلات', 'icon': Icons.download, 'label': 'التنزيلات'},
      {'id': 'المجالات', 'icon': Icons.description, 'label': 'المجالات'},
      {'id': 'السجلات', 'icon': Icons.search, 'label': 'السجلات'},
    ];
    
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: sidebarTabs.length,
              itemBuilder: (context, index) {
                final tab = sidebarTabs[index];
                final isSelected = selectedTab == tab['id'];
                return InkWell(
                  onTap: () => onTabSelected(tab['id'] as String),
                  child: Container(
                    color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          color: isSelected ? primaryColor : Colors.grey.shade700,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tab['label'] as String,
                            style: normalStyle(
                              color: isSelected ? primaryColor : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
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
      ),
    );
  }
}

