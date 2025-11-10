// lib/ui/dialog_widgets/book_card_edit_mode.dart
import 'package:flutter/material.dart';
import '../../Models/Author.dart';
import '../../Models/Section.dart';

class BookCardEditMode extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  final List<Section> sections;
  final List<Author> authors;
  final String? selectedSectionId;
  final String? selectedAuthorId;

  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<String?> onAuthorChanged;

  const BookCardEditMode({
    Key? key,
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.sections,
    required this.authors,
    required this.selectedSectionId,
    required this.selectedAuthorId,
    required this.onSectionChanged,
    required this.onAuthorChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // قائمة عناصر الـ Dropdown للقسم
    final List<DropdownMenuItem<String>> sectionItems = sections.map((section) {
      return DropdownMenuItem<String>(
        value: section.id,
        child: Text(section.title, textDirection: TextDirection.rtl),
      );
    }).toList();

    // قائمة عناصر الـ Dropdown للمؤلف
    final List<DropdownMenuItem<String>> authorItems = authors.map((author) {
      return DropdownMenuItem<String>(
        value: author.id,
        child: Text(author.name, textDirection: TextDirection.rtl),
      );
    }).toList();

    // إضافة خيار فارغ (اختياري)
    sectionItems.insert(0, const DropdownMenuItem(value: '', child: Text('اختر قسمًا')));
    authorItems.insert(0, const DropdownMenuItem(value: '', child: Text('اختر مؤلفًا')));

    return Form(
      key: formKey,
      child: Column(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: titleCtrl,
            textDirection: TextDirection.rtl,
            enabled: false,
            decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder(), isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'يجب إدخال عنوان الكتاب' : null,
          ),
          const SizedBox(height: 10),
          _buildResponsiveFields(sectionItems, authorItems),
          const SizedBox(height: 10),
          TextFormField(
            controller: descCtrl,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder(), alignLabelWithHint: true),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          Text('اضغط حفظ لحفظ التغييرات أو إلغاء للرجوع.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResponsiveFields(List<DropdownMenuItem<String>> sectionItems, List<DropdownMenuItem<String>> authorItems) {
    return LayoutBuilder(
      builder: (context, constr) {
        final authorField = Expanded(
          child: DropdownButtonFormField<String?>(
            value: selectedAuthorId,
            decoration: const InputDecoration(
              labelText: 'المؤلف',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            hint: const Text('اختر مؤلفًا'),
            items: authorItems,
            onChanged: onAuthorChanged,
            validator: (value) => (value == null || value.isEmpty) ? 'يجب اختيار مؤلف' : null,
          ),
        );

        final sectionField = Expanded(
          child: DropdownButtonFormField<String?>(
            value: selectedSectionId,
            decoration: const InputDecoration(
              labelText: 'القسم',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            hint: const Text('اختر قسمًا'),
            items: sectionItems,
            onChanged: onSectionChanged,
            validator: (value) => (value == null || value.isEmpty) ? 'يجب اختيار قسم' : null,
          ),
        );

        if (constr.maxWidth > 360) {
          return Row(
            textDirection: TextDirection.rtl,
            children: [
              authorField,
              const SizedBox(width: 10),
              sectionField,
            ],
          );
        } else {
          return Column(
            children: [
              authorField,
              const SizedBox(height: 8),
              sectionField,
            ],
          );
        }
      },
    );
  }
}