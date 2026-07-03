import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

/// Widget for displaying a professional bottom sheet when no search results are found.
class NoResultsBottomSheet {
  // Constants for bottom sheet styling
  static const double _bottomSheetBorderRadius = 20.0;
  static const double _bottomSheetPadding = 24.0;
  static const double _dragHandleWidth = 40.0;
  static const double _dragHandleHeight = 4.0;
  static const double _dragHandleMarginBottom = 20.0;
  static const double _iconSize = 80.0;
  static const double _titleFontSize = 20.0;
  static const double _subtitleFontSize = 18.0;
  static const double _descriptionFontSize = 14.0;
  static const double _buttonFontSize = 16.0;
  static const double _spacingAfterHeader = 24.0;
  static const double _spacingAfterIcon = 20.0;
  static const double _spacingAfterTitle = 12.0;
  static const double _spacingBeforeButton = 32.0;
  static const double _spacingAfterButton = 12.0;
  static const double _buttonVerticalPadding = 14.0;
  static const double _buttonBorderRadius = 8.0;
  static const double _closeButtonSpacerWidth = 40.0;

  /// Shows a professional bottom sheet when no search results are found.
  /// 
  /// Displays a modal bottom sheet with an icon, message, and action buttons
  /// that covers the content from the bottom, similar to professional applications.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_bottomSheetBorderRadius),
        ),
      ),
      builder: (BuildContext context) => _buildContent(context),
    );
  }

  /// Builds the content widget for the no results bottom sheet.
  static Widget _buildContent(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_bottomSheetPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_bottomSheetBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(context),
          SizedBox(height: _spacingAfterHeader),
          _buildIcon(),
          SizedBox(height: _spacingAfterIcon),
          _buildTitle(),
          SizedBox(height: _spacingAfterTitle),
          _buildDescription(),
          SizedBox(height: _spacingBeforeButton),
          _buildOkButton(context),
          SizedBox(height: _spacingAfterButton),
        ],
      ),
    );
  }

  /// Builds the drag handle at the top of the bottom sheet.
  static Widget _buildDragHandle() {
    return Container(
      width: _dragHandleWidth,
      height: _dragHandleHeight,
      margin: EdgeInsets.only(bottom: _dragHandleMarginBottom),
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Builds the header row with title and close button.
  static Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: _closeButtonSpacerWidth),
        Expanded(
          child: Center(
            child: Text(
              'لا توجد نتائج',
              style: mediumStyle(
                fontSize: _titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          icon: LibraryIcon.fromIcon(Icons.close, color: accentColor.withOpacity(0.68)),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
        ),
      ],
    );
  }

  /// Builds the no results icon.
  static Widget _buildIcon() {
    return LibraryIcon.fromIcon(
      Icons.search_off,
      size: _iconSize,
      color: borderColor,
    );
  }

  /// Builds the no results title text.
  static Widget _buildTitle() {
    return Text(
      'لا توجد نتائج للبحث',
      style: mediumStyle(
        fontSize: _subtitleFontSize,
        color: accentColor,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the no results description text.
  static Widget _buildDescription() {
    return Text(
      'جرب تغيير كلمات البحث أو معايير البحث',
      style: smallStyle(
        fontSize: _descriptionFontSize,
        color: accentColor.withOpacity(0.68),
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the OK button to dismiss the bottom sheet.
  static Widget _buildOkButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          padding: EdgeInsets.symmetric(vertical: _buttonVerticalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppChrome.radius),
          ),
        ),
        child: Text(
          'حسناً',
          style: mediumStyle(
            color: Colors.white,
            fontSize: _buttonFontSize,
          ),
        ),
      ),
    );
  }
}





