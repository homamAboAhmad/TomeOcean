import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Constants.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

import '../Controllers/PathController.dart';
import '../TestApp.dart';

class BooksDrawer extends StatefulWidget {
  final void Function(File) onBookSelected;

  BooksDrawer({required this.onBookSelected, super.key});

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

  @override
  Widget build(BuildContext context) {
    // loadBooks();
    return Drawer(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          _headerW(),
          _booksListW(),
          _pickBtnW(),
        ],
      ),
    );
  }

  void loadBooks() async {
    final dir = Directory(BOOKS_FOLDER_PATH);
    print(BOOKS_FOLDER_PATH);
    if (await dir.exists()) {
      final files = dir
          .listSync()
          .whereType<File>()
          // .where((f) => f.path.endsWith('.docx')) // لو حابب تحدد نوع الملفات
          .toList();
      setState(() => bookFiles = files);
    }
  }

  _pickBtnW() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: secondaryColor.withOpacity(0.8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // القيمة التي تريدها
              ),
            ),
            onPressed: _pickDocxFile,
            child: Text(
              'إضافة كتاب جديد',
              style: normalStyle(
                color: primaryColor,

              ),
            ),
          ),
        ),
      ),
    );
  }

  _pickDocxFile() async {
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      if (result != null) {
        await showFileProcessDailog(context, result!.files.single.path!,
            update: true);
        loadBooks();
        setState(() {});
      }
    } catch (e) {
      setState(() {});
    }
  }

  _headerW() {
    String logo_path = "assets/icons/logo.png";
    return Image.asset(
      logo_path,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      height: 196,
    );
  }

  _booksListW() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 64.0, top: 212),
      child:
          ListView(children: bookFiles.map((file) => _bookRow(file)).toList()),
    );
  }

  Widget _bookRow(File file) {
    String bookName = getFileName(file.path);
    print(file.path);
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onBookSelected(file);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          borderRadius: BorderRadius.circular(8),
          color: primaryColor.withOpacity(0.9),
          elevation: 2,

          child: Center(child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(bookName,style: normalStyle(color: secondaryColor,),),
          ))),
      ),
    );

  }
}
