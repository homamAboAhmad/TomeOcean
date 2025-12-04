// lib/Dialogs/Author/author_details_info.dart
import 'package:flutter/material.dart';
import '../../Models/Author.dart';
import '../../Styles/TextSyles.dart';

/// Widget for displaying author information
class AuthorDetailsInfo extends StatelessWidget {
  final Author author;

  const AuthorDetailsInfo({
    Key? key,
    required this.author,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        if (author.deathYear != null && author.deathYear!.isNotEmpty) ...[
          _buildInfoRow(
            label: 'تاريخ الوفاة (هجري)',
            value: author.deathYear!,
          ),
          const SizedBox(height: 20),
        ],
        if (author.description.isNotEmpty) ...[
          _buildDescriptionSection(),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Text(
          label,
          style: normalStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: normalStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            'الوصف',
            style: normalStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          author.description,
          style: normalStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w400,
          ).copyWith(height: 1.6),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}

