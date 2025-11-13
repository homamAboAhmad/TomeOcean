import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomContextMenu extends StatelessWidget {
  const CustomContextMenu({
    super.key,
    required this.state,
    required this.bookTitle,
    required this.pageNumber,
    required this.contextMenuAnchors,
    this.selectedText,
  });

  final SelectableRegionState state;
  final String bookTitle;
  final int pageNumber;
  final TextSelectionToolbarAnchors contextMenuAnchors;
  final String? selectedText;

  void _handleCopy() {
    state.copySelection(SelectionChangedCause.toolbar);
  }

  void _handleCopyReference() {
    final String? text = selectedText;
    if (text != null && text.isNotEmpty) {
      final String textToCopy = '"$text"\n(${bookTitle}, ${pageNumber})';
      Clipboard.setData(ClipboardData(text: textToCopy));
      state.hideToolbar();
    }
  }

  void _handleGoogleSearch() async {
    final String? text = selectedText;
    if (text != null && text.isNotEmpty) {
      final Uri googleUrl = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(text)}',
      );
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl);
      } else {
        debugPrint('Could not launch $googleUrl');
      }
      state.hideToolbar();
    }
  }

  void _handleSelectAll() {
    state.selectAll(SelectionChangedCause.toolbar);
  }

  Widget _buildMenuItem(
      {required String label, required VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text(
          label,
          style: normalStyle(
              color: onPressed != null ? Colors.white : Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canCopy = selectedText != null && selectedText!.isNotEmpty;

    return Stack(
      children: [
        Positioned(
          top: contextMenuAnchors.primaryAnchor.dy,
          left: contextMenuAnchors.primaryAnchor.dx,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4.0,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMenuItem(
                    label: 'نسخ',
                    onPressed: canCopy ? _handleCopy : null,
                  ),
                  _buildMenuItem(
                    label: 'نسخ مع المرجع',
                    onPressed: canCopy ? _handleCopyReference : null,
                  ),
                  _buildMenuItem(
                    label: 'بحث',
                    onPressed: () {
                      debugPrint("Search action triggered");
                      state.hideToolbar();
                    },
                  ),
                  _buildMenuItem(
                    label: 'بحث في جوجل',
                    onPressed: canCopy ? _handleGoogleSearch : null,
                  ),
                  _buildMenuItem(
                    label: 'تحديد الكل',
                    onPressed: _handleSelectAll,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}