import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:path/path.dart' as p;

class FolderImportPreviewDialog extends StatefulWidget {
  final List<File> files;
  final String folderPath;

  const FolderImportPreviewDialog({
    required this.files,
    required this.folderPath,
    super.key,
  });

  @override
  State<FolderImportPreviewDialog> createState() =>
      _FolderImportPreviewDialogState();
}

class _FolderImportPreviewDialogState extends State<FolderImportPreviewDialog> {
  late Map<String, bool> _selectedFiles;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _selectedFiles = {for (var f in widget.files) f.path: true};
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
          const Icon(Icons.folder_open_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'استيراد من مجلد',
                  style: bigStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'تم العثور على ${widget.files.length} كتاب في ${p.basename(widget.folderPath)}',
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
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.files.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final file = widget.files[index];
          final fileName = p.basename(file.path);
          final filePath = file.path;

          return CheckboxListTile(
            value: _selectedFiles[filePath],
            activeColor: primaryColor,
            title: Text(
              fileName,
              style: normalStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              p.relative(filePath, from: widget.folderPath),
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
        },
      ),
    );
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
            onPressed: selectedCount > 0
                ? () {
                    final selectedPaths = widget.files
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
              'بدء الاستيراد ($selectedCount)',
              style: normalStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
