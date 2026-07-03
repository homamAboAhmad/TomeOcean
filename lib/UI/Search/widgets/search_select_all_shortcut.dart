import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchSelectAllShortcut extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSelectAll;

  const SearchSelectAllShortcut({
    super.key,
    required this.child,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    if (onSelectAll == null) return child;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
            const _SearchSelectAllIntent(),
      },
      child: Actions(
        actions: {
          _SearchSelectAllIntent: CallbackAction<_SearchSelectAllIntent>(
            onInvoke: (_) {
              onSelectAll!();
              return null;
            },
          ),
        },
        child: Focus(canRequestFocus: true, child: child),
      ),
    );
  }
}

class _SearchSelectAllIntent extends Intent {
  const _SearchSelectAllIntent();
}
