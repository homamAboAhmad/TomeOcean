// lib/ui/book_card_dialog.dart
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';

import '../../Helpers/AuthorStorage.dart';
import '../../Helpers/SectionStorage.dart';
import '../../Models/BookCard.dart';
import '../../Models/Section.dart';
import 'book_card_edit_mode.dart';
import 'book_card_header.dart';
import 'book_card_view_mode.dart';

Future<BookCard?> showBookCardDialog(BuildContext context, BookCard book) {
  return showDialog<BookCard>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => BookCardDialog(book: book),
  );
}

class BookCardDialog extends StatefulWidget {
  final BookCard book;
  const BookCardDialog({Key? key, required this.book}) : super(key: key);

  @override
  State<BookCardDialog> createState() => _BookCardDialogState();
}

class _BookCardDialogState extends State<BookCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedSectionId;
  String? _selectedAuthorId;
  bool _isEditing = false;

  final _sectionStorage = SectionStorage();
  final _authorStorage = AuthorStorage();
  List<Section> _sections = [];
  List<Author> _authors = [];
  String _authorName = '';
  String _sectionTitle = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _initControllers();
  }

  Future<void> _loadData() async {
    _sections = _sectionStorage.getSections();
    _authors = _authorStorage.getAuthors();

    // جلب اسم القسم والمؤلف بناءً على المعرفات
    final section = _sectionStorage.getSectionById(widget.book.sectionId);
    final author = AuthorStorage.getAuthorById(widget.book.authorId);

    setState(() {
      _sectionTitle = section?.title ?? 'غير محدد';
      _authorName = author?.name ?? 'غير محدد';
      _selectedSectionId = widget.book.sectionId;
      _selectedAuthorId = widget.book.authorId;
    });
  }

  void _initControllers() {
    _titleCtrl.text = widget.book.title;
    _descCtrl.text = widget.book.description;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.book.copyWith(
      title: _titleCtrl.text.trim(),
      sectionId: _selectedSectionId ?? '',
      authorId: _selectedAuthorId ?? '',
      description: _descCtrl.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }

  void _cancelEdit() {
    setState(() {
      _initControllers();
      _selectedSectionId = widget.book.sectionId;
      _selectedAuthorId = widget.book.authorId;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookCardHeader(
                isEditing: _isEditing,
                onToggleEdit: _toggleEdit,
                onSave: _save,
                onCancel: _cancelEdit,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: _isEditing
                    ? BookCardEditMode(
                  key: const ValueKey('editMode'),
                  formKey: _formKey,
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                  sections: _sections,
                  authors: _authors,
                  selectedSectionId: _selectedSectionId,
                  selectedAuthorId: _selectedAuthorId,
                  onSectionChanged: (newId) {
                    setState(() {
                      _selectedSectionId = newId;
                    });
                  },
                  onAuthorChanged: (newId) {
                    setState(() {
                      _selectedAuthorId = newId;
                    });
                  },
                )
                    : BookCardViewMode(
                  key: const ValueKey('viewMode'),
                  book: widget.book,
                  sectionTitle: _sectionTitle,
                  authorName: _authorName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}