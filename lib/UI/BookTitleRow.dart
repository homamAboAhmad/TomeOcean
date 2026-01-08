import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import '../Utils/TxtUtils.dart';
import 'package:google_fonts/google_fonts.dart';

class BookTitleRow extends StatefulWidget {
  final String title;
  final bool isChoosed;
  final Function() onClose;
  final Function() onTab;

  const BookTitleRow({
    required this.title,
    required this.isChoosed,
    required this.onClose,
    required this.onTab,
    super.key,
  });

  @override
  State<BookTitleRow> createState() => _BookTitleRowState();
}

class _BookTitleRowState extends State<BookTitleRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        margin: const EdgeInsetsDirectional.only(end: 4),
        decoration: BoxDecoration(
          color: widget.isChoosed ? Colors.white : Colors.grey[200],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border(
            top: BorderSide(
              color: widget.isChoosed ? primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
          boxShadow: widget.isChoosed
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTab,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  _buildBookIcon(),
                  const SizedBox(width: 8),
                  Expanded(child: _buildBookTitle()),
                  const SizedBox(width: 4),
                  _buildCloseButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookIcon() {
    return Icon(
      Icons.book_outlined,
      size: 16,
      color: widget.isChoosed ? primaryColor : Colors.grey[600],
    );
  }

  Widget _buildCloseButton() {
    return Opacity(
      opacity: (_isHovered || widget.isChoosed) ? 1.0 : 0.0,
      child: InkWell(
        onTap: widget.onClose,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildBookTitle() {
    String title = shortenTitle(widget.title);
    return Text(
      title,
      textAlign: TextAlign.center,
      style: GoogleFonts.amiri(
        color: widget.isChoosed ? primaryColor : Colors.black87,
        fontSize: 13,
        fontWeight: widget.isChoosed ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
