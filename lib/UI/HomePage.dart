import 'dart:io';
import 'dart:math';
import 'dart:convert'; // Added for JSON encoding/decoding

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/BookTitleRow.dart';
import 'package:golden_shamela/UI/DocViewer.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Utils/SnackBar.dart';
import 'package:path_provider/path_provider.dart'; // Added for cache directory

import 'package:golden_shamela/UI/TestScreen.dart'; // Add this import
import 'package:golden_shamela/UI/IndexingScreen.dart'; // Add this import
import 'package:golden_shamela/UI/Search/search_dialog.dart'; // Import SearchDialog
import 'package:golden_shamela/database/search_database_helper.dart'; // Import SearchResult

import 'package:path/path.dart' as p; // Import the path package

import '../Helpers/FileHelper.dart';
import '../Styles/TextSyles.dart';
import '../Utils/FileToArchive.dart';
import '../Utils/SnackBar.dart';
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
          actions: [ // Add this actions block
            IconButton(
              icon: Icon(Icons.search, color: secondaryColor),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SearchDialog(onResultTapped: _handleSearchResultNavigation),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.storage, color: secondaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  IndexingScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.bug_report, color: secondaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  TestScreen()),
                );
              },
            ),
          ],
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

  _onBookSelected(File book, {int? pageNumber}) async {
    filePath = book.path;
    await _readDocxFile(filePath);
    if (pageNumber != null) {
      openedBooks[selectedBookP].currentPage = pageNumber;
    }
    setState(() {});
  }

  void _handleSearchResultNavigation(SearchResult result) {
    _onBookSelected(File(result.bookPath), pageNumber: result.pageNumber);
    setState(() {}); // Update UI to reflect new book/page
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

    WordDocument wordDocument = WordDocument();
    wordDocument.title = getFileName(filePath);

    // 1. Generate Cache Path
    final appDocsDir = await getApplicationDocumentsDirectory();
    final tomeOceanDir = Directory('${appDocsDir.path}/tome_ocean');
    final bookCacheDir = Directory('${tomeOceanDir.path}/${wordDocument.title}');
    final metadataFile = File('${bookCacheDir.path}/metadata.json');
    final pagesDir = Directory('${bookCacheDir.path}/pages');

    print("Book cache path ${bookCacheDir.path}");
    bool loadedFromCache = false;

    // try {
      // 2. Check for existing, valid cache
      if (await bookCacheDir.exists()) {
        final docxFile = File(filePath);
        final docxLastModified = await docxFile.lastModified();
        final cacheLastModified = await metadataFile.lastModified();

        if (cacheLastModified.isAfter(docxLastModified)) {
          // Cache is valid, load from split files
          final jsonString = await metadataFile.readAsString();
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          wordDocument = WordDocument.fromCacheJson(jsonMap);
          wordDocument.pagesDirectory = pagesDir.path;

          // Load page file paths
          final pageFiles = await pagesDir.list().toList();
          pageFiles.sort((a, b) {
            final aNum = int.parse(p.basenameWithoutExtension(a.path));
            final bNum = int.parse(p.basenameWithoutExtension(b.path));
            return aNum.compareTo(bNum);
          });
          wordDocument.pageFilePaths = pageFiles.map((file) => p.basename(file.path)).toList();
          wordDocument.initLoadedPages();

          ShowSnackBar(context, "Loaded from cache: ${wordDocument.title}");
          loadedFromCache = true;
        }
      }
    // } catch (e) {
    //   print("Error loading from cache: $e");
    //   ShowSnackBar(context, "Error loading from cache, re-parsing: $e");
    //   if (await bookCacheDir.exists()) {
    //     await bookCacheDir.delete(recursive: true);
    //   }
    //   loadedFromCache = false;
    // }

    if (!loadedFromCache) {
      // 3. Parse and Save to Cache
      try {
        docArchive = await FileToArchive(filePath);
        List<WordPage> parsedPages = await AddDocData(docArchive, wordDocument);
        wordDocument.setLoadedPages(parsedPages);

        // Save to cache (split files)
        await bookCacheDir.create(recursive: true);
        await pagesDir.create(recursive: true);

        // Save metadata
        final metadataJsonMap = wordDocument.toMetadataJson();
        final metadataJsonString = jsonEncode(metadataJsonMap);
        await metadataFile.writeAsString(metadataJsonString);

        // Save pages
        wordDocument.pagesDirectory = pagesDir.path;
        for (int i = 0; i < parsedPages.length; i++) {
          final pageFile = File('${pagesDir.path}/$i.json');
          await pageFile.writeAsString(jsonEncode(parsedPages[i].toJson()));
        }

        ShowSnackBar(context, "Parsed and saved to cache: ${wordDocument.title}");
      } catch (e) {
        print("Error parsing docx or saving to cache: $e");
        ShowSnackBar(context, "Error parsing docx: $e");
        return; // Stop if parsing fails
      }
    }

    openedBooks.add(wordDocument);
    selectedBookP = openedBooks.length - 1;
    await Future.delayed(Duration(milliseconds: 1500), () {});
  }
}
