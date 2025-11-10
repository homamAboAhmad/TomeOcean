import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/BookTitleRow.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';

import '../Helpers/FileHelper.dart';
import '../Styles/TextSyles.dart';
import '../Utils/FileToArchive.dart';
import '../main.dart';
import '../wordToHTML/AddDocData.dart';
import 'BooksDrawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WordDocument> openedBooks = [];
  String? filePath;
  int selectedBookP = 0;

  @override
  Widget build(BuildContext context) {
    print("openedBooks.length ${openedBooks.length}");
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Container(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text("البحر المحيط",
                  style: normalStyle(
                    fontSize: 24,
                    color: secondaryColor
                  )),
            ),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.menu,
                color: secondaryColor,
              ),
              // غير الأيقونة إذا بدك
              onPressed: () {
                Scaffold.of(context).openDrawer(); // هيك رح تشتغل
              },
            ),
          ),
        ),

        drawer: BooksDrawer(
          onBookSelected: _onBookSelected,
        ),
        // body: DocViewer(openedBooks[selectedBookP]),

        body: Stack(
          children: [
            if (openedBooks.isNotEmpty) openedBooksTitlesList(),
            if (openedBooks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48.0),
                child: DocViewer(openedBooks[selectedBookP],
                    onBookSelected: _onBookSelected),
              ),
          ],
        ),
      ),
    );
  }

  _onBookSelected(File book) async {
    filePath = book.path;
    await _readDocxFile(filePath);
    setState(() {});
  }

  // هذه هي الدالة المعدلة باستخدام LongPressDraggable
  Widget openedBooksTitlesList() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8, top: 24),
      child: SizedBox(
        height: 24,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: openedBooks.length,
          itemBuilder: (context, i) {
            WordDocument book = openedBooks[i];

            return DragTarget<int>(
              onWillAccept: (data) => true,
              onAccept: (oldIndex) {
                setState(() {
                  final newIndex = i;
                  if (oldIndex != newIndex) {
                    final WordDocument draggedBook = openedBooks.removeAt(oldIndex);
                    openedBooks.insert(newIndex, draggedBook);
                  }
                });
              },
              builder: (context, candidateData, rejectedData) {
                return LongPressDraggable(
                  data: i, // نمرر فهرس العنصر الحالي
                  delay: Duration(milliseconds: 300), // يبدأ السحب فوراً
                  feedback: Material( // الشكل الذي يظهر أثناء السحب
                    elevation: 4.0,
                    child: BookTitleRow(
                      title: book.title,
                      isChoosed: true, // أثناء السحب يظهر كأنه محدد
                      onTab: () {},
                      onClose: () {},
                    ),
                  ),
                  child: BookTitleRow(
                    title: book.title,
                    isChoosed: selectedBookP == i,
                    onTab: () => _switchToBook(i),
                    onClose: () => _closeBook(i),
                    key: ValueKey(book.title), // استخدام مفتاح فريد وثابت
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }  _closeBook(int i) {
    print("remove $i");
    openedBooks.removeAt(i);
    selectedBookP = openedBooks.length - 1;
    setState(() {});
  }

  _switchToBook(int i) {
    selectedBookP = i;
    setState(() {});
  }

  Future<void> _readDocxFile(String? filePath) async {
    if (filePath == null) return;
    // if (result != null) filePath = result!.files.single.path!;
    WordDocument wordDocument = WordDocument();
    wordDocument.title = getFileName(filePath);
    openedBooks.add(wordDocument);
    selectedBookP = openedBooks.length - 1;
    docArchive = await FileToArchive(filePath);
    AddDocData(docArchive, wordDocument);
    await Future.delayed(Duration(milliseconds: 1500), () {});
  }
}
