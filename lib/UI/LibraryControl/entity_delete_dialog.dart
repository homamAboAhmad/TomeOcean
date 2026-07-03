import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum EntityDeleteChoice {
  unlinkBooks,
  deleteBooks,
}

Future<EntityDeleteChoice?> showEntityDeleteDialog(
  BuildContext context, {
  required String entityLabel,
  required String entityName,
  required int linkedBooksCount,
}) {
  return showDialog<EntityDeleteChoice>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(dialogContext);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            Navigator.pop(dialogContext, _confirmChoice(linkedBooksCount));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: Text('حذف $entityLabel'),
          content: Text(_message(entityLabel, entityName, linkedBooksCount)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            if (linkedBooksCount > 0)
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, EntityDeleteChoice.unlinkBooks),
                child: const Text('فك الربط فقط'),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () =>
                  Navigator.pop(dialogContext, _confirmChoice(linkedBooksCount)),
              child: Text(linkedBooksCount == 0 ? 'حذف' : 'حذف الكتب أيضًا'),
            ),
          ],
        ),
      ),
    ),
  );
}

EntityDeleteChoice _confirmChoice(int linkedBooksCount) {
  return linkedBooksCount == 0
      ? EntityDeleteChoice.unlinkBooks
      : EntityDeleteChoice.deleteBooks;
}

String _message(String label, String name, int count) {
  if (count == 0) return 'هل تريد حذف $label "$name"؟';
  return '$label "$name" مرتبط بـ $count كتاب. اختر هل تريد فك الربط فقط أم حذف الكتب التابعة أيضًا.';
}
