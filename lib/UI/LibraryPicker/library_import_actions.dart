import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/dialogs/batch_file_processing_dialog.dart';
import 'package:golden_shamela/UI/dialogs/folder_import_preview_dialog.dart';
import 'package:golden_shamela/UI/home_page/home_page_book_management.dart';

class LibraryImportActions {
  const LibraryImportActions._();

  static Future<bool> pickDocxFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      allowMultiple: true,
    );
    final paths = result?.files
        .map((file) => file.path)
        .whereType<String>()
        .toList();
    if (paths == null || paths.isEmpty) return false;
    return _processImportedPaths(context, paths);
  }

  static Future<bool> pickFolder(BuildContext context) async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return false;

    _showLoadingDialog(context, 'جاري فحص المجلد...');
    final books = await HomePageBookManagement.collectBooksFromFolder(
      folderPath,
    );
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return false;

    if (books.isEmpty) {
      _showMessage(context, 'لم يتم العثور على ملفات docx داخل المجلد');
      return false;
    }

    final selectedPaths = await showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => FolderImportPreviewDialog(
        files: books,
        folderPath: folderPath,
      ),
    );
    if (selectedPaths == null || selectedPaths.isEmpty) return false;
    return _processImportedPaths(context, selectedPaths);
  }

  static Future<bool> _processImportedPaths(
    BuildContext context,
    List<String> paths,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchFileProcessingDialog(filePaths: paths),
    );
    return true;
  }

  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
