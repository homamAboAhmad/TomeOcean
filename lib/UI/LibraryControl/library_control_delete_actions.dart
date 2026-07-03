part of 'library_control_dialog.dart';

extension _LibraryControlDeleteActions on _LibraryControlDialogState {
  Future<void> _deleteAuthor() async {
    final id = _selectedAuthorId;
    if (id == null) return;
    final linked = await _repo.linkedBookPaths(authorId: id);
    final choice = await showEntityDeleteDialog(
      context,
      entityLabel: 'المؤلف',
      entityName: _entityTitle(_authors, id),
      linkedBooksCount: linked.length,
    );
    if (choice == null) return;
    if (choice == EntityDeleteChoice.deleteBooks) {
      final result = await _deleteAuthorBooksWithProgress(id, linked.length);
      if (result.hasFailures) {
        await _showDeleteResult(result);
        await _reload();
        return;
      }
      _message('تم حذف المؤلف وحذف ${linked.length} كتاب تابع');
    } else {
      await _repo.deleteAuthor(id);
      _message('تم حذف المؤلف وفك ربط ${linked.length} كتاب');
    }
    _selectedAuthorId = null;
    await _reload();
  }

  Future<void> _deleteSection() async {
    final id = _selectedSectionId;
    if (id == null) return;
    final linked = await _repo.linkedBookPaths(sectionId: id);
    final choice = await showEntityDeleteDialog(
      context,
      entityLabel: 'التصنيف',
      entityName: _entityTitle(_sections, id),
      linkedBooksCount: linked.length,
    );
    if (choice == null) return;
    if (choice == EntityDeleteChoice.deleteBooks) {
      final result = await _deleteSectionBooksWithProgress(id, linked.length);
      if (result.hasFailures) {
        await _showDeleteResult(result);
        await _reload();
        return;
      }
      _message('تم حذف التصنيف وحذف ${linked.length} كتاب تابع');
    } else {
      await _repo.deleteSection(id);
      _message('تم حذف التصنيف وفك ربط ${linked.length} كتاب');
    }
    _selectedSectionId = null;
    await _reload();
  }

  String _entityTitle(List<LibraryEntityRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row.title;
    }
    return '';
  }
}
