// lib/Dialogs/Author/author_details_actions.dart
import 'package:flutter/material.dart';
import '../../Styles/AppResourses.dart';
import '../../Styles/TextSyles.dart';

/// Action buttons widget for author details dialog
class AuthorDetailsActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onManageBooks;
  final bool isLoading;

  const AuthorDetailsActions({
    Key? key,
    this.onEdit,
    this.onDelete,
    this.onManageBooks,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      textDirection: TextDirection.rtl,
      children: [
        if (onManageBooks != null)
          TextButton.icon(
            onPressed: isLoading ? null : onManageBooks,
            icon: Icon(Icons.library_books, size: 18, color: primaryColor),
            label: Text(
              'إدارة الكتب',
              style: normalStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        if (onManageBooks != null && (onEdit != null || onDelete != null))
          const SizedBox(width: 8),
        if (onEdit != null)
          TextButton.icon(
            onPressed: isLoading ? null : onEdit,
            icon: Icon(Icons.edit, size: 18, color: Colors.black87),
            label: Text(
              'تعديل',
              style: normalStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textDirection: TextDirection.rtl,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        if (onEdit != null && onDelete != null)
          const SizedBox(width: 8),
        if (onDelete != null)
          TextButton.icon(
            onPressed: isLoading ? null : onDelete,
            icon: Icon(Icons.delete, size: 18, color: Colors.black87),
            label: Text(
              'حذف',
              style: normalStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textDirection: TextDirection.rtl,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }
}

