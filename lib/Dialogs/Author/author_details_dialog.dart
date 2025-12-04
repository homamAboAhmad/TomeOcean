// lib/Dialogs/Author/author_details_dialog.dart
import 'package:flutter/material.dart';
import '../../Models/Author.dart';
import '../../Models/BookCard.dart';
import 'author_details_view_model.dart';
import 'author_details_header.dart';
import 'author_details_info.dart';
import 'author_details_books_list.dart';
import 'author_details_actions.dart';
import 'author_dialog.dart';
import 'author_books_manager_dialog.dart';
import '../BookCard/book_card_dialog.dart';

/// Shows a professional author details dialog
Future<void> showAuthorDetailsDialog(
  BuildContext context,
  String authorId, {
  VoidCallback? onAuthorUpdated,
  VoidCallback? onAuthorDeleted,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AuthorDetailsDialog(
      authorId: authorId,
      onAuthorUpdated: onAuthorUpdated,
      onAuthorDeleted: onAuthorDeleted,
    ),
  );
}

class AuthorDetailsDialog extends StatefulWidget {
  final String authorId;
  final VoidCallback? onAuthorUpdated;
  final VoidCallback? onAuthorDeleted;

  const AuthorDetailsDialog({
    Key? key,
    required this.authorId,
    this.onAuthorUpdated,
    this.onAuthorDeleted,
  }) : super(key: key);

  @override
  State<AuthorDetailsDialog> createState() => _AuthorDetailsDialogState();
}

class _AuthorDetailsDialogState extends State<AuthorDetailsDialog> {
  final _viewModel = AuthorDetailsViewModel();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {});
    try {
      await _viewModel.loadData(widget.authorId);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showErrorSnackBar('حدث خطأ أثناء تحميل البيانات: $e');
      }
    }
  }

  Future<void> _handleEdit() async {
    if (_viewModel.author == null) return;
    
    final updatedAuthor = await showAuthorDialog(context, author: _viewModel.author);
    if (updatedAuthor != null && mounted) {
      await _loadData();
      widget.onAuthorUpdated?.call();
    }
  }

  Future<void> _handleDelete() async {
    if (_viewModel.author == null) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (confirmed != true || !mounted) return;

    setState(() {});
    try {
      await _viewModel.deleteAuthor(widget.authorId);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onAuthorDeleted?.call();
        _showSuccessSnackBar('تم حذف المؤلف بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showErrorSnackBar('حدث خطأ أثناء الحذف: $e');
      }
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المؤلف "${_viewModel.author!.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManageBooks() async {
    if (_viewModel.author == null) return;
    
    await showAuthorBooksManagerDialog(
      context,
      widget.authorId,
      onBooksUpdated: () async {
        await _loadData();
        widget.onAuthorUpdated?.call();
      },
    );
  }

  void _handleBookTap(BookCard book) {
    // TODO: Open book card dialog
    Navigator.of(context).pop();
    // showBookCardDialog will be called from parent
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_viewModel.author == null) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'المؤلف غير موجود',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                AuthorDetailsHeader(
                  authorName: _viewModel.author!.name,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 24),
                AuthorDetailsInfo(author: _viewModel.author!),
                const SizedBox(height: 24),
                Expanded(
                  child: AuthorDetailsBooksList(
                    books: _viewModel.books,
                    onBookTap: _handleBookTap,
                  ),
                ),
                const SizedBox(height: 20),
                AuthorDetailsActions(
                  onEdit: _handleEdit,
                  onDelete: _handleDelete,
                  onManageBooks: _handleManageBooks,
                  isLoading: _viewModel.isDeleting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

