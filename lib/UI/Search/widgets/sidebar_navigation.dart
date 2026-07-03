import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

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
      {'id': 'مؤخرا', 'icon': Icons.access_time, 'label': 'مؤخراً'},
      {'id': 'التنزيلات', 'icon': Icons.download, 'label': 'التنزيلات'},
      {'id': 'المجالات', 'icon': Icons.description, 'label': 'المجالات'},
      {'id': 'السجلات', 'icon': Icons.search, 'label': 'السجلات'},
    ];
    
    return Container(
      color: mutedColor,
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
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? organicHighlightColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppChrome.radius),
                      border: isSelected ? Border.all(color: borderColor) : null,
                    ),
                    child: Row(
                      children: [
                        LibraryIcon.fromIcon(
                          tab['icon'] as IconData,
                          color: isSelected ? actionColor : accentColor.withOpacity(0.72),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tab['label'] as String,
                            style: normalStyle(
                              color: isSelected ? primaryColor : accentColor,
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

