import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import '../Controllers/PathController.dart';
import 'dialogs/file_processing_dialog.dart';

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
        return name.toLowerCase().endsWith('.docx') && !name.startsWith('~\$');
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
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: secondaryColor, width: 2),
            ),
            child: const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.menu_book_rounded,
                color: primaryColor,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'البحر المحيط',
            style: bigStyle(color: Colors.white, fontSize: 22),
          ),
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
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _pickDocxFile,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: secondaryColor),
            const SizedBox(width: 8),
            Text(
              'إضافة كتاب جديد',
              style: normalStyle(color: secondaryColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocxFile() async {
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      if (result != null) {
        final filePath = result!.files.single.path!;
        if (mounted) {
          final processingResult = await showFileProcessDailog(
            context,
            filePath,
            update: true,
          );

          loadBooks();

          if (processingResult != null && processingResult.success) {
            if (mounted) Navigator.pop(context);

            final fileName = filePath.split('\\').last.split('/').last;
            final bookFile = File('$BOOKS_FOLDER_PATH\\$fileName');
            if (await bookFile.exists()) {
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
