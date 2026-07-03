// lib/Dialogs/Author/author_dialog_form.dart
import 'package:flutter/material.dart';
import '../../Styles/TextSyles.dart';
import 'author_death_date_field.dart';

class AuthorDialogForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController deathYearController;
  final TextEditingController descriptionController;

  const AuthorDialogForm({
    super.key,
    required this.nameController,
    required this.deathYearController,
    required this.descriptionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        _nameField(),
        const SizedBox(height: 20),
        AuthorDeathDateField(controller: deathYearController),
        const SizedBox(height: 20),
        _descriptionField(),
      ],
    );
  }

  Widget _nameField() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: nameController,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: normalStyle(fontSize: 14, fontWeight: FontWeight.w400),
        decoration: _fieldDecoration(label: 'اسم المؤلف *'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'يجب إدخال اسم المؤلف';
          }
          return null;
        },
      ),
    );
  }

  Widget _descriptionField() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: descriptionController,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: normalStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ).copyWith(height: 1.5),
        maxLines: 4,
        decoration: _fieldDecoration(label: 'الوصف', alignLabelWithHint: true),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: normalStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: normalStyle(
        fontSize: 12,
        color: Colors.red,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
