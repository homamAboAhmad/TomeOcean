import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:golden_shamela/database/search_indexer.dart';
import 'package:golden_shamela/database/search_database_helper.dart';
import 'package:path/path.dart' as p;

class IndexingScreen extends StatefulWidget {
  const IndexingScreen({super.key});

  @override
  State<IndexingScreen> createState() => _IndexingScreenState();
}

class _IndexingScreenState extends State<IndexingScreen> {
  IndexingProgress _progress = IndexingProgress(message: 'Ready to index.');
  bool _isIndexing = false;
  final SearchIndexer _indexer = SearchIndexer();
  final ValueNotifier<bool> _cancellationNotifier = ValueNotifier(false);
  List<Map<String, dynamic>> _indexedBooks = [];

  @override
  void initState() {
    super.initState();
    _loadIndexedBooks();
  }

  @override
  void dispose() {
    _cancellationNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadIndexedBooks() async {
    final books = await SearchDatabaseHelper.instance.getAllIndexedBooksMetadata();
    setState(() {
      _indexedBooks = books;
    });
  }

  Future<void> _startIndexing() async {
    setState(() {
      _isIndexing = true;
      _progress = IndexingProgress(message: 'Selecting books folder...');
    });
    _cancellationNotifier.value = false; // Reset cancellation flag

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        setState(() {
          _progress = IndexingProgress(message: 'Folder selection cancelled.');
          _isIndexing = false;
        });
        return;
      }

      setState(() {
        _progress = IndexingProgress(message: 'Finding .docx files...');
      });

      final dir = Directory(selectedDirectory);
      final List<String> bookPaths = [];
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.docx')) {
          bookPaths.add(entity.path);
        }
      }

      if (bookPaths.isEmpty) {
        setState(() {
          _progress = IndexingProgress(message: 'No .docx files found.');
          _isIndexing = false;
        });
        return;
      }

      setState(() {
        _progress = IndexingProgress(
            message: 'Found ${bookPaths.length} books. Starting indexing...');
      });

      await _indexer.indexBooks(bookPaths, (progressUpdate) {
        setState(() {
          _progress = progressUpdate;
        });
      }, _cancellationNotifier);

    } catch (e) {
      setState(() {
        _progress = IndexingProgress(message: 'An error occurred: $e');
      });
    } finally {
      setState(() {
        _isIndexing = false;
        _loadIndexedBooks(); // Reload the list of indexed books
      });
    }
  }

  void _cancelIndexing() {
    setState(() {
      _progress = IndexingProgress(
        message: 'Cancellation requested...',
        totalBooks: _progress.totalBooks,
        currentBookNum: _progress.currentBookNum,
      );
    });
    _cancellationNotifier.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Indexing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  if (!_isIndexing)
                    ElevatedButton(
                      onPressed: _startIndexing,
                      child: const Text('Select Books Folder and Index'),
                    ),
                  if (_isIndexing)
                    ElevatedButton(
                      onPressed: _cancelIndexing,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Cancel Indexing'),
                    ),
                  const SizedBox(height: 20),
                  if (_isIndexing) ...[
                    const Text('Overall Progress:'),
                    LinearProgressIndicator(value: _progress.overallProgress),
                    const SizedBox(height: 10),
                    Text('${_progress.currentBookNum} / ${_progress.totalBooks} books'),
                    const SizedBox(height: 20),
                    const Text('Current Book Progress:'),
                    LinearProgressIndicator(value: _progress.currentBookProgress),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _progress.message,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Indexed Books (${_indexedBooks.length}):',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _indexedBooks.length,
                itemBuilder: (context, index) {
                  final book = _indexedBooks[index];
                  final bookName = p.basename(book['book_path']);
                  final indexedDate = DateTime.fromMillisecondsSinceEpoch(book['indexed_date']).toLocal().toString().split(' ')[0];
                  return ListTile(
                    title: Text(bookName),
                    subtitle: Text('Pages: ${book['page_count']} | Indexed: $indexedDate'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
