import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';

class LibrarySidebarTab {
  final String id;
  final String label;
  final LibraryIconType icon;

  const LibrarySidebarTab(this.id, this.label, this.icon);
}

class LibrarySidebarTabs extends StatelessWidget {
  final List<LibrarySidebarTab> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  const LibrarySidebarTabs({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxHeight < 600;
        return Container(
          width: compact ? 78 : LibraryDesignTokens.sidebarWidth,
          decoration: BoxDecoration(
            color: LibraryDesignTokens.sidebar,
            border: const Border(
              left: BorderSide(color: LibraryDesignTokens.divider),
            ),
          ),
          child: ListView(
            children: tabs.map((tab) {
          final selected = tab.id == selectedTab;
          return InkWell(
            onTap: () => onTabSelected(tab.id),
            child: Container(
              constraints: BoxConstraints(minHeight: compact ? 74 : 86),
              padding: EdgeInsets.symmetric(vertical: compact ? 6 : 9),
              decoration: BoxDecoration(
                color: selected
                    ? LibraryDesignTokens.selected
                    : Colors.transparent,
                border: selected
                    ? Border.all(color: LibraryDesignTokens.selectedBorder)
                    : null,
              ),
              child: Column(
                children: [
                  LibraryIcon(
                    tab.icon,
                    size: compact ? 26 : 30,
                    color: selected
                        ? LibraryDesignTokens.primary
                        : LibraryDesignTokens.icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: AppUiFonts.style(
                      AppFontRole.bookLists,
                      TextStyle(fontSize: compact ? 11 : 12),
                      sizeOffset: compact ? -3 : -2,
                    ),
                  ),
                ],
              ),
            ),
          );
            }).toList(),
          ),
        );
      },
    );
  }
}
