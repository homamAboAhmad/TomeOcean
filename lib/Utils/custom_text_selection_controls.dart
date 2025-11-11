import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomTextSelectionControls extends MaterialTextSelectionControls {
  CustomTextSelectionControls({
    required this.bookTitle,
    required this.pageNumber,
  });

  final String bookTitle;
  final int pageNumber;

  @override
  bool canCopy(TextSelectionDelegate delegate) {
    return super.canCopy(delegate) && delegate.textEditingValue.selection.isValid;
  }

  @override
  bool canSelectAll(TextSelectionDelegate delegate) {
    return super.canSelectAll(delegate);
  }

  void _handleCopyReference(TextSelectionDelegate delegate) {
    final String selectedText =
        delegate.textEditingValue.selection.textInside(delegate.textEditingValue.text);
    if (selectedText.isNotEmpty) {
      final String textToCopy = '"$selectedText"\n(${bookTitle}, ${pageNumber})';
      Clipboard.setData(ClipboardData(text: textToCopy));
      delegate.hideToolbar();
    }
  }

  void _handleGoogleSearch(TextSelectionDelegate delegate) async {
    final String selectedText =
        delegate.textEditingValue.selection.textInside(delegate.textEditingValue.text);
    if (selectedText.isNotEmpty) {
      final Uri googleUrl = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(selectedText)}',
      );
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl);
      } else {
        debugPrint('Could not launch $googleUrl');
      }
      delegate.hideToolbar();
    }
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
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    final bool isCopyEnabled = canCopy(delegate);
    final bool isSelectAllEnabled = canSelectAll(delegate);

    final List<Widget> menuItems = <Widget>[
      _buildMenuItem(
        label: 'نسخ',
        onPressed: isCopyEnabled ? () => handleCopy(delegate) : null,
      ),
      _buildMenuItem(
        label: 'نسخ مع المرجع',
        onPressed: isCopyEnabled ? () => _handleCopyReference(delegate) : null,
      ),
      _buildMenuItem(
        label: 'بحث',
        onPressed: () {
          debugPrint("Search action triggered");
          delegate.hideToolbar();
        },
      ),
      _buildMenuItem(
        label: 'بحث في جوجل',
        onPressed: () => _handleGoogleSearch(delegate),
      ),
      _buildMenuItem(
        label: 'تحديد الكل',
        onPressed: isSelectAllEnabled ? () => handleSelectAll(delegate) : null,
      ),
    ];

    if (lastSecondaryTapDownPosition == null) {
      return TextSelectionToolbar(
        anchorAbove: endpoints.first.point,
        anchorBelow: endpoints.last.point,
        children: menuItems,
      );
    }

    return Stack(
      children: <Widget>[
        Positioned(
          top: lastSecondaryTapDownPosition.dy,
          left: lastSecondaryTapDownPosition.dx,
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
                children: menuItems,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

