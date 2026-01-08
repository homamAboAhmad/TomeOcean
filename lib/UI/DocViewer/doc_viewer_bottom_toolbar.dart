import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

class DocViewerBottomToolbar extends StatelessWidget {
  final WordDocument wordDocument;
  final TextEditingController pageNumberController;
  final int? Function() findPreviousVisited;
  final int? Function() findNextVisited;
  final VoidCallback goToPreviousVisitedPage;
  final VoidCallback goToNextVisitedPage;
  final Function(int) jumpToPage;
  final ValueChanged<double> onSliderChanged;

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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Page Number Input
                _buildPageInputSection(totalPages),

                const SizedBox(width: 20),

                // Slider
                Expanded(child: _buildSlider(context, totalPages)),

                const SizedBox(width: 20),

                // History Navigation - Fixed RTL
                _buildHistoryNavigation(hasPrevious, hasNext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageInputSection(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'صفحة',
            style: TextStyle(
              fontFamily: appFont,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 50,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
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
                  jumpToPage(page - 1);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'من $totalPages',
            style: TextStyle(
              fontFamily: appFont,
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context, int totalPages) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.15),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.1),
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
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
              color: Colors.grey[300],
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
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEnabled
                  ? primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: isEnabled ? primaryColor : Colors.grey[400],
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
