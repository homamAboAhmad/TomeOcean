// lib/UI/AuthorsManagement/helpers/dialog_helper.dart
import 'package:flutter/material.dart';
import '../../../Models/Author.dart';
import '../../../Styles/TextSyles.dart';

/// Helper class for showing dialogs
class DialogHelper {
  /// Shows delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
    BuildContext context,
    Author author,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(
              'تأكيد الحذف',
              style: normalStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف المؤلف "${author.name}"؟\n\nسيتم حذف جميع البيانات المرتبطة بهذا المؤلف.',
          textDirection: TextDirection.rtl,
          style: normalStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: normalStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: Text(
              'حذف',
              style: normalStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

