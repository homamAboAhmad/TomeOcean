import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Models/Section.dart';

/// Sections list panel widget
class SectionsListPanel extends StatelessWidget {
  final List<Section> sections;
  final Set<String> selectedSectionIds;
  final Function(String) onSectionToggled;
  final Function() onSelectAllSections;
  final Function() onClearSelection;
  final bool isLoading;

  const SectionsListPanel({
    Key? key,
    required this.sections,
    required this.selectedSectionIds,
    required this.onSectionToggled,
    required this.onSelectAllSections,
    required this.onClearSelection,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أقسام',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }
    
    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الأقسام (${sections.length})', style: mediumStyle()),
              if (selectedSectionIds.isNotEmpty)
                TextButton.icon(
                  icon: Icon(Icons.clear, size: 14),
                  label: Text('إزالة', style: smallStyle()),
                  onPressed: onClearSelection,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sections.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return CheckboxListTile(
                  title: Text('كل الأقسام', style: normalStyle()),
                  value: sections.isNotEmpty &&
                      sections.every((section) =>
                          selectedSectionIds.contains(section.id)),
                  onChanged: (val) => onSelectAllSections(),
                );
              }
              final section = sections[index - 1];
              return CheckboxListTile(
                title: Text(section.title, style: normalStyle()),
                value: selectedSectionIds.contains(section.id),
                onChanged: (val) => onSectionToggled(section.id),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}

