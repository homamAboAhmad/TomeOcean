import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_type_filter_group.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_scope_menu.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_field.dart';

class LibraryBooksToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchScope;
  final bool showCard;
  final VoidCallback onToggleCard;
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;
  final ValueChanged<String> onSearchScopeChanged;
  final ValueChanged<String> onSearchChanged;

  const LibraryBooksToolbar({
    super.key,
    required this.searchController,
    required this.searchScope,
    required this.showCard,
    required this.onToggleCard,
    required this.onPickFiles,
    required this.onPickFolder,
    required this.onSearchScopeChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ToolbarSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: TextDirection.ltr,
        children: [
          _ToolbarIcon(
            tooltip: 'بطاقة الكتاب',
            customIcon: const LibraryIcon(LibraryIconType.bookCard),
            onPressed: onToggleCard,
          ),
          _AddBooksMenu(
            onPickFiles: onPickFiles,
            onPickFolder: onPickFolder,
          ),
          LibrarySearchScopeMenu(
            selectedScope: searchScope,
            onSelected: onSearchScopeChanged,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LibrarySearchField(
              controller: searchController,
              hint: 'يمكن البحث بجزء من اسم الكتاب أو المؤلف أو كليهما',
              onChanged: onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarySectionsToolbar extends StatelessWidget {
  final Set<String> selectedTypes;
  final bool includeMatchingPrinted;
  final bool includeNotMatchingPrinted;
  final ValueChanged<String> onTypeToggled;
  final void Function(List<String> types, bool selected) onGroupChanged;
  final ValueChanged<bool> onMatchingPrintedChanged;
  final ValueChanged<bool> onNotMatchingPrintedChanged;

  const LibrarySectionsToolbar({
    super.key,
    required this.selectedTypes,
    required this.includeMatchingPrinted,
    required this.includeNotMatchingPrinted,
    required this.onTypeToggled,
    required this.onGroupChanged,
    required this.onMatchingPrintedChanged,
    required this.onNotMatchingPrintedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: LibraryDesignTokens.surface,
        border: const Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              flex: 6,
              child: LibraryTypeFilterGroup(
              label: 'المطبوعات',
              types: BookMetadataOptions.printedTypes,
              selectedTypes: selectedTypes,
              onGroupChanged: (selected) {
                onGroupChanged(BookMetadataOptions.printedTypes, selected);
              },
              onTypeToggled: onTypeToggled,
              trailingChecks: [
                _CheckFilter(
                  label: 'يوافق المطبوع',
                  value: includeMatchingPrinted,
                  onChanged: onMatchingPrintedChanged,
                ),
                _CheckFilter(
                  label: 'لا يوافق المطبوع',
                  value: includeNotMatchingPrinted,
                  onChanged: onNotMatchingPrintedChanged,
                ),
              ],
            ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: LibraryTypeFilterGroup(
              label: 'غير المطبوعات',
              types: BookMetadataOptions.unprintedTypes,
              selectedTypes: selectedTypes,
              onGroupChanged: (selected) {
                onGroupChanged(BookMetadataOptions.unprintedTypes, selected);
              },
              onTypeToggled: onTypeToggled,
            ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> buildLibraryBookActions({
  required bool showCard,
  required VoidCallback onToggleCard,
  required VoidCallback onPickFiles,
  required VoidCallback onPickFolder,
}) {
  return [
    _ToolbarIcon(
      tooltip: 'بطاقة الكتاب',
      customIcon: const LibraryIcon(LibraryIconType.bookCard),
      onPressed: onToggleCard,
    ),
    _AddBooksMenu(onPickFiles: onPickFiles, onPickFolder: onPickFolder),
  ];
}

class _ToolbarSurface extends StatelessWidget {
  final Widget child;

  const _ToolbarSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LibraryDesignTokens.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: LibraryDesignTokens.surface,
        border: const Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: child,
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final String tooltip;
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback onPressed;

  const _ToolbarIcon({
    required this.tooltip,
    this.icon,
    this.customIcon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        icon: customIcon ?? Icon(icon, color: LibraryDesignTokens.icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _AddBooksMenu extends StatelessWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;

  const _AddBooksMenu({
    required this.onPickFiles,
    required this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: PopupMenuButton<String>(
        tooltip: 'إضافة كتب',
        padding: EdgeInsets.zero,
        icon: const LibraryIcon(LibraryIconType.addBook),
        onSelected: (value) =>
            value == 'files' ? onPickFiles() : onPickFolder(),
        itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'files',
          child: ListTile(
            leading: Icon(Icons.note_add_outlined),
            title: Text('إضافة كتاب'),
          ),
        ),
        PopupMenuItem(
          value: 'folder',
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('إضافة مجلد'),
          ),
        ),
        ],
      ),
    );
  }
}

class _SearchScopeMenu extends StatelessWidget {
  final String selectedScope;
  final ValueChanged<String> onSelected;

  const _SearchScopeMenu({
    required this.selectedScope,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'نطاق البحث',
      icon: Icon(Icons.settings, color: Colors.brown.shade700),
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
    );
  }
}

class _CheckFilter extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: (next) => onChanged(next ?? false),
          ),
          Text(label),
        ],
      ),
    );
  }
}
