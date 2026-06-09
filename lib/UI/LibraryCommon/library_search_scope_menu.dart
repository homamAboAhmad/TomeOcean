import 'package:flutter/material.dart';
import 'library_design_tokens.dart';

class LibrarySearchScopeMenu extends StatelessWidget {
  final String selectedScope;
  final ValueChanged<String> onSelected;

  const LibrarySearchScopeMenu({
    super.key,
    required this.selectedScope,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: PopupMenuButton<String>(
        tooltip: 'نطاق البحث',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.settings, color: LibraryDesignTokens.icon),
        initialValue: selectedScope,
        onSelected: onSelected,
        itemBuilder: (_) => const [
        PopupMenuItem(value: 'title', child: Text('اسم الكتاب')),
        PopupMenuItem(
          value: 'title_author',
          child: Text('اسم الكتاب واسم المؤلف'),
        ),
        PopupMenuItem(
          value: 'full',
          child: Text('اسم الكتاب واسم المؤلف والبطاقة'),
        ),
        ],
      ),
    );
  }
}
