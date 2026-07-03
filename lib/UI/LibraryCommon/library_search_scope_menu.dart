import 'package:flutter/material.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';

String libraryBookSearchHint(String scope, {String? context}) {
  final target = switch (scope) {
    'title' => 'اسم الكتاب',
    'title_author' => 'اسم الكتاب أو المؤلف',
    'full' => 'اسم الكتاب أو المؤلف أو بطاقة الكتاب',
    _ => 'اسم الكتاب أو المؤلف',
  };
  final prefix = context?.trim() ?? '';
  return prefix.isEmpty ? 'يمكن البحث بجزء من $target' : '$prefix: $target';
}

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
        icon: const LibraryIcon(LibraryIconType.settings),
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
          child: Text('اسم الكتاب واسم المؤلف وبطاقة الكتاب'),
        ),
        ],
      ),
    );
  }
}
