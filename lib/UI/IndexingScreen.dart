import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:path/path.dart' as p;

class IndexingScreen extends StatefulWidget {
  const IndexingScreen({super.key});

  @override
  State<IndexingScreen> createState() => _IndexingScreenState();
}

class _IndexingScreenState extends State<IndexingScreen> {
  IndexingProgress _progress = IndexingProgress(message: 'جاهز للفهرسة.');
  bool _isIndexing = false;
  final ShamelaSearchIndexer _indexer = ShamelaSearchIndexer();
  final ValueNotifier<bool> _cancellationNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _cancellationNotifier.dispose();
    super.dispose();
  }

  Future<void> _startIndexing() async {
    setState(() {
      _isIndexing = true;
      _progress = IndexingProgress(message: 'جارٍ بدء الفهرسة...');
    });
    _cancellationNotifier.value = false; // Reset cancellation flag

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        setState(() {
          _progress = IndexingProgress(message: 'تم إلغاء اختيار المجلد.');
          _isIndexing = false;
        });
        return;
      }

      setState(() {
        _progress = IndexingProgress(message: 'جارٍ البحث عن ملفات .docx...');
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
          _progress = IndexingProgress(message: 'لم يتم العثور على ملفات .docx.');
          _isIndexing = false;
        });
        return;
      }

      setState(() {
        _progress = IndexingProgress(
          message: 'تم العثور على ${bookPaths.length} كتاب. جارٍ بدء الفهرسة...'
        );
      });

      await _indexer.indexBooks(bookPaths, (progressUpdate) {
        setState(() {
          _progress = progressUpdate;
        });
      }, _cancellationNotifier);

      setState(() {
        _progress = IndexingProgress(message: 'اكتملت الفهرسة بنجاح!');
      });
    } catch (e) {
      setState(() {
        _progress = IndexingProgress(message: 'حدث خطأ أثناء الفهرسة: $e');
      });
    } finally {
      setState(() {
        _isIndexing = false;
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
        title: Text('فهرسة الكتب'),
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
                      child: const Text('اختر مجلد الكتب وابدأ الفهرسة'),
                    ),
                  if (_isIndexing)
                    ElevatedButton(
                      onPressed: _cancelIndexing,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('إلغاء الفهرسة'),
                    ),
                  const SizedBox(height: 20),
                  if (_isIndexing) ...[
                    const Text('التقدم الإجمالي:'),
                    LinearProgressIndicator(value: _progress.overallProgress),
                    const SizedBox(height: 10),
                    Text('${_progress.currentBookNum} / ${_progress.totalBooks} كتاب'),
                    const SizedBox(height: 20),
                    const Text('تقدم الكتاب الحالي:'),
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
          ],
        ),
      ),
    );
  }
}
