import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

class DocViewerTopToolbar extends StatelessWidget {
  final WordDocument wordDocument;
  final Widget sideBarIcons;
  final VoidCallback onDuplicateBook;
  final VoidCallback onGoStart;
  final VoidCallback onGoPrevious;
  final VoidCallback onGoNext;
  final VoidCallback onGoEnd;
  final VoidCallback onCopyPage;
  final VoidCallback onToggleDiacritics;
  final VoidCallback onShowBookCard;

  const DocViewerTopToolbar({
    super.key,
    required this.wordDocument,
    required this.sideBarIcons,
    required this.onDuplicateBook,
    required this.onGoStart,
    required this.onGoPrevious,
    required this.onGoNext,
    required this.onGoEnd,
    required this.onCopyPage,
    required this.onToggleDiacritics,
    required this.onShowBookCard,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 30,
        width: double.infinity,
        color: bgColor,
        child: Stack(
          children: [
            sideBarIcons,
            Center(
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarButton(onTap: onDuplicateBook, icon: Icons.new_label),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: onGoStart, icon: Icons.skip_next),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: onGoPrevious, icon: Icons.navigate_before),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: onGoNext, icon: Icons.navigate_next),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: onGoEnd, icon: Icons.skip_previous),
                  const SizedBox(width: 8),
                  _buildBookTitle(),
                  const SizedBox(width: 8),
                  _buildToolbarButton(onTap: onCopyPage, icon: Icons.copy),
                  const SizedBox(width: 8),
                  _buildDiacriticsButton(),
                  const SizedBox(width: 8),
                  _buildBookCardButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(wordDocument.title, style: normalStyle(color: Colors.black)),
    );
  }

  Widget _buildToolbarButton({
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Icon(
        icon,
        color: Colors.black,
        textDirection: TextDirection.rtl,
        size: iconSize,
      ),
    );
  }

  Widget _buildDiacriticsButton() {
    return InkWell(
      onTap: onToggleDiacritics,
      child: Material(
        elevation: wordDocument.withDiacritics ? 2 : 0,
        color: wordDocument.withDiacritics ? Colors.grey : bgColor,
        child: Container(
          height: 36,
          width: 36,
          padding: EdgeInsets.all(wordDocument.withDiacritics ? 4 : 0),
          child: Image.asset("assets/icons/ic_diacritics.png"),
        ),
      ),
    );
  }

  Widget _buildBookCardButton(BuildContext context) {
    return InkWell(
      onTap: onShowBookCard,
      child: const SizedBox(
        height: 36,
        width: 36,
        child: Icon(Icons.note, color: Colors.blueGrey),
      ),
    );
  }
}
