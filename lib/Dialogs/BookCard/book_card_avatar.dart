// lib/ui/dialog_widgets/book_cover_avatar.dart
import 'package:flutter/material.dart';

class BookCoverAvatar extends StatelessWidget {
  final String title;

  const BookCoverAvatar({Key? key, required this.title}) : super(key: key);

  String _getInitials(String title) {
    if (title.trim().isEmpty) return '؟';
    final parts = title.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    } else {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(title);
    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.blueGrey.shade100,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}