import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import '../Utils/TxtUtils.dart';

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
    final titleColor = AppUiColors.color(AppColorRole.titles);
    final maxWords = AppOtherSettings.instance.draft().maxTabTitleWords;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(
          minWidth: 120,
          maxWidth: (maxWords * 58.0).clamp(220.0, 420.0).toDouble(),
        ),
        margin: const EdgeInsetsDirectional.only(end: 4),
        decoration: BoxDecoration(
          color: widget.isChoosed ? surfaceColor : mutedColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppChrome.radius),
            topRight: Radius.circular(AppChrome.radius),
          ),
          border: Border(
            top: BorderSide(
              color: widget.isChoosed ? actionColor : Colors.transparent,
              width: 3,
            ),
          ),
          boxShadow: widget.isChoosed
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTab,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppChrome.radius),
              topRight: Radius.circular(AppChrome.radius),
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
    return LibraryIcon.fromIcon(
      Icons.book_outlined,
      size: 16,
      color: widget.isChoosed
          ? AppUiColors.color(AppColorRole.titles)
          : accentColor.withOpacity(0.62),
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
            color: destructiveColor.withOpacity(0.10),
          ),
          child: const LibraryIcon(
            LibraryIconType.close,
            size: 14,
            color: destructiveColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBookTitle() {
    String title = shortenTitle(
      widget.title,
      maxWords: AppOtherSettings.instance.draft().maxTabTitleWords,
    );
    final titleColor = AppUiColors.color(AppColorRole.titles);
    return Text(
      title,
      textAlign: TextAlign.center,
      style: AppUiFonts.style(
        AppFontRole.bookLists,
        normalStyle(
        color: widget.isChoosed ? titleColor : accentColor,
        fontSize: 13,
        fontWeight: widget.isChoosed ? FontWeight.bold : FontWeight.normal,
        ),
        sizeOffset: -1,
        fontWeight: widget.isChoosed ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
