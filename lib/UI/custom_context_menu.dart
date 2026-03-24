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
  });

  final SelectableRegionState state;
  final String bookTitle;
  final int pageNumber;
  final TextSelectionToolbarAnchors contextMenuAnchors;

  void _handleCopy() {
    state.copySelection(SelectionChangedCause.toolbar);
  }

  void _handleCopyReference() async {
    state.copySelection(SelectionChangedCause.toolbar);
    await Future.delayed(const Duration(milliseconds: 50));
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text != null && text.isNotEmpty) {
      final formatted = '«$text» [$bookTitle (ص $pageNumber)]';
      await Clipboard.setData(ClipboardData(text: formatted));
    }
    state.hideToolbar();
  }

  void _handleGoogleSearch() async {
    state.copySelection(SelectionChangedCause.toolbar);
    await Future.delayed(const Duration(milliseconds: 50));
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text != null && text.isNotEmpty) {
      final Uri googleUrl = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(text)}',
      );
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl);
      }
    }
    state.hideToolbar();
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
                  _buildMenuItem(label: 'نسخ', onPressed: _handleCopy),
                  _buildMenuItem(
                    label: 'نسخ مع المرجع',
                    onPressed: _handleCopyReference,
                  ),
                  _buildMenuItem(
                    label: 'بحث في جوجل',
                    onPressed: _handleGoogleSearch,
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