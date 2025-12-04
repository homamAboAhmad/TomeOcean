// lib/Dialogs/Author/author_details_header.dart
import 'package:flutter/material.dart';
import '../../Styles/AppResourses.dart';
import '../../Styles/TextSyles.dart';

/// Header widget for author details dialog
class AuthorDetailsHeader extends StatelessWidget {
  final String authorName;
  final VoidCallback onClose;

  const AuthorDetailsHeader({
    Key? key,
    required this.authorName,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Text(
            authorName,
            style: normalStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
          onPressed: onClose,
          tooltip: 'إغلاق',
        ),
      ],
    );
  }
}

