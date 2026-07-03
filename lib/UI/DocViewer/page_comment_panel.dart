import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';

class PageCommentPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool pinned;
  final bool dirty;
  final bool canUndo;
  final bool canRedo;
  final bool isSaving;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onTogglePinned;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  const PageCommentPanel({
    super.key,
    required this.controller,
    required this.pinned,
    required this.dirty,
    required this.canUndo,
    required this.canRedo,
    required this.isSaving,
    required this.onUndo,
    required this.onRedo,
    required this.onTogglePinned,
    required this.onSave,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppUiColors.color(AppColorRole.commentBackground);
    final textColor = AppUiColors.color(AppColorRole.comments);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.shade500)),
        ),
        child: Column(
          children: [
            _toolbar(backgroundColor),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppUiFonts.style(
                  AppFontRole.comments,
                  normalStyle(color: textColor, fontSize: 15, height: 1.5),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 10),
                  hintText: 'اكتب تعليق الصفحة هنا...',
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(Color backgroundColor) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.82),
        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
      ),
      child: Row(
        children: [
          _button(Icons.undo, 'تراجع', canUndo ? onUndo : null),
          _button(Icons.redo, 'إعادة', canRedo ? onRedo : null),
          _button(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            pinned ? 'إلغاء تثبيت نافذة التعليق' : 'تثبيت نافذة التعليق',
            onTogglePinned,
            active: pinned,
          ),
          const Spacer(),
          if (dirty)
            Text('غير محفوظ', style: smallStyle(color: Colors.red.shade700)),
          const SizedBox(width: 8),
          _button(
            isSaving ? Icons.hourglass_empty : Icons.save_outlined,
            'حفظ',
            isSaving ? null : onSave,
            active: dirty,
          ),
          _button(Icons.close, 'إغلاق', onClose),
        ],
      ),
    );
  }

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool active = false,
  }) {
    final iconColor = onPressed == null
        ? Colors.grey.shade400
        : active
            ? primaryColor
            : Colors.grey.shade700;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: LibraryIcon.fromIcon(
          icon,
          size: 16,
          color: iconColor,
        ),
        color: active ? primaryColor : Colors.grey.shade700,
        disabledColor: Colors.grey.shade400,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        splashRadius: 14,
        onPressed: onPressed,
      ),
    );
  }
}
