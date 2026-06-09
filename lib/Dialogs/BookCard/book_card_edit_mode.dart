// lib/ui/dialog_widgets/book_card_edit_mode.dart
import 'package:flutter/material.dart';
import '../../Models/BookMetadataOptions.dart';
import '../../Models/Author.dart';
import '../../Models/Section.dart';

class BookCardEditMode extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController publisherCtrl;
  final TextEditingController editionCtrl;
  final TextEditingController pageCountCtrl;

  final List<Section> sections;
  final List<Author> authors;
  final String? selectedSectionId;
  final String? selectedAuthorId;
  final String? selectedBookType;
  final bool matchesPrinted;

  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<String?> onAuthorChanged;
  final ValueChanged<String?> onBookTypeChanged;
  final ValueChanged<bool> onMatchesPrintedChanged;
  final VoidCallback? onAddNewAuthor;

  const BookCardEditMode({
    Key? key,
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.publisherCtrl,
    required this.editionCtrl,
    required this.pageCountCtrl,
    required this.sections,
    required this.authors,
    required this.selectedSectionId,
    required this.selectedAuthorId,
    required this.selectedBookType,
    required this.matchesPrinted,
    required this.onSectionChanged,
    required this.onAuthorChanged,
    required this.onBookTypeChanged,
    required this.onMatchesPrintedChanged,
    this.onAddNewAuthor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // قائمة عناصر الـ Dropdown للقسم
    final List<DropdownMenuItem<String?>> sectionItems = sections.map((section) {
      return DropdownMenuItem<String?>(
        value: section.id,
        child: Text(section.title, textDirection: TextDirection.rtl),
      );
    }).toList();

    // قائمة عناصر الـ Dropdown للمؤلف
    final List<DropdownMenuItem<String?>> authorItems = authors.map((author) {
      return DropdownMenuItem<String?>(
        value: author.id,
        child: Text(author.name, textDirection: TextDirection.rtl),
      );
    }).toList();

    // إضافة خيار فارغ (اختياري)
    sectionItems.insert(0, const DropdownMenuItem<String?>(value: '', child: Text('اختر قسمًا')));
    authorItems.insert(0, const DropdownMenuItem<String?>(value: '', child: Text('اختر مؤلفًا')));

    return Form(
      key: formKey,
      child: Column(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: titleCtrl,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'يجب إدخال عنوان الكتاب' : null,
          ),
          const SizedBox(height: 10),
          _buildResponsiveFields(sectionItems, authorItems),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedBookType,
            decoration: const InputDecoration(
              labelText: 'نوع الكتاب',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: BookMetadataOptions.bookTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(BookMetadataOptions.typeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: onBookTypeChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: matchesPrinted,
                  onChanged: (v) => onMatchesPrintedChanged(v ?? false),
                  title: const Text('موافق للمطبوع'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildOptionalFields(),
          const SizedBox(height: 10),
          TextFormField(
            controller: descCtrl,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'الوصف',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          Text('اضغط حفظ لحفظ التغييرات أو إلغاء للرجوع.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionalFields() {
    return LayoutBuilder(
      builder: (context, constr) {
        final publisher = TextFormField(
          controller: publisherCtrl,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'الناشر',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
        final edition = TextFormField(
          controller: editionCtrl,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'الطبعة',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
        final pages = TextFormField(
          controller: pageCountCtrl,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'عدد الصفحات',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
        if (constr.maxWidth > 420) {
          return Row(children: [
            Expanded(child: publisher),
            const SizedBox(width: 8),
            Expanded(child: edition),
            const SizedBox(width: 8),
            Expanded(child: pages),
          ]);
        }
        return Column(children: [
          publisher,
          const SizedBox(height: 8),
          edition,
          const SizedBox(height: 8),
          pages,
        ]);
      },
    );
  }

  Widget _buildResponsiveFields(
    List<DropdownMenuItem<String?>> sectionItems,
    List<DropdownMenuItem<String?>> authorItems,
  ) {
    return LayoutBuilder(
      builder: (context, constr) {
        final authorField = Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
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
              ),
              if (onAddNewAuthor != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'إضافة مؤلف جديد',
                  onPressed: onAddNewAuthor,
                  iconSize: 24,
                ),
              ],
            ],
        );

        final sectionField = DropdownButtonFormField<String?>(
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
        );

        if (constr.maxWidth > 360) {
          return Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(child: authorField),
              const SizedBox(width: 10),
              Expanded(child: sectionField),
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
