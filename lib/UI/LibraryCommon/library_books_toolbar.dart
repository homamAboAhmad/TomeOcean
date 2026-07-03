import 'package:flutter/material.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';
import 'library_search_field.dart';
import 'library_search_scope_menu.dart';

class LibraryBooksToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchScope;
  final bool showCard;
  final VoidCallback onToggleCard;
  final VoidCallback? onPickFiles;
  final VoidCallback? onPickFolder;
  final VoidCallback? onPickParts;
  final bool allBooksSelected;
  final int? visibleBookCount;
  final VoidCallback? onToggleAllBooks;
  final ValueChanged<String> onSearchScopeChanged;
  final ValueChanged<String> onSearchChanged;

  const LibraryBooksToolbar({
    super.key,
    required this.searchController,
    required this.searchScope,
    required this.showCard,
    required this.onToggleCard,
    required this.onSearchScopeChanged,
    required this.onSearchChanged,
    this.onPickFiles,
    this.onPickFolder,
    this.onPickParts,
    this.allBooksSelected = false,
    this.visibleBookCount,
    this.onToggleAllBooks,
  });

  @override
  Widget build(BuildContext context) {
    return _ToolbarSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: TextDirection.ltr,
        children: [
          if (onToggleAllBooks != null)
            _SelectAllBooksButton(
              allSelected: allBooksSelected,
              onToggleAll: onToggleAllBooks!,
            ),
          _ToolbarIcon(
            tooltip: 'بطاقة الكتاب',
            customIcon: const LibraryIcon(LibraryIconType.bookCard),
            active: showCard,
            onPressed: onToggleCard,
          ),
          if (onPickFiles != null && onPickFolder != null)
            _AddBooksMenu(
              onPickFiles: onPickFiles!,
              onPickFolder: onPickFolder!,
              onPickParts: onPickParts,
            ),
          LibrarySearchScopeMenu(
            selectedScope: searchScope,
            onSelected: onSearchScopeChanged,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LibrarySearchField(
              controller: searchController,
              hint: libraryBookSearchHint(searchScope),
              onChanged: onSearchChanged,
            ),
          ),
          if (visibleBookCount != null) ...[
            const SizedBox(width: 8),
            Text('${visibleBookCount!} كتاب'),
          ],
        ],
      ),
    );
  }
}

List<Widget> buildLibraryBookActions({
  required bool showCard,
  required VoidCallback onToggleCard,
  VoidCallback? onPickFiles,
  VoidCallback? onPickFolder,
  VoidCallback? onPickParts,
}) {
  return [
    _ToolbarIcon(
      tooltip: 'بطاقة الكتاب',
      customIcon: const LibraryIcon(LibraryIconType.bookCard),
      active: showCard,
      onPressed: onToggleCard,
    ),
    if (onPickFiles != null && onPickFolder != null)
      _AddBooksMenu(
        onPickFiles: onPickFiles,
        onPickFolder: onPickFolder,
        onPickParts: onPickParts,
      ),
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
      decoration: const BoxDecoration(
        color: LibraryDesignTokens.surface,
        border: Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: child,
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final String tooltip;
  final Widget customIcon;
  final bool active;
  final VoidCallback onPressed;

  const _ToolbarIcon({
    required this.tooltip,
    required this.customIcon,
    required this.active,
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
        style: active
            ? IconButton.styleFrom(backgroundColor: LibraryDesignTokens.header)
            : null,
        icon: customIcon,
        onPressed: onPressed,
      ),
    );
  }
}

class _AddBooksMenu extends StatelessWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;
  final VoidCallback? onPickParts;

  const _AddBooksMenu({
    required this.onPickFiles,
    required this.onPickFolder,
    this.onPickParts,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: PopupMenuButton<String>(
        tooltip: 'إضافة كتب',
        padding: EdgeInsets.zero,
        icon: const LibraryIcon(LibraryIconType.addBook),
        onSelected: (value) {
          if (value == 'files') {
            onPickFiles();
          } else if (value == 'parts') {
            onPickParts?.call();
          } else {
            onPickFolder();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'files',
            child: ListTile(
              leading: LibraryIcon.fromIcon(Icons.note_add_outlined),
              title: Text('إضافة كتاب'),
            ),
          ),
          if (onPickParts != null)
            PopupMenuItem(
              value: 'parts',
              child: ListTile(
                leading: LibraryIcon.fromIcon(Icons.library_books_outlined),
                title: Text('إضافة كتاب من عدة أجزاء'),
              ),
            ),
          PopupMenuItem(
            value: 'folder',
            child: ListTile(
              leading: LibraryIcon.fromIcon(Icons.create_new_folder_outlined),
              title: Text('إضافة مجلد'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectAllBooksButton extends StatelessWidget {
  final bool allSelected;
  final VoidCallback onToggleAll;

  const _SelectAllBooksButton({
    required this.allSelected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'تحديد كل الكتب الظاهرة',
      child: SizedBox.square(
        dimension: 38,
        child: Checkbox(
          value: allSelected,
          tristate: true,
          onChanged: (_) => onToggleAll(),
        ),
      ),
    );
  }
}
