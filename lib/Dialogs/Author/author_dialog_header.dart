// lib/Dialogs/Author/author_dialog_header.dart
import 'package:flutter/material.dart';
import '../../Styles/TextSyles.dart';

/// Header widget for author dialog
class AuthorDialogHeader extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onClose;

  const AuthorDialogHeader({
    Key? key,
    required this.isEditing,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            isEditing ? 'تعديل مؤلف' : 'إضافة مؤلف جديد',
            style: normalStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
          onPressed: onClose,
          tooltip: 'إغلاق',
        ),
      ],
    );
  }
}
