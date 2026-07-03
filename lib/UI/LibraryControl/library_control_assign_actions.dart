part of 'library_control_dialog.dart';

extension _LibraryControlAssignActions on _LibraryControlDialogState {
  bool get _hasTargetBooks => _targetBookPaths.isNotEmpty;

  Set<String> get _targetBookPaths {
    if (_checkedBookPaths.isNotEmpty) return _checkedBookPaths.toSet();
    return [_selectedBookPath].whereType<String>().toSet();
  }

  Future<void> _assignSelectedAuthor() async {
    final paths = _targetBookPaths;
    if (paths.isEmpty) return;
    final author = await showLibraryEntityPickerDialog(
      context: context,
      title: 'اختيار المؤلف',
      searchHint: 'بحث في المؤلفين',
      titleHeader: 'المؤلف',
      secondaryHeader: 'الوفاة',
      loadRows: _repo.loadAuthors,
    );
    if (author == null) return;
    await _repo.assignAuthor(author.id, paths);
    this._message('تم ربط ${paths.length} كتاب بالمؤلف: ${author.title}');
    await this._reload();
  }

  Future<void> _assignSelectedSection() async {
    final paths = _targetBookPaths;
    if (paths.isEmpty) return;
    final section = await showLibraryEntityPickerDialog(
      context: context,
      title: 'اختيار التصنيف',
      searchHint: 'بحث في التصنيفات',
      titleHeader: 'التصنيف',
      secondaryHeader: '',
      loadRows: _repo.loadSections,
    );
    if (section == null) return;
    await _repo.assignSection(section.id, paths);
    this._message('تم ربط ${paths.length} كتاب بالتصنيف: ${section.title}');
    await this._reload();
  }
}
