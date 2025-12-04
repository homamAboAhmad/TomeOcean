// lib/Dialogs/Author/author_dialog_form.dart
import 'package:flutter/material.dart';
import '../../Styles/TextSyles.dart';

/// Form fields widget for author dialog
class AuthorDialogForm extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController deathYearController;
  final TextEditingController descriptionController;

  const AuthorDialogForm({
    Key? key,
    required this.nameController,
    required this.deathYearController,
    required this.descriptionController,
  }) : super(key: key);

  @override
  State<AuthorDialogForm> createState() => _AuthorDialogFormState();
}

class _AuthorDialogFormState extends State<AuthorDialogForm> {
  @override
  void initState() {
    super.initState();
    widget.deathYearController.addListener(_updateSuffix);
  }

  @override
  void dispose() {
    widget.deathYearController.removeListener(_updateSuffix);
    super.dispose();
  }

  void _updateSuffix() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        // Name field
        Directionality(
          textDirection: TextDirection.rtl,
          child: TextFormField(
            controller: widget.nameController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: normalStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'اسم المؤلف *',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يجب إدخال اسم المؤلف';
            }
            return null;
          },
          ),
        ),
        const SizedBox(height: 20),
        
        // Death year field
        Directionality(
          textDirection: TextDirection.rtl,
          child: TextFormField(
            controller: widget.deathYearController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: normalStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'تاريخ الوفاة (هجري)',
              labelStyle: normalStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            hintText: 'مثال: 545 أو 545 هـ أو اتركه فارغاً',
            hintStyle: normalStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
            ),
            helperText: 'يمكن إدخال سنة هجرية (مثل: 545 أو 545 هـ) أو "غير معروف" أو اتركه فارغاً',
            helperStyle: normalStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
            errorStyle: normalStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: widget.deathYearController.text.isNotEmpty &&
                    widget.deathYearController.text.trim().toLowerCase() != 'غير معروف' &&
                    int.tryParse(widget.deathYearController.text
                        .trim()
                        .replaceAll('هـ', '')
                        .replaceAll('ه', '')
                        .replaceAll(' ', '')) != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1.0,
                      child: Text(
                        'هـ',
                        style: normalStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  )
                : null,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Optional field
            }
            final trimmedValue = value.trim().toLowerCase();
            // Allow "غير معروف"
            if (trimmedValue == 'غير معروف') {
              return null;
            }
            // Remove "هـ" or "ه" if present and check if it's a number
            final cleanedValue = trimmedValue
                .replaceAll('هـ', '')
                .replaceAll('ه', '')
                .replaceAll(' ', '');
            // Check if it's a valid number (year)
            if (cleanedValue.isEmpty) {
              return 'يجب إدخال سنة هجرية أو "غير معروف"';
            }
            final year = int.tryParse(cleanedValue);
            if (year == null) {
              return 'يجب إدخال سنة هجرية صحيحة (مثل: 545) أو "غير معروف"';
            }
            // Check if year is reasonable (between 1 and 2000)
            if (year < 1 || year > 2000) {
              return 'السنة الهجرية يجب أن تكون بين 1 و 2000';
            }
            return null;
          },
          ),
        ),
        const SizedBox(height: 20),
        
        // Description field
        Directionality(
          textDirection: TextDirection.rtl,
          child: TextFormField(
            controller: widget.descriptionController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: normalStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ).copyWith(height: 1.5),
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'الوصف',
              labelStyle: normalStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            alignLabelWithHint: true,
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
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          ),
        ),
      ],
    );
  }
}

