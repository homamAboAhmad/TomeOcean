import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Dialogs/Author/author_dialog.dart';
import 'package:golden_shamela/Services/BookSourceChangeMonitor.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_field.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_sidebar_tabs.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_import_actions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'book_metadata_edit_dialog.dart';
import 'entity_delete_dialog.dart';
import 'library_books_exporter.dart';
import 'library_control_repository.dart';
import 'library_entity_picker_dialog.dart';
import 'section_name_dialog.dart';

part 'library_control_delete_actions.dart';
part 'library_control_bulk_delete.dart';
part 'library_control_export_actions.dart';
part 'library_control_assign_actions.dart';
part 'library_control_state_actions.dart';

Future<void> showLibraryControlDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const LibraryControlDialog(),
    );

class LibraryControlDialog extends StatefulWidget {
  const LibraryControlDialog({super.key});

  @override
  State<LibraryControlDialog> createState() => _LibraryControlDialogState();
}

class _LibraryControlDialogState extends State<LibraryControlDialog> {
  static const _booksTab = 'books';
  static const _authorsTab = 'authors';
  static const _sectionsTab = 'sections';

  final _repo = LibraryControlRepository();
  final _exporter = LibraryBooksExporter();
  final _search = TextEditingController();
  final _checkedBookPaths = <String>{};
  List<LibraryBookItem> _books = [];
  List<LibraryEntityRow> _authors = [];
  List<LibraryEntityRow> _sections = [];
  String _tab = _booksTab;
  String? _selectedBookPath;
  String? _selectedAuthorId;
  String? _selectedSectionId;
  bool _busy = false;
  int? _progressDone;
  int? _progressTotal;
  String? _progressText;
  Timer? _searchDebounce;
  int _reloadSerial = 0;

  @override
  void initState() {
    super.initState();
    this._reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              return this._handleEscapeKey();
            }
            if (event.logicalKey == LogicalKeyboardKey.delete) {
              this._deleteCurrentTab();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SizedBox(
            width: 1180,
            height: 720,
            child: Row(
              children: [
                LibrarySidebarTabs(
                  tabs: const [
                    LibrarySidebarTab(_booksTab, 'الكتب', LibraryIconType.books),
                    LibrarySidebarTab(
                      _sectionsTab,
                      'التصنيف',
                      LibraryIconType.categories,
                    ),
                    LibrarySidebarTab(
                      _authorsTab,
                      'المؤلفون',
                      LibraryIconType.authors,
                    ),
                  ],
                  selectedTab: _tab,
                  onTabSelected: (tab) {
                    setState(() => _tab = tab);
                    this._reload();
                  },
                ),
                Expanded(child: _main()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _main() => Column(
        children: [
          _header(),
          const Divider(height: 1),
          _toolbar(),
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              value: _progressTotal == null || _progressTotal == 0
                  ? null
                  : (_progressDone ?? 0) / _progressTotal!,
            ),
          Expanded(child: _body()),
          _footer(),
        ],
      );

  Widget _header() => SizedBox(
        height: 54,
        child: Row(
          children: [
            IconButton(
              tooltip: 'إغلاق',
              icon: const LibraryIcon(LibraryIconType.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            const LibraryIcon(
              LibraryIconType.control,
              color: LibraryDesignTokens.primary,
            ),
            const SizedBox(width: 8),
            const Text('لوحة التحكم', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 16),
          ],
        ),
      );

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 360,
              child: LibrarySearchField(
                controller: _search,
                hint: _searchHint,
                onChanged: (_) => _scheduleReload(),
              ),
            ),
            const SizedBox(width: 8),
            ..._actions(),
          ],
        ),
      );

  Widget _body() {
    if (_tab == _booksTab) return _booksTable(_books);
    if (_tab == _authorsTab) {
      return LibraryEntitiesTable(
        rows: _authors,
        selectedId: _selectedAuthorId,
        titleHeader: 'المؤلف',
        secondaryHeader: 'الوفاة',
        onSelected: (id) => setState(() => _selectedAuthorId = id),
      );
    }
    return LibraryEntitiesTable(
      rows: _sections,
      selectedId: _selectedSectionId,
      titleHeader: 'التصنيف',
      secondaryHeader: '',
      onSelected: (id) => setState(() => _selectedSectionId = id),
    );
  }

  Widget _booksTable(List<LibraryBookItem> books) => LibraryBooksTable(
        books: books,
        selectedPath: _selectedBookPath,
        favoritePaths: const {},
        checkedPaths: _checkedBookPaths,
        showCheckboxes: true,
        onSelected: (item) => setState(() => _selectedBookPath = item.bookPath),
        onDoubleTap: _editBook,
        onCheckedChanged: (item, value) => setState(() {
          if (value) {
            _checkedBookPaths.add(item.bookPath);
          } else {
            _checkedBookPaths.remove(item.bookPath);
          }
        }),
      );

  Widget _footer() => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerRight,
        child: _progressText == null
            ? Text(
                'المعروض: ${_visibleCount}    المحدد من الكتب: ${_checkedBookPaths.length}',
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_progressText!),
                ],
              ),
      );

  List<Widget> _actions() {
    if (_tab == _booksTab) {
      return [
        _button(Icons.add, 'إضافة كتاب', _importBooks),
        _button(Icons.edit_outlined, 'تعديل البيانات', _editSelectedBook),
        _button(
          Icons.description_outlined,
          'تعديل ملف Word',
          _openSelectedBookSource,
          enabled: _selectedBookPath != null,
        ),
        _button(Icons.delete_outline, 'حذف', _deleteSelectedBooks),
        _button(Icons.ios_share_outlined, 'تصدير', this._exportSelectedBooks),
        _button(
          Icons.person_add_alt_1_outlined,
          'اختيار مؤلف للكتب المحددة',
          this._assignSelectedAuthor,
          enabled: this._hasTargetBooks,
        ),
        _button(
          Icons.category_outlined,
          'اختيار تصنيف للكتب المحددة',
          this._assignSelectedSection,
          enabled: this._hasTargetBooks,
        ),
      ];
    }
    if (_tab == _authorsTab) {
      return [
        _button(Icons.add, 'إضافة مؤلف', _addAuthor),
        _button(Icons.edit_outlined, 'تعديل', _editAuthor),
        _button(Icons.ios_share_outlined, 'تصدير', this._exportAuthorBooks),
        _button(Icons.delete_outline, 'حذف', () => this._deleteAuthor()),
      ];
    }
    return [
      _button(Icons.add, 'إضافة تصنيف', _addSection),
      _button(Icons.edit_outlined, 'تعديل', _editSection),
      _button(Icons.ios_share_outlined, 'تصدير', this._exportSectionBooks),
      _button(Icons.delete_outline, 'حذف', () => this._deleteSection()),
    ];
  }

  Widget _button(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    final iconColor = _busy || !enabled
        ? LibraryDesignTokens.icon.withOpacity(0.35)
        : LibraryDesignTokens.primary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: 40,
          height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            onPressed: _busy || !enabled ? null : onPressed,
            child: LibraryIcon.fromIcon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  Future<void> _importBooks() async {
    if (await LibraryImportActions.pickDocxFiles(context)) await this._reload();
  }

  Future<void> _editSelectedBook() async {
    final item = _selectedBook;
    if (item != null) await _editBook(item);
  }

  Future<void> _editBook(LibraryBookItem item) async {
    final updated = await showBookMetadataEditDialog(
      context,
      item.book,
      bookPath: item.bookPath,
    );
    if (updated == null) return;
    await _repo.saveBook(updated, item.bookPath);
    await this._reload();
  }

  Future<void> _openSelectedBookSource() async {
    final path = _selectedBookPath;
    if (path == null) return;
    if (!await File(path).exists()) {
      _message('ملف Word غير موجود');
      return;
    }
    final opened = await launchUrl(
      Uri.file(path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _message('تعذر فتح ملف Word');
      return;
    }
    BookSourceChangeMonitor.watchBook(path);
  }

  Future<void> _deleteSelectedBooks() async {
    final paths = _checkedBookPaths.isEmpty
        ? [_selectedBookPath].whereType<String>().toList()
        : _checkedBookPaths.toList();
    if (paths.isEmpty || !await _confirm('حذف ${paths.length} كتاب؟')) return;
    final result = await _deleteBooksWithProgress(paths);
    _checkedBookPaths.removeAll(paths);
    await this._reload();
    await _showDeleteResult(result);
  }

  Future<void> _addAuthor() async {
    await showAuthorDialog(context);
    await this._reload();
  }

  Future<void> _editAuthor() async {
    final id = _selectedAuthorId;
    if (id == null) return;
    final author = await _repo.getAuthor(id);
    if (author == null) return;
    await showAuthorDialog(context, author: author);
    await this._reload();
  }

  Future<void> _addSection() async {
    final section = await showSectionNameDialog(context);
    if (section == null) return;
    await _repo.saveSection(section);
    await this._reload();
  }

  Future<void> _editSection() async {
    final id = _selectedSectionId;
    if (id == null) return;
    final section = await _repo.getSection(id);
    if (section == null) return;
    final updated = await showSectionNameDialog(context, section: section);
    if (updated == null) return;
    await _repo.saveSection(updated);
    await this._reload();
  }

}
