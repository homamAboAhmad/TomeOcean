part of 'library_control_dialog.dart';

extension _LibraryControlBulkDelete on _LibraryControlDialogState {
  Future<LibraryDeleteResult> _deleteBooksWithProgress(List<String> paths) async {
    return _runDeleteWithProgress(
      total: paths.length,
      action: (onProgress) => _repo.deleteBooks(
        paths,
        onProgress: onProgress,
      ),
    );
  }

  Future<LibraryDeleteResult> _deleteAuthorBooksWithProgress(
    String id,
    int total,
  ) {
    return _runDeleteWithProgress(
      total: total,
      action: (onProgress) => _repo.deleteAuthorWithBooks(
        id,
        onProgress: onProgress,
      ),
    );
  }

  Future<LibraryDeleteResult> _deleteSectionBooksWithProgress(
    String id,
    int total,
  ) {
    return _runDeleteWithProgress(
      total: total,
      action: (onProgress) => _repo.deleteSectionWithBooks(
        id,
        onProgress: onProgress,
      ),
    );
  }

  Future<LibraryDeleteResult> _runDeleteWithProgress({
    required int total,
    required Future<LibraryDeleteResult> Function(
      void Function(int done, int total, String path, String message) onProgress,
    ) action,
  }) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _progressDone = 0;
        _progressTotal = total;
        _progressText = _deleteProgressText(0, total, 'بدء الحذف');
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));

    try {
      return await action(
        (done, total, _, message) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
            _progressText = _deleteProgressText(done, total, message);
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressDone = null;
          _progressTotal = null;
          _progressText = null;
        });
      }
    }
  }

  String _deleteProgressText(int done, int total, String message) {
    if (total <= 0) return 'تحديث القائمة';
    if (total == 1) return message;
    final current = (done + 1).clamp(1, total);
    return '$message - الكتاب $current من $total';
  }

  Future<void> _showDeleteResult(LibraryDeleteResult result) async {
    if (!result.hasFailures) {
      _message(result.deleted == 1
          ? 'تم حذف الكتاب'
          : 'تم حذف ${result.deleted} كتاب');
      return;
    }

    _message('لم يكتمل حذف كل الكتب');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(dialogContext);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: const Text('تعذر حذف بعض الكتب'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(_deleteFailuresText(result)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  String _deleteFailuresText(LibraryDeleteResult result) {
    return 'تم حذف ${result.deleted} من ${result.total} كتاب.\n'
        'تعذر حذف ${result.failures.length} كتاب. قد يكون أحد الملفات مفتوحًا '
        'أو لا يملك التطبيق صلاحية حذفه.\n\n'
        'أغلق الملفات المفتوحة ثم أعد المحاولة.';
  }
}
