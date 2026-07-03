part of '../HomePage.dart';

extension _HomePageOpenTabs on _HomePageState {
  Future<void> _restoreOpenTabs() async {
    final records = OpenTabsStore.instance.load();
    unawaited(WorkSessionStore().archivePreviousOpenTabs(records));
    if (!AppOtherSettings.instance.draft().restoreTabsOnStartup) return;
    for (final record in records) {
      if (!mounted) return;
      if (record.type == OpenTabRecord.typeLibraryData) {
        _openLibraryDataTab(save: false);
        continue;
      }
      if (record.type == OpenTabRecord.typeRecitedText) {
        _openRecitedTextTab(save: false);
        continue;
      }
      if (!record.isBook) continue;
      await _onBookSelected(
        File(record.bookPath),
        pageNumber: record.pageIndex,
        openSource: record.source,
      );
    }
  }

  void _saveOpenTabs() {
    final records = [
      for (final space in _spaces) ..._openTabRecordsFor(space),
    ];
    unawaited(OpenTabsStore.instance.save(records));
  }

  List<OpenTabRecord> _openTabRecordsFor(HomePageTabSpace space) {
    return [
      for (final book in space.openedBooks)
        if ((book.sourcePath ?? '').isNotEmpty)
          OpenTabRecord(
            bookPath: book.sourcePath!,
            pageIndex: book.currentPage,
            source: book.openSource,
          ),
      if (space.libraryDataTab != null)
        const OpenTabRecord(
          type: OpenTabRecord.typeLibraryData,
          bookPath: '',
          pageIndex: 0,
          source: BookOpenSource.other,
        ),
      if (space.recitedTextTab != null)
        const OpenTabRecord(
          type: OpenTabRecord.typeRecitedText,
          bookPath: '',
          pageIndex: 0,
          source: BookOpenSource.other,
        ),
    ];
  }
}
