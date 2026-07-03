part of '../HomePage.dart';

extension _HomePageAppBar on _HomePageState {
  Widget _buildStackedAppBar() {
    final appBar = _buildAppBar();
    return SizedBox(
      height: appBar.preferredSize.height,
      child: appBar,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      toolbarHeight: 70,
      leadingWidth: 280,
      leading: Row(
        children: [
          const SizedBox(width: 8),
          _buildAppBarAction(
            icon: Icons.auto_stories_rounded,
            tooltip: 'القرآن الكريم (Ctrl+Q)',
            onPressed: () => this._openRecitedTextTab(),
          ),
          _buildAppBarAction(
            icon: Icons.note_add_outlined,
            tooltip: 'إضافة كتاب (Ctrl+N)',
            onPressed: () => unawaited(this._addBookFromHome()),
          ),
          _buildAppBarAction(
            icon: Icons.menu_book_rounded,
            tooltip: 'تصفح الكتب (F10)',
            onPressed: () => this._openLibraryPicker(),
          ),
          _buildAppBarAction(
            icon: Icons.search_rounded,
            tooltip: 'بحث (F3)',
            onPressed: () => _searchHandlers!.openSearchWindow(),
          ),
          _buildAppBarAction(
            icon: Icons.save,
            tooltip: 'المحفوظات (Ctrl+L)',
            onPressed: () => this._openSavedItemsDialog(),
          ),
        ],
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
          border: Border.all(color: Colors.white.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LibraryIcon(
              LibraryIconType.books,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'المكتبة',
              style: bigStyle(fontSize: 22, color: Colors.white),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        _buildSplitModeMenu(),
        _buildAppBarAction(
          icon: Icons.people_outline_rounded,
          tooltip: 'بيانات المؤلفين والكتب',
          onPressed: () => this._openLibraryDataTab(),
        ),
        _buildAppBarAction(
          icon: Icons.fact_check_outlined,
          tooltip: 'لوحة التحكم (F2)',
          onPressed: () => this._openLibraryControlPanel(),
        ),
        _buildAppBarAction(
          icon: Icons.settings_rounded,
          tooltip: 'الإعدادات (Ctrl+O)',
          onPressed: this._openSettings,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSplitModeMenu() {
    return PopupMenuButton<HomePageSplitMode>(
      tooltip: 'مساحات العرض',
      child: _appBarIconSurface(LibraryIcon.fromIcon(
        _splitModeIcon(),
        color: Colors.white,
        size: 22,
      )),
      onSelected: (mode) => this._handleSplitModeMenuSelection(mode),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: HomePageSplitMode.vertical,
          child: Text('مساحتان عموديا'),
        ),
        PopupMenuItem(
          value: HomePageSplitMode.horizontal,
          child: Text('مساحتان أفقيا'),
        ),
        PopupMenuItem(
          value: HomePageSplitMode.single,
          child: Text('مساحة واحدة'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: HomePageSplitMode.detachCurrentTab,
          child: Text('فصل التبويب مستقلا'),
        ),
        PopupMenuItem(
          value: HomePageSplitMode.returnDetachedTabs,
          child: Text('إرجاع التبويبات المفصولة'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: HomePageSplitMode.closeCurrentTab,
          child: Row(
            children: [
              Expanded(child: Text('إغلاق التبويب الحالي')),
              Text('Esc'),
            ],
          ),
        ),
        PopupMenuItem(
          value: HomePageSplitMode.closeAllTabs,
          child: Row(
            children: [
              Expanded(child: Text('إغلاق جميع التبويبات')),
              Text('Shift Esc'),
            ],
          ),
        ),
        PopupMenuItem(
          value: HomePageSplitMode.closeOtherTabs,
          child: Text('إغلاق التبويبات الأخرى'),
        ),
      ],
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => const SettingsScreen(),
    );
  }

  IconData _splitModeIcon() {
    switch (_splitMode) {
      case HomePageSplitMode.vertical:
        return Icons.vertical_split;
      case HomePageSplitMode.horizontal:
        return Icons.horizontal_split;
      case HomePageSplitMode.single:
        return Icons.web_asset_outlined;
      case HomePageSplitMode.detachCurrentTab:
        return Icons.open_in_new;
      case HomePageSplitMode.returnDetachedTabs:
        return Icons.keyboard_return;
      case HomePageSplitMode.closeCurrentTab:
      case HomePageSplitMode.closeAllTabs:
      case HomePageSplitMode.closeOtherTabs:
        return Icons.close;
    }
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppChrome.radius),
          onTap: onPressed,
          child: _appBarIconSurface(
            LibraryIcon.fromIcon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _appBarIconSurface(Widget child) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: child,
    );
  }
}
