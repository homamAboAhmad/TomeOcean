import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePageTabShortcuts extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final int totalTabs;
  final ValueChanged<int> onSwitchToIndex;
  final bool Function(int direction)? onSwitchDetachedTab;
  final VoidCallback? onCloseCurrentTab;
  final VoidCallback? onCloseAllTabs;
  final VoidCallback? onOpenLibraryPicker;
  final VoidCallback? onAddBook;
  final VoidCallback? onOpenRecitedText;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenLibraryControl;
  final VoidCallback? onOpenSavedItems;
  final VoidCallback? onOpenSettings;

  const HomePageTabShortcuts({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.totalTabs,
    required this.onSwitchToIndex,
    this.onSwitchDetachedTab,
    this.onCloseCurrentTab,
    this.onCloseAllTabs,
    this.onOpenLibraryPicker,
    this.onAddBook,
    this.onOpenRecitedText,
    this.onOpenSearch,
    this.onOpenLibraryControl,
    this.onOpenSavedItems,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.tab, control: true): _next,
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): _previous,
        const SingleActivator(LogicalKeyboardKey.escape): _closeCurrent,
        const SingleActivator(
          LogicalKeyboardKey.escape,
          shift: true,
        ): _closeAll,
        const SingleActivator(LogicalKeyboardKey.f10): _openLibraryPicker,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _addBook,
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
            _openRecitedText,
        const SingleActivator(LogicalKeyboardKey.f3): _openSearch,
        const SingleActivator(LogicalKeyboardKey.f2): _openLibraryControl,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _openSavedItems,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _openSettings,
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  void _next() => _switchBy(1);

  void _previous() => _switchBy(-1);

  void _closeCurrent() => onCloseCurrentTab?.call();

  void _closeAll() => onCloseAllTabs?.call();

  void _openLibraryPicker() => onOpenLibraryPicker?.call();

  void _addBook() => onAddBook?.call();

  void _openRecitedText() => onOpenRecitedText?.call();

  void _openSearch() => onOpenSearch?.call();

  void _openLibraryControl() => onOpenLibraryControl?.call();

  void _openSavedItems() => onOpenSavedItems?.call();

  void _openSettings() => onOpenSettings?.call();

  void _switchBy(int direction) {
    if (onSwitchDetachedTab?.call(direction) == true) return;
    if (totalTabs <= 1) return;
    if (currentIndex < 0 || currentIndex >= totalTabs) {
      onSwitchToIndex(direction > 0 ? 0 : totalTabs - 1);
      return;
    }
    final nextIndex = (currentIndex + direction) % totalTabs;
    onSwitchToIndex(nextIndex < 0 ? nextIndex + totalTabs : nextIndex);
  }
}
