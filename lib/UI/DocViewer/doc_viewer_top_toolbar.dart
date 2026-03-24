import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

class DocViewerTopToolbar extends StatelessWidget {
  final WordDocument wordDocument;
  final Widget sideBarIcons;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onDuplicateBook;
  final VoidCallback onGoStart;
  final VoidCallback onGoPrevious;
  final VoidCallback onGoNext;
  final VoidCallback onGoEnd;
  final VoidCallback onCopyPage;
  final VoidCallback onToggleDiacritics;
  final VoidCallback onToggleNumerals;
  final VoidCallback onShowBookCard;

  const DocViewerTopToolbar({
    super.key,
    required this.wordDocument,
    required this.sideBarIcons,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onDuplicateBook,
    required this.onGoStart,
    required this.onGoPrevious,
    required this.onGoNext,
    required this.onGoEnd,
    required this.onCopyPage,
    required this.onToggleDiacritics,
    required this.onToggleNumerals,
    required this.onShowBookCard,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              // Sidebar Icons Section
              sideBarIcons,

              // Divider
              _buildDivider(),

              // Navigation Controls - Corrected RTL Order & Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start (Page 1) - Right-most in RTL
                    _buildToolbarButton(
                      onTap: onGoStart,
                      icon: Icons.first_page_rounded, // Mirrors to >|
                      tooltip: 'البداية',
                    ),
                    // Previous - Points Right in RTL
                    _buildToolbarButton(
                      onTap: onGoPrevious,
                      icon: Icons.chevron_left_rounded, // Mirrors to >
                      tooltip: 'السابق',
                    ),
                    // Next - Points Left in RTL
                    _buildToolbarButton(
                      onTap: onGoNext,
                      icon: Icons.chevron_right_rounded, // Mirrors to <
                      tooltip: 'التالي',
                    ),
                    // End (Last Page) - Left-most in RTL
                    _buildToolbarButton(
                      onTap: onGoEnd,
                      icon: Icons.last_page_rounded, // Mirrors to |<
                      tooltip: 'النهاية',
                    ),
                  ],
                ),
              ),

              // Divider
              _buildDivider(),

              // Book Title - Pure Text
              Expanded(
                child: Center(
                  child: Text(
                    wordDocument.title,
                    style: normalStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Divider
              _buildDivider(),

              // Zoom Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolbarButton(
                      onTap: onZoomOut,
                      icon: Icons.remove_rounded,
                      tooltip: 'تصغير',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ),
                    _buildToolbarButton(
                      onTap: onZoomIn,
                      icon: Icons.add_rounded,
                      tooltip: 'تكبير',
                    ),
                  ],
                ),
              ),

              // Divider
              _buildDivider(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolbarButton(
                      onTap: onDuplicateBook,
                      icon: Icons.tab_rounded,
                      tooltip: 'نسخ في تبويب جديد',
                    ),
                    _buildToolbarButton(
                      onTap: onCopyPage,
                      icon: Icons.copy_rounded,
                      tooltip: 'نسخ الصفحة',
                    ),
                    _buildDiacriticsButton(),
                    const SizedBox(width: 4),
                    _buildNumeralsButton(),
                    _buildBookCardButton(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 32, color: Colors.grey[200]);
  }

  Widget _buildToolbarButton({
    required VoidCallback onTap,
    required IconData icon,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            child: Icon(icon, color: accentColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildDiacriticsButton() {
    final isActive = wordDocument.withDiacritics;
    return Tooltip(
      message: isActive ? 'إخفاء التشكيل' : 'إظهار التشكيل',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleDiacritics,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              "assets/icons/ic_diacritics.png",
              color: isActive ? primaryColor : accentColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumeralsButton() {
    final isActive = wordDocument.useArabicNumerals;
    return Tooltip(
      message: isActive ? 'عرض أرقام غربية' : 'عرض أرقام عربية',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleNumerals,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              isActive ? '١٢٣' : '123',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? primaryColor : accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCardButton() {
    return Tooltip(
      message: 'بطاقة الكتاب',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShowBookCard,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            child: Icon(
              Icons.info_outline_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
