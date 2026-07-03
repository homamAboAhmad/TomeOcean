import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';

class LibrarySearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 5),
          child: SizedBox(
            height: 34,
            child: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            textAlignVertical: TextAlignVertical.center,
            style: normalStyle(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              suffixIcon: LibraryIcon.fromIcon(
                Icons.search,
                size: 20,
                color: LibraryDesignTokens.primary,
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF979D99)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: LibraryDesignTokens.selectedBorder,
                ),
              ),
            ),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}
