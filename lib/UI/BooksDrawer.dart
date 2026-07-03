import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Services/BookLibraryRepository.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/UI/LibraryPicker/library_import_actions.dart';
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
    final files = await BookLibraryRepository().loadAvailableBookSources();
    if (mounted) setState(() => bookFiles = files);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      backgroundColor: bgColor,
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
      decoration: BoxDecoration(
        gradient: AppChrome.headerGradient,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.18),
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
            LibraryIcon.fromIcon(
              Icons.library_books_outlined,
              size: 48,
              color: borderColor,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد كتب حالياً',
              style: normalStyle(color: accentColor.withOpacity(0.62)),
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
        final bookName = AppStoragePaths.displayTitleFromPath(file.path);
        return _buildBookTile(file, bookName);
      },
    );
  }

  Widget _buildBookTile(File file, String bookName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.fromBorderSide(AppChrome.borderSide()),
        boxShadow: AppChrome.softShadow,
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
            color: organicHighlightColor,
            borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
          ),
          child: const LibraryIcon(LibraryIconType.books, color: actionColor, size: 20),
        ),
        title: Text(
          bookName,
          style: AppUiFonts.style(
            AppFontRole.bookLists,
            normalStyle(color: accentColor, fontSize: 15),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: LibraryIcon.fromIcon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: borderColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
        ),
      ),
    );
  }

  Widget _buildAddBookButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: AppChrome.borderSide()),
        boxShadow: AppChrome.topShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
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
                LibraryIcon.fromIcon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة كتب مختارة',
                  style: normalStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: AppChrome.borderSide(opacity: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppChrome.radius),
              ),
            ),
            onPressed: _pickMultipartBook,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LibraryIcon.fromIcon(
                  Icons.library_books_outlined,
                  color: actionColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة كتاب من عدة أجزاء',
                  style: normalStyle(color: accentColor, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: AppChrome.borderSide(opacity: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppChrome.radius),
              ),
            ),
            onPressed: _pickFolder,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LibraryIcon.fromIcon(
                  Icons.folder_open_rounded,
                  color: actionColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'استيراد مجلد كامل',
                  style: normalStyle(color: accentColor, fontSize: 16),
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

  Future<void> _pickMultipartBook() async {
    if (await LibraryImportActions.pickMultipartBook(context)) {
      loadBooks();
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
        if (mounted) {
          final List<String> paths = result!.files.map((f) => f.path!).toList();
          final selectedPaths = await showDialog<List<String>>(
            context: context,
            barrierDismissible: true,
            builder: (context) => FolderImportPreviewDialog(
              files: paths.map((path) => File(path)).toList(),
              folderPath: '',
              title: 'إضافة كتب مختارة',
              subtitle: 'راجع الكتب التي سيتم إضافتها',
              icon: Icons.library_books_outlined,
              confirmLabel: 'بدء إضافة الكتب',
            ),
          );
          if (!mounted || selectedPaths == null || selectedPaths.isEmpty) {
            return;
          }

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                BatchFileProcessingDialog(filePaths: selectedPaths),
          );

          loadBooks();

          // Auto-select the last added book if success
          // Logic to find last added book:
          final lastPath = selectedPaths.last;
          final bookId = AppStoragePaths.bookIdFromPath(lastPath);
          final bookFile = File(AppStoragePaths.bookSourcePath(bookId));
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
