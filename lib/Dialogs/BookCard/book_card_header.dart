// lib/ui/dialog_widgets/book_card_header.dart
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

class BookCardHeader extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  const BookCardHeader({
    Key? key,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Text(
            'معلومات الكتاب',
            style: normalStyle(fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
        ),
        if (!isEditing) ...[
          IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit), onPressed: onToggleEdit),
        ] else ...[
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.undo),
            label:  Text('إلغاء',style: normalStyle()),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.check),
            label:  Text('حفظ',style: normalStyle(),),
            style: ElevatedButton.styleFrom(elevation: 0),
          ),
        ],
        const SizedBox(width: 6),
        IconButton(tooltip: 'إغلاق', icon: const Icon(Icons.close), onPressed: onClose),
      ],
    );
  }
}