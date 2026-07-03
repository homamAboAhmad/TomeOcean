import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/PageCommentsRepository.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

class CommentsExchangePanel extends StatefulWidget {
  const CommentsExchangePanel({super.key});

  @override
  State<CommentsExchangePanel> createState() => _CommentsExchangePanelState();
}

class _CommentsExchangePanelState extends State<CommentsExchangePanel> {
  bool _busy = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const Divider(height: 28),
          Text(
            'يمكنك حفظ التعليقات في ملف، ثم إضافة هذا الملف إلى نسخة أخرى من التطبيق.',
            style: normalStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _exportComments,
                icon: const LibraryIcon(LibraryIconType.download),
                label: const Text('حفظ التعليقات'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _importComments,
                icon: const LibraryIcon(LibraryIconType.upload),
                label: const Text('إضافة التعليقات'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: normalStyle(color: primaryColor)),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const LibraryIcon(LibraryIconType.comments, color: primaryColor, size: 34),
        const SizedBox(width: 12),
        Text('تبادل التعليقات', style: mediumStyle(fontSize: 22)),
      ],
    );
  }

  Future<void> _exportComments() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ التعليقات',
      fileName: '${DateTime.now().toIso8601String().split('T').first}.pk',
      type: FileType.custom,
      allowedExtensions: ['pk'],
    );
    if (path == null) return;

    await _run(() async {
      final bytes = await PageCommentsRepository.instance.exportShamelaPk();
      final target = path.toLowerCase().endsWith('.pk') ? path : '$path.pk';
      await File(target).writeAsBytes(bytes, flush: true);
      _status = 'تم حفظ التعليقات في الملف.';
    });
  }

  Future<void> _importComments() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'إضافة التعليقات',
      type: FileType.custom,
      allowedExtensions: ['pk'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;

    await _run(() async {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final result = await PageCommentsRepository.instance.importShamelaPk(bytes);
      _status = [
        'تمت الإضافة: ${result.added}',
        'تم الدمج: ${result.merged}',
        'موجود سابقًا: ${result.unchanged}',
        'كتب غير مطابقة: ${result.skippedMissingBook}',
        'تعليقات غير صالحة: ${result.skippedInvalid}',
      ].join('\n');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await action();
    } catch (e) {
      _status = 'تعذر إتمام العملية: $e';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
