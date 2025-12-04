// lib/UI/AuthorsManagement/widgets/author_stat_card.dart
import 'package:flutter/material.dart';
import '../../../Styles/TextSyles.dart';

/// Widget for displaying statistics card
class AuthorStatCard extends StatelessWidget {
  final String label;
  final String value;

  const AuthorStatCard({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              value,
              style: normalStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              label,
              style: normalStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

