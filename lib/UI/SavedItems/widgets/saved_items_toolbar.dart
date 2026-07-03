import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

class SavedItemsToolbar extends StatelessWidget {
  final TextEditingController nameController;
  final String hintText;
  final String saveTooltip;
  final VoidCallback? onSave;
  final bool showSaveButton;
  final VoidCallback? onRename;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;

  const SavedItemsToolbar({
    super.key,
    required this.nameController,
    required this.hintText,
    required this.saveTooltip,
    required this.onSave,
    this.showSaveButton = true,
    required this.onRename,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(bottom: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: nameController,
              style: smallStyle(color: accentColor, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle: smallStyle(color: accentColor.withOpacity(0.58)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (showSaveButton)
            _ToolButton(
              icon: Icons.save,
              tooltip: saveTooltip,
              onPressed: onSave,
            ),
          _ToolButton(
            icon: Icons.drive_file_rename_outline,
            tooltip: 'إعادة تسمية المحدد',
            onPressed: onRename,
          ),
          const Spacer(),
          _ToolButton(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'رفع المحدد للأعلى',
            onPressed: onMoveUp,
          ),
          _ToolButton(
            icon: Icons.keyboard_arrow_down,
            tooltip: 'إنزال المحدد للأسفل',
            onPressed: onMoveDown,
          ),
          _ToolButton(
            icon: Icons.delete_outline,
            tooltip: 'حذف المحدد',
            color: destructiveColor,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback? onPressed;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: organicHighlightColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
          ),
        ),
        icon: LibraryIcon.fromIcon(icon, size: 18, color: color ?? primaryColor),
        onPressed: onPressed,
      ),
    );
  }
}
