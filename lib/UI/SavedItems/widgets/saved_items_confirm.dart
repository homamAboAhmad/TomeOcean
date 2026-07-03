import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

Future<bool> confirmSavedItemAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: mediumStyle(fontSize: 16)),
      content: Text(message, style: normalStyle(fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('إلغاء', style: normalStyle(fontSize: 12)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'تأكيد',
            style: normalStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
