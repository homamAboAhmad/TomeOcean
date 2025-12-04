// lib/Dialogs/Author/author_dialog.dart
import 'package:flutter/material.dart';
import '../../Models/Author.dart';
import '../../Styles/TextSyles.dart';
import '../../Styles/AppResourses.dart';
import 'author_dialog_view_model.dart';
import 'author_dialog_header.dart';
import 'author_dialog_form.dart';
import 'author_dialog_actions.dart';

/// Shows a dialog to add or edit an author
Future<Author?> showAuthorDialog(BuildContext context, {Author? author}) {
  return showDialog<Author>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AuthorDialog(author: author),
  );
}

class AuthorDialog extends StatefulWidget {
  final Author? author;
  
  const AuthorDialog({Key? key, this.author}) : super(key: key);

  @override
  State<AuthorDialog> createState() => _AuthorDialogState();
}

class _AuthorDialogState extends State<AuthorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _deathYearCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  
  final _viewModel = AuthorDialogViewModel();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.author != null) {
      _nameCtrl.text = widget.author!.name;
      _deathYearCtrl.text = widget.author!.deathYear ?? '';
      _descriptionCtrl.text = widget.author!.description;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deathYearCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final author = await _viewModel.saveAuthor(
        id: widget.author?.id,
        name: _nameCtrl.text,
        deathYear: _deathYearCtrl.text,
        description: _descriptionCtrl.text,
      );
      
      if (mounted) {
        Navigator.of(context).pop(author);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('حدث خطأ أثناء حفظ المؤلف: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.author != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                textDirection: TextDirection.rtl,
                children: [
                  AuthorDialogHeader(
                    isEditing: isEditing,
                    onClose: _handleCancel,
                  ),
                  const SizedBox(height: 24),
                  AuthorDialogForm(
                    nameController: _nameCtrl,
                    deathYearController: _deathYearCtrl,
                    descriptionController: _descriptionCtrl,
                  ),
                  const SizedBox(height: 24),
                  AuthorDialogActions(
                    isEditing: isEditing,
                    isSaving: _isSaving,
                    onCancel: _handleCancel,
                    onSave: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


