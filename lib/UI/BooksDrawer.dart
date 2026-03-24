import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import '../Controllers/PathController.dart';
import 'dialogs/file_processing_dialog.dart';
import 'dialogs/batch_file_processing_dialog.dart';
import 'dialogs/folder_import_preview_dialog.dart';
import 'home_page/home_page_book_management.dart';

class BooksDrawer extends StatefulWidget {
  final void Function(File) onBookSelected;

  const BooksDrawer({required this.onBookSelected, super.key});

  @override
  State<BooksDrawer> createState() => _BooksDrawerState();
}

class _BooksDrawerState extends State<BooksDrawer> {
  List<File> bookFiles = [];
  FilePickerResult? result;

  @override
  void initState() {
    super.initState();
    loadBooks();
  }

  void loadBooks() async {
    final dir = Directory(BOOKS_FOLDER_PATH);
    if (await dir.exists()) {
      final files = dir.listSync().whereType<File>().where((f) {
        final name = f.path.split(Platform.pathSeparator).last;
        return name.toLowerCase().endsWith('.docx') &&
            !name.startsWith('~\$') &&
            !name.startsWith('_temp_');
      }).toList();
      setState(() => bookFiles = files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      backgroundColor: const Color(0xFFF9FAFB),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBooksList()),
          _buildAddBookButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icons/logo.png',
              height: 80,
              width: 80,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text('المكتبة', style: bigStyle(color: Colors.white, fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            'مكتبتك الرقمية المتكاملة',
            style: normalStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    if (bookFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد كتب حالياً',
              style: normalStyle(color: Colors.grey[500]!),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: bookFiles.length,
      itemBuilder: (context, index) {
        final file = bookFiles[index];
        final bookName = getFileName(file.path);
        return _buildBookTile(file, bookName);
      },
    );
  }

  Widget _buildBookTile(File file, String bookName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          widget.onBookSelected(file);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book_outlined, color: primaryColor, size: 20),
        ),
        title: Text(
          bookName,
          style: normalStyle(color: Colors.black87, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAddBookButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _pickDocxFile,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة كتب مختارة',
                  style: normalStyle(color: secondaryColor, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _pickFolder,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'استيراد مجلد كامل',
                  style: normalStyle(color: primaryColor, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFolder() async {
    try {
      String? folderPath = await FilePicker.platform.getDirectoryPath();

      if (folderPath != null) {
        if (!mounted) return;

        // إظهار مؤشر تحميل أثناء مسح المجلد
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: primaryColor),
          ),
        );

        final List<File> books =
            await HomePageBookManagement.collectBooksFromFolder(folderPath);

        if (mounted) Navigator.pop(context); // إغلاق مؤشر التحميل

        if (books.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لم يتم العثور على كتب docx في هذا المجلد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'jreg'),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        if (mounted) {
          final List<String>? selectedPaths = await showDialog<List<String>>(
            context: context,
            barrierDismissible: true,
            builder: (ctx) =>
                FolderImportPreviewDialog(files: books, folderPath: folderPath),
          );

          if (selectedPaths != null && selectedPaths.isNotEmpty) {
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    BatchFileProcessingDialog(filePaths: selectedPaths),
              );

              loadBooks();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
    }
  }

  Future<void> _pickDocxFile() async {
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
        allowMultiple: true,
      );

      if (result != null && result!.files.isNotEmpty) {
        // Use the new World-Class Batch Dialog
        if (mounted) {
          final List<String> paths = result!.files.map((f) => f.path!).toList();

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => BatchFileProcessingDialog(filePaths: paths),
          );

          loadBooks();

          // Auto-select the last added book if success
          // Logic to find last added book:
          final lastPath = paths.last;
          final fileName = lastPath.split('\\').last.split('/').last;
          final bookFile = File('$BOOKS_FOLDER_PATH\\$fileName');
          if (await bookFile.exists()) {
            if (mounted) {
              Navigator.pop(context);
              widget.onBookSelected(bookFile);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }
}
