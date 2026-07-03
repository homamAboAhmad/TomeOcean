import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/Section.dart';

Future<Section?> showSectionNameDialog(
  BuildContext context, {
  Section? section,
}) async {
  final controller = TextEditingController(text: section?.title ?? '');
  final result = await showDialog<Section>(
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
            _submitSectionName(dialogContext, controller, section);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: Text(section == null ? 'إضافة تصنيف' : 'تعديل تصنيف'),
          content: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            onSubmitted: (_) =>
                _submitSectionName(dialogContext, controller, section),
            decoration: const InputDecoration(labelText: 'اسم التصنيف'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  _submitSectionName(dialogContext, controller, section),
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}

void _submitSectionName(
  BuildContext dialogContext,
  TextEditingController controller,
  Section? section,
) {
  final title = controller.text.trim();
  if (title.isEmpty) return;
  Navigator.pop(dialogContext, Section(id: section?.id, title: title));
}
