import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

class DocViewerBottomToolbar extends StatelessWidget {
  final WordDocument wordDocument;
  final TextEditingController pageNumberController;
  final int? Function() findPreviousVisited;
  final int? Function() findNextVisited;
  final VoidCallback goToPreviousVisitedPage;
  final VoidCallback goToNextVisitedPage;
  final Function(int) jumpToPage;
  final ValueChanged<double> onSliderChanged;
  final bool commentPanelOpen;
  final VoidCallback onToggleCommentPanel;

  const DocViewerBottomToolbar({
    super.key,
    required this.wordDocument,
    required this.pageNumberController,
    required this.findPreviousVisited,
    required this.findNextVisited,
    required this.goToPreviousVisitedPage,
    required this.goToNextVisitedPage,
    required this.jumpToPage,
    required this.onSliderChanged,
    required this.commentPanelOpen,
    required this.onToggleCommentPanel,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = wordDocument.pageFilePaths.length;
    final hasPrevious = findPreviousVisited() != -1;
    final hasNext = findNextVisited() != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: AppChrome.borderSide(opacity: 0.65)),
          boxShadow: AppChrome.topShadow,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Page Number Input
                _buildPageInputSection(
                  wordDocument.partForPage(wordDocument.currentPage)?.pageCount ??
                      totalPages,
                ),
                if (wordDocument.hasParts) ...[
                  const SizedBox(width: 8),
                  _buildPartDropdown(
                    wordDocument.partForPage(wordDocument.currentPage)?.partNumber,
                  ),
                ],

                const SizedBox(width: 20),

                // Slider
                Expanded(child: _buildSlider(context, totalPages)),

                const SizedBox(width: 20),

                // History Navigation - Fixed RTL
                _buildHistoryNavigation(hasPrevious, hasNext),

                const SizedBox(width: 10),
                _buildCommentButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageInputSection(int totalPages) {
    final currentPart = wordDocument.partForPage(wordDocument.currentPage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: borderColor.withOpacity(0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'صفحة',
            style: TextStyle(
              fontFamily: appFont,
              color: accentColor.withOpacity(0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 50,
            height: 26,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
              border: Border.all(color: primaryColor.withOpacity(0.35)),
            ),
            child: TextField(
              controller: pageNumberController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: appFont,
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onSubmitted: (value) {
                final page = int.tryParse(value);
                if (page != null) {
                  final maxPage = totalPages < 1 ? 1 : totalPages;
                  final safePage = page.clamp(1, maxPage).toInt();
                  final target = currentPart == null
                      ? safePage - 1
                      : currentPart.pageOffset + safePage - 1;
                  jumpToPage(target);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'من $totalPages',
            style: TextStyle(
              fontFamily: appFont,
              color: accentColor.withOpacity(0.58),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartDropdown(int? currentPartNumber) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: currentPartNumber,
        isDense: true,
        items: [
          for (final part in wordDocument.parts)
            DropdownMenuItem<int>(
              value: part.partNumber,
              child: Text(
                part.partTitle.isEmpty
                    ? 'الجزء ${part.partNumber}'
                    : part.partTitle,
                style: TextStyle(fontFamily: appFont, fontSize: 12),
              ),
            ),
        ],
        onChanged: (partNumber) {
          if (partNumber == null) return;
          jumpToPage(wordDocument.firstPageOfPart(partNumber));
        },
      ),
    );
  }

  Widget _buildSlider(BuildContext context, int totalPages) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.15),
        thumbColor: actionColor,
        overlayColor: actionColor.withOpacity(0.12),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Slider(
        value: (wordDocument.currentPage + 1).toDouble(),
        min: 1,
        max: totalPages > 0 ? totalPages.toDouble() : 1,
        onChanged: onSliderChanged,
        onChangeEnd: (value) => jumpToPage(value.round() - 1),
      ),
    );
  }

  Widget _buildHistoryNavigation(bool hasPrevious, bool hasNext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: borderColor.withOpacity(0.75)),
      ),
      // Use LTR to prevent icon mirroring
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left button (visual) -> Points LEFT (<) -> Should govern NEXT
            _buildHistoryButton(
              icon: Icons.arrow_back_rounded,
              isEnabled: hasNext, // Enable if there's a next page
              onTap: goToNextVisitedPage, // Action: Go to Next
              tooltip: 'الصفحة التالية المزارة',
            ),
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: borderColor,
            ),
            // Right button (visual) -> Points RIGHT (>) -> Should govern PREVIOUS
            _buildHistoryButton(
              icon: Icons.arrow_forward_rounded,
              isEnabled: hasPrevious, // Enable if there's a previous page
              onTap: goToPreviousVisitedPage, // Action: Go to Previous
              tooltip: 'الصفحة السابقة المزارة',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEnabled
                  ? primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
            ),
            child: LibraryIcon.fromIcon(
              icon,
              color: isEnabled ? primaryColor : accentColor.withOpacity(0.36),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentButton() {
    return Tooltip(
      message: commentPanelOpen ? 'إخفاء التعليق' : 'إظهار التعليق',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleCommentPanel,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: commentPanelOpen
                  ? primaryColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
              border: Border.all(color: borderColor),
            ),
            child: LibraryIcon.fromIcon(
              Icons.mode_comment_outlined,
              color: commentPanelOpen ? primaryColor : accentColor,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
