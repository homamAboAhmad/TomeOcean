import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/Utils/TxtUtils.dart';

class OpenBooksDropdownButton extends StatelessWidget {
  final List<WordDocument> openedBooks;
  final int selectedBookIndex;
  final ValueChanged<int> onBookSelected;

  const OpenBooksDropdownButton({
    required this.openedBooks,
    required this.selectedBookIndex,
    required this.onBookSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (openedBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'الكتب المفتوحة',
      child: PopupMenuButton<int>(
        tooltip: 'الكتب المفتوحة',
        onSelected: onBookSelected,
        offset: const Offset(0, 40),
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
        ),
        itemBuilder: (context) {
          return List.generate(openedBooks.length, (index) {
            final book = openedBooks[index];
            final isSelected = index == selectedBookIndex;

            return PopupMenuItem<int>(
              value: index,
              child: SizedBox(
                width: 220,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        shortenTitle(book.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: normalStyle(
                          fontSize: 14,
                          color: accentColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    LibraryIcon.fromIcon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.menu_book_rounded,
                      size: 16,
                      color: isSelected ? actionColor : accentColor.withOpacity(0.58),
                    ),
                  ],
                ),
              ),
            );
          });
        },
        child: Container(
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: organicHighlightColor,
            borderRadius: BorderRadius.circular(AppChrome.radius),
            border: Border.all(color: borderColor),
          ),
          child: const LibraryIcon(
            LibraryIconType.chevronDown,
            size: 20,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}
