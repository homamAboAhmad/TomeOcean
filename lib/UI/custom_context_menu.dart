import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/clipboard_post_processor.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomContextMenu extends StatelessWidget {
  const CustomContextMenu({
    super.key,
    required this.state,
    required this.bookTitle,
    required this.pageNumber,
    required this.contextMenuAnchors,
    required this.wordPage,
  });

  final SelectableRegionState state;
  final String bookTitle;
  final int pageNumber;
  final TextSelectionToolbarAnchors contextMenuAnchors;
  final WordPage wordPage;

  Future<String> _copyPlain() async {
    state.copySelection(SelectionChangedCause.toolbar);
    await Future.delayed(const Duration(milliseconds: 100));
    return ClipboardPostProcessor.postProcessClipboard(wordPage);
  }

  Future<String> _copyRich() async {
    state.copySelection(SelectionChangedCause.toolbar);
    await Future.delayed(const Duration(milliseconds: 100));
    return ClipboardPostProcessor.postProcessClipboardRich(wordPage);
  }

  void _handleCopy() async {
    await _copyPlain();
    state.hideToolbar();
  }

  void _handleCopyRich() async {
    await _copyRich();
    state.hideToolbar();
  }

  void _handleCopyReference() async {
    final text = await _copyPlain();
    if (text.isNotEmpty) {
      final formatted = '«$text» [$bookTitle (ص $pageNumber)]';
      await Clipboard.setData(ClipboardData(text: formatted));
    }
    state.hideToolbar();
  }

  void _handleGoogleSearch() async {
    final text = await _copyPlain();
    if (text.isNotEmpty) {
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
                  // نسخ مع التنسيق: يضع على الحافظة نص عادي + HTML مع CSS داخلي
                  // التنسيقات المنسوخة: غامق (bold)، مائل (italic)، تسطير (underline)،
                  // يتوسط (line-through)، لون النص (color)، خط (font-family)،
                  // حجم الخط (font-size)، تباعد الأحرف (letter-spacing)،
                  // لون الخلفية، محاذاة النص (text-align)، اتجاه (RTL/LTR)
                  // TODO: تفعيل عند الحاجة
                  // _buildMenuItem(
                  //   label: 'نسخ مع التنسيق',
                  //   onPressed: _handleCopyRich,
                  // ),
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