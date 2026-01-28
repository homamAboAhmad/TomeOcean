// lib/UI/AuthorsManagement/authors_management_screen.dart
import 'package:flutter/material.dart';
import '../../Models/Author.dart';
import '../../Dialogs/Author/author_dialog.dart';
import '../../Dialogs/Author/author_details_dialog.dart';
import '../../Styles/TextSyles.dart';
import '../../Styles/AppResourses.dart';
import 'authors_management_view_model.dart';
import 'widgets/author_stat_card.dart';
import 'widgets/author_card.dart';
import 'helpers/snackbar_helper.dart';
import 'helpers/dialog_helper.dart';

/// Professional screen for managing authors (add, edit, delete, view details)
class AuthorsManagementScreen extends StatefulWidget {
  const AuthorsManagementScreen({Key? key}) : super(key: key);

  @override
  State<AuthorsManagementScreen> createState() =>
      _AuthorsManagementScreenState();
}

class _AuthorsManagementScreenState extends State<AuthorsManagementScreen> {
  final _viewModel = AuthorsManagementViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAuthors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthors() async {
    setState(() {});
    try {
      await _viewModel.loadAuthors();
      if (mounted) {
        setState(() {});
        _onSearchChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        SnackbarHelper.showError(context, 'حدث خطأ أثناء تحميل المؤلفين: $e');
      }
    }
  }

  void _onSearchChanged() {
    _viewModel.filterAuthors(_searchController.text);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleAddAuthor() async {
    final newAuthor = await showAuthorDialog(context);
    if (newAuthor != null) {
      await _loadAuthors();
    }
  }

  Future<void> _handleEditAuthor(Author author) async {
    final updatedAuthor = await showAuthorDialog(context, author: author);
    if (updatedAuthor != null) {
      await _loadAuthors();
    }
  }

  Future<void> _handleDeleteAuthor(Author author) async {
    final confirmed = await DialogHelper.showDeleteConfirmation(
      context,
      author,
    );
    if (confirmed != true || !mounted) return;

    setState(() {});
    try {
      await _viewModel.deleteAuthor(author.id);
      await _loadAuthors();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'تم حذف المؤلف بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        SnackbarHelper.showError(context, 'حدث خطأ أثناء حذف المؤلف: $e');
      }
    }
  }

  Future<void> _handleViewDetails(String authorId) async {
    await showAuthorDetailsDialog(
      context,
      authorId,
      onAuthorUpdated: () => _loadAuthors(),
      onAuthorDeleted: () => _loadAuthors(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'إدارة المؤلفين',
              style: normalStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Statistics and Search Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: AuthorStatCard(
                        label: 'إجمالي المؤلفين',
                        value: '${_viewModel.allAuthors.length}',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AuthorStatCard(
                        label: 'إجمالي الكتب',
                        value: '${_viewModel.getTotalBooksCount()}',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AuthorStatCard(
                        label: 'نتائج البحث',
                        value: '${_viewModel.filteredAuthors.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Search bar
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
                        hintText: 'ابحث في المؤلفين...',
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
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Authors list
          Expanded(
            child: _viewModel.isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 24),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'جاري تحميل المؤلفين...',
                            style: normalStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  )
                : _viewModel.filteredAuthors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 24),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'لا توجد مؤلفين'
                                : 'لا توجد نتائج للبحث',
                            style: normalStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged();
                            },
                            child: Text(
                              'مسح البحث',
                              style: normalStyle(
                                fontSize: 14,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _viewModel.filteredAuthors.length,
                    itemBuilder: (context, index) {
                      final author = _viewModel.filteredAuthors[index];
                      final bookCount =
                          _viewModel.authorBookCounts[author.id] ?? 0;
                      return AuthorCard(
                        author: author,
                        bookCount: bookCount,
                        onTap: () => _handleViewDetails(author.id),
                        onViewDetails: () => _handleViewDetails(author.id),
                        onEdit: () => _handleEditAuthor(author),
                        onDelete: () => _handleDeleteAuthor(author),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _handleAddAuthor,
            icon: Icon(Icons.add_rounded, size: 22, color: Colors.white),
            label: Text(
              'إضافة مؤلف',
              style: normalStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textDirection: TextDirection.rtl,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
