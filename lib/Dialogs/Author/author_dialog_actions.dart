// lib/Dialogs/Author/author_dialog_actions.dart
import 'package:flutter/material.dart';
import '../../Styles/TextSyles.dart';
import '../../Styles/AppResourses.dart';

/// Action buttons widget for author dialog
class AuthorDialogActions extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const AuthorDialogActions({
    Key? key,
    required this.isEditing,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      textDirection: TextDirection.rtl,
      children: [
        TextButton(
          onPressed: isSaving ? null : onCancel,
          child: Text(
            'إلغاء',
            style: normalStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textDirection: TextDirection.rtl,
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  isEditing ? 'حفظ التعديلات' : 'إضافة',
                  style: normalStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
        ),
      ],
    );
  }
}

