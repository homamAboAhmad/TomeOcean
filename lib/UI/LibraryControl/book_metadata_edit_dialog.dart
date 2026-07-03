import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Services/BookSourceFingerprint.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';

Future<BookCard?> showBookMetadataEditDialog(
  BuildContext context,
  BookCard book, {
  String? bookPath,
}) {
  return showDialog<BookCard>(
    context: context,
    builder: (_) => _BookMetadataEditDialog(book: book, bookPath: bookPath),
  );
}

class _BookMetadataEditDialog extends StatefulWidget {
  final BookCard book;
  final String? bookPath;

  const _BookMetadataEditDialog({required this.book, this.bookPath});

  @override
  State<_BookMetadataEditDialog> createState() =>
      _BookMetadataEditDialogState();
}

class _BookMetadataEditDialogState extends State<_BookMetadataEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _publisher = TextEditingController();
  final _edition = TextEditingController();
  final _pageCount = TextEditingController();
  final _savedSourceModified = TextEditingController();
  final _db = BooksMetadataDatabase();
  List<Author> _authors = [];
  List<Section> _sections = [];
  String? _authorId;
  String? _sectionId;
  String? _bookType;
  bool _matchesPrinted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _title.text = book.title;
    _description.text = book.description;
    _publisher.text = book.publisher;
    _edition.text = book.edition;
    _pageCount.text = book.pageCount;
    _authorId = book.authorId.isEmpty ? null : book.authorId;
    _sectionId = book.sectionId.isEmpty ? null : book.sectionId;
    _bookType = BookMetadataOptions.normalizeType(book.bookType);
    _matchesPrinted = book.matchesPrinted;
    _loadLists();
    _loadSavedSourceModified();
  }

  Future<void> _loadSavedSourceModified() async {
    final path = widget.bookPath;
    if (path == null) return;
    final db = await _db.database;
    final rows = await db.query(
      'books',
      columns: ['source_hash'],
      where: 'book_path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final modified = BookSourceFingerprint.modifiedAt(
      rows.first['source_hash']?.toString(),
    );
    if (modified == null) return;
    _savedSourceModified.text = _formatDate(modified);
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _loadLists() async {
    final authors = await _db.getAuthors();
    final sections = await _db.getSections(limit: 10000);
    authors.sort(_compareAuthorsByDeathYear);
    if (!mounted) return;
    setState(() {
      _authors = authors;
      _sections = sections;
      if (!_authors.any((author) => author.id == _authorId)) _authorId = null;
      if (!_sections.any((section) => section.id == _sectionId)) {
        _sectionId = null;
      }
      _loading = false;
    });
  }

  int _compareAuthorsByDeathYear(Author a, Author b) {
    final death = AuthorDeathDateParser.compare(a.deathYear, b.deathYear);
    if (death != 0) return death;
    return a.name.compareTo(b.name);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _publisher.dispose();
    _edition.dispose();
    _pageCount.dispose();
    _savedSourceModified.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: SizedBox(
            width: 620,
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 14),
            _textField(_title, 'اسم الكتاب', required: true),
            const SizedBox(height: 10),
            _authorField(),
            const SizedBox(height: 10),
            _sectionField(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _typeField()),
                const SizedBox(width: 10),
                Expanded(
                  child: CheckboxListTile(
                    value: _matchesPrinted,
                    onChanged: (value) =>
                        setState(() => _matchesPrinted = value ?? false),
                    title: const Text('موافق للمطبوع'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _textField(_publisher, 'الناشر')),
                const SizedBox(width: 10),
                Expanded(child: _textField(_edition, 'الطبعة')),
                const SizedBox(width: 10),
                SizedBox(width: 120, child: _textField(_pageCount, 'الصفحات')),
              ],
            ),
            const SizedBox(height: 10),
            _textField(_description, 'نبذة عن الكتاب', maxLines: 3),
            const SizedBox(height: 10),
            _textField(
              _savedSourceModified,
              'آخر تعديل محفوظ لملف Word',
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          tooltip: 'إغلاق',
          onPressed: () => Navigator.of(context).pop(),
          icon: const LibraryIcon(LibraryIconType.close),
        ),
        const Spacer(),
        const Text(
          'تعديل بيانات الكتاب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'مطلوب' : null
          : null,
    );
  }

  Widget _authorField() {
    return DropdownButtonFormField<String>(
      value: _authorId,
      decoration: const InputDecoration(
        labelText: 'المؤلف',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('غير محدد')),
        ..._authors.map(
          (author) => DropdownMenuItem(
            value: author.id,
            child: Text(author.name),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _authorId = value),
    );
  }

  Widget _sectionField() {
    return DropdownButtonFormField<String>(
      value: _sectionId,
      decoration: const InputDecoration(
        labelText: 'التصنيف',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('غير محدد')),
        ..._sections.map(
          (section) => DropdownMenuItem(
            value: section.id,
            child: Text(section.title),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _sectionId = value),
    );
  }

  Widget _typeField() {
    return DropdownButtonFormField<String>(
      value: _bookType,
      decoration: const InputDecoration(
        labelText: 'النوع',
        border: OutlineInputBorder(),
      ),
      items: BookMetadataOptions.bookTypes
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(BookMetadataOptions.typeLabel(type)),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _bookType = value),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const LibraryIcon(LibraryIconType.save),
          label: const Text('حفظ'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(widget.book.copyWith(
          title: _title.text.trim(),
          authorId: _authorId ?? '',
          sectionId: _sectionId ?? '',
          description: _description.text.trim(),
          bookType: _bookType,
          matchesPrinted: _matchesPrinted,
          publisher: _publisher.text.trim(),
          edition: _edition.text.trim(),
          pageCount: _pageCount.text.trim(),
        ));
  }
}
