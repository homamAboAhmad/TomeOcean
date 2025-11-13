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
  final VoidCallback onSliderChanged;

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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 4.0,
        child: Container(
          width: double.infinity,
          height: 40,
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Card(
                elevation: 2.0,
                child: Container(
                  width: 70,
                  height: 30,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: pageNumberController,
                    textAlign: TextAlign.center,
                    style: normalStyle(color: primaryColor, fontSize: 16),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(bottom: 15)),
                    onSubmitted: (value) {
                      final page = int.tryParse(value);
                      if (page != null) {
                        jumpToPage(page - 1);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: primaryColor.withOpacity(0.3),
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: (wordDocument.currentPage + 1).toDouble(),
                    min: 1,
                    max: wordDocument.pageFilePaths.isNotEmpty
                        ? wordDocument.pageFilePaths.length.toDouble()
                        : 1,
                    onChanged: (value) {
                      pageNumberController.text = value.round().toString();
                      onSliderChanged();
                    },
                    onChangeEnd: (value) {
                      jumpToPage(value.round() - 1);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.arrow_circle_right_outlined,
                    size: iconSize + 4),
                color: findPreviousVisited() != -1
                    ? primaryColor
                    : Theme.of(context).disabledColor,
                onPressed: findPreviousVisited() != -1
                    ? goToPreviousVisitedPage
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.arrow_circle_left_outlined,
                    size: iconSize + 4),
                color: findNextVisited() != null
                    ? primaryColor
                    : Theme.of(context).disabledColor,
                onPressed:
                    findNextVisited() != null ? goToNextVisitedPage : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
