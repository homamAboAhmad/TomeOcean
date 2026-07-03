import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:path/path.dart' as p;

class FolderImportPreviewDialog extends StatefulWidget {
  final List<File> files;
  final String folderPath;
  final String? title;
  final String? subtitle;
  final IconData icon;
  final String confirmLabel;
  final bool allowReorder;
  final int minSelectionCount;

  const FolderImportPreviewDialog({
    required this.files,
    required this.folderPath,
    this.title,
    this.subtitle,
    this.icon = Icons.folder_open_rounded,
    this.confirmLabel = 'بدء الاستيراد',
    this.allowReorder = false,
    this.minSelectionCount = 1,
    super.key,
  });

  @override
  State<FolderImportPreviewDialog> createState() =>
      _FolderImportPreviewDialogState();
}

class _FolderImportPreviewDialogState extends State<FolderImportPreviewDialog> {
  late List<File> _files;
  late Map<String, bool> _selectedFiles;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _files = List<File>.of(widget.files);
    _selectedFiles = {for (var f in _files) f.path: true};
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      for (var key in _selectedFiles.keys) {
        _selectedFiles[key] = _selectAll;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int selectedCount = _selectedFiles.values.where((v) => v).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(selectedCount),
              _buildSelectAllBar(),
              const Divider(height: 1),
              _buildFilesList(),
              const Divider(height: 1),
              _buildFooter(selectedCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          LibraryIcon.fromIcon(widget.icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'استيراد من مجلد',
                  style: bigStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  widget.subtitle ??
                      'تم العثور على ${_files.length} كتاب في ${p.basename(widget.folderPath)}',
                  style: normalStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            activeColor: primaryColor,
            onChanged: _toggleSelectAll,
          ),
          Text(
            'تحديد الكل',
            style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            '${_selectedFiles.values.where((v) => v).length} مختار',
            style: normalStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return Flexible(
      child: widget.allowReorder
          ? ReorderableListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _files.length,
              onReorder: _reorderFile,
              itemBuilder: (context, index) => _buildFileTile(_files[index]),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _files.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _buildFileTile(_files[index]),
            ),
    );
  }

  Widget _buildFileTile(File file) {
    final fileName = p.basename(file.path);
    final filePath = file.path;
    final subtitle = widget.folderPath.trim().isEmpty
        ? p.dirname(filePath)
        : p.relative(filePath, from: widget.folderPath);

    return CheckboxListTile(
      key: ValueKey(filePath),
      value: _selectedFiles[filePath],
      activeColor: primaryColor,
      secondary: widget.allowReorder
          ? const LibraryIcon(LibraryIconType.tune, color: Colors.grey)
          : null,
      title: Text(
        fileName,
        style: normalStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: smallStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: (value) {
        setState(() {
          _selectedFiles[filePath] = value ?? false;
          _selectAll = _selectedFiles.values.every((v) => v);
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _reorderFile(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final file = _files.removeAt(oldIndex);
      _files.insert(newIndex, file);
    });
  }

  Widget _buildFooter(int selectedCount) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: normalStyle(color: Colors.red)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: selectedCount >= widget.minSelectionCount
                ? () {
                    final selectedPaths = _files
                        .where((f) => _selectedFiles[f.path] == true)
                        .map((f) => f.path)
                        .toList();
                    Navigator.pop(context, selectedPaths);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '${widget.confirmLabel} ($selectedCount)',
              style: normalStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
