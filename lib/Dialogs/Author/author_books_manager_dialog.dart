// lib/Dialogs/Author/author_books_manager_dialog.dart
import 'package:flutter/material.dart';
import '../../Models/BookCard.dart';
import '../../Styles/TextSyles.dart';
import '../../Styles/AppResourses.dart';
import 'author_books_manager_view_model.dart';
import 'author_books_manager_list.dart';

/// Shows a dialog to manage author's books
Future<void> showAuthorBooksManagerDialog(
  BuildContext context,
  String authorId, {
  VoidCallback? onBooksUpdated,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AuthorBooksManagerDialog(
      authorId: authorId,
      onBooksUpdated: onBooksUpdated,
    ),
  );
}

class AuthorBooksManagerDialog extends StatefulWidget {
  final String authorId;
  final VoidCallback? onBooksUpdated;

  const AuthorBooksManagerDialog({
    Key? key,
    required this.authorId,
    this.onBooksUpdated,
  }) : super(key: key);

  @override
  State<AuthorBooksManagerDialog> createState() =>
      _AuthorBooksManagerDialogState();
}

class _AuthorBooksManagerDialogState extends State<AuthorBooksManagerDialog> {
  final _viewModel = AuthorBooksManagerViewModel();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {});
    try {
      await _viewModel.loadData(widget.authorId);
      if (mounted) {
        setState(() {});
        _onSearchChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showErrorSnackBar('حدث خطأ أثناء تحميل البيانات: $e');
      }
    }
  }

  void _onSearchChanged() {
    _viewModel.filterBooks(_searchController.text);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleBookToggle(String bookId, bool isSelected) {
    _viewModel.toggleBookSelection(bookId, isSelected);
    setState(() {});
  }

  Future<void> _handleLink() async {
    if (_viewModel.selectedBookIds.isEmpty) return;

    setState(() {});
    try {
      await _viewModel.linkBooks(widget.authorId);
      if (mounted) {
        setState(() {});
        widget.onBooksUpdated?.call();
        _showSuccessSnackBar('تم ربط الكتب بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showErrorSnackBar('حدث خطأ أثناء الربط: $e');
      }
    }
  }

  Future<void> _handleUnlink() async {
    if (_viewModel.getBooksToUnlink().isEmpty) return;

    setState(() {});
    try {
      await _viewModel.unlinkBooks(widget.authorId);
      if (mounted) {
        setState(() {});
        widget.onBooksUpdated?.call();
        _showSuccessSnackBar('تم فك ربط الكتب بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showErrorSnackBar('حدث خطأ أثناء فك الربط: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      'إدارة كتب المؤلف',
                      style: normalStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: normalStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث في الكتب...',
                        hintStyle: normalStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                                tooltip: 'مسح البحث',
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: AuthorBooksManagerList(
                    books: _viewModel.filteredBooks,
                    selectedBookIds: _viewModel.selectedBookIds,
                    authorBookIds: _viewModel.authorBookIds,
                    onBookToggle: _handleBookToggle,
                    isLoading: _viewModel.isLoading,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  textDirection: TextDirection.rtl,
                  children: [
                    TextButton(
                      onPressed:
                          _viewModel.isSaving ||
                              _viewModel.selectedBookIds.isEmpty
                          ? null
                          : _handleUnlink,
                      child: Text(
                        'فك الربط',
                        style: normalStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          _viewModel.isSaving ||
                              _viewModel.selectedBookIds.isEmpty
                          ? null
                          : _handleLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _viewModel.isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'ربط',
                              style: normalStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
