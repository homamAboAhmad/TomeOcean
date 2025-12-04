// lib/ui/book_card_dialog.dart
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';

import '../../Models/BookCard.dart';
import '../../Models/Section.dart';
import '../Author/author_dialog.dart';
import 'book_card_dialog_controller.dart';
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
  final _controller = BookCardDialogController();

  String? _selectedSectionId;
  String? _selectedAuthorId;
  bool _isEditing = false;

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
    final data = await _controller.loadDialogData(widget.book);
    setState(() {
      _sections = data.sections;
      _authors = data.authors;
      _sectionTitle = data.sectionTitle;
      _authorName = data.authorName;
      _selectedSectionId = data.selectedSectionId;
      _selectedAuthorId = data.selectedAuthorId;
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
    final updated = _controller.createUpdatedBookCard(
      originalBook: widget.book,
      title: _titleCtrl.text,
      sectionId: _selectedSectionId,
      authorId: _selectedAuthorId,
      description: _descCtrl.text,
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

  Future<void> _addNewAuthor() async {
    final newAuthor = await showAuthorDialog(context);
    if (newAuthor != null) {
      final updatedAuthors = await _controller.reloadAuthors();
      setState(() {
        _authors = updatedAuthors;
        _selectedAuthorId = newAuthor.id;
      });
    }
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
                  onAddNewAuthor: _addNewAuthor,
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