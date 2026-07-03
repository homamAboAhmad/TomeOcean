part of '../HomePage.dart';

extension _HomePageTabCloseActions on _HomePageState {
  void _handleSplitModeMenuSelection(HomePageSplitMode mode) {
    switch (mode) {
      case HomePageSplitMode.closeCurrentTab:
        _closeCurrentTabCommand();
        return;
      case HomePageSplitMode.closeAllTabs:
        _closeAllTabsCommand();
        return;
      case HomePageSplitMode.closeOtherTabs:
        _closeOtherTabsCommand();
        return;
      default:
        this._setSplitMode(mode);
    }
  }

  void _closeCurrentTabCommand() {
    if (_detachedTabs.isNotEmpty) {
      setState(() => _detachedTabs.removeLast());
      _saveOpenTabs();
      return;
    }
    _closeCurrentTab(_activeSpace);
  }

  void _closeCurrentTab(HomePageTabSpace space) {
    setState(() {
      space.closeSelectedTab();
    });
    _saveOpenTabs();
  }

  void _closeAllTabsCommand() {
    setState(() {
      if (_detachedTabs.isNotEmpty) {
        _detachedTabs.clear();
        return;
      }
      _activeSpace.closeAllTabs();
    });
    _saveOpenTabs();
  }

  void _closeOtherTabsCommand() {
    setState(() {
      if (_detachedTabs.isNotEmpty) {
        if (_detachedTabs.length > 1) {
          final current = _detachedTabs.removeLast();
          _detachedTabs.clear();
          _detachedTabs.add(current);
        }
        return;
      }
      _activeSpace.closeOtherTabs();
    });
    _saveOpenTabs();
  }
}
