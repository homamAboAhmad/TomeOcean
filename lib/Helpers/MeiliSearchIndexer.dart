import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:http/http.dart' as http;

class MeiliSearchIndexer {
  final String _meiliUrl = 'http://127.0.0.1:7700';
  final String _indexName = 'books';
  final http.Client _client;

  MeiliSearchIndexer() : _client = http.Client();

  Future<void> configureIndex() async {
    print("MeiliSearchIndexer: Starting configureIndex()...");
    final url = Uri.parse('$_meiliUrl/indexes/$_indexName/settings');
    final headers = {'Content-Type': 'application/json'};

    // MeiliSearch has good defaults for Arabic, but we can customize if needed.
    // Here we specify which attributes are searchable and which can be used for filtering.
    final body = jsonEncode({
      'searchableAttributes': ['content'],
      'filterableAttributes': ['book_path', 'section_type', 'raw_content'],
      'rankingRules': [
        'words',
        'typo',
        'proximity',
        'attribute',
        'sort',
        'exactness',
      ],
      'stopWords': [ // Optional: Add custom Arabic stop words if needed
        // "من", "في", "على", "و", "او" 
      ]
    });

    try {
      final response = await _client.patch(url, headers: headers, body: body);
      if (response.statusCode == 202) {
        print("MeiliSearch index configuration accepted.");
      } else {
        print("Error configuring MeiliSearch index: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error communicating with MeiliSearch during configuration: $e");
    }
  }

  Future<void> indexBooks(
      List<String> bookFilePaths,
      Function(IndexingProgress progress) onProgress,
      ValueNotifier<bool> cancellationNotifier) async {
    print("MeiliSearchIndexer: Starting indexBooks()...");
    
    await configureIndex();

    int totalBooks = bookFilePaths.length;
    int currentBookNum = 0;

    for (String bookPath in bookFilePaths) {
      if (cancellationNotifier.value) {
        onProgress(IndexingProgress(message: 'Indexing cancelled.'));
        return;
      }

      currentBookNum++;
      String bookName = AppStoragePaths.displayTitleFromPath(bookPath);
      onProgress(IndexingProgress(
        message: 'Processing book: $bookName',
        totalBooks: totalBooks,
        currentBookNum: currentBookNum,
      ));

      try {
        List<WordPage> pages = await DocxParser.parse(bookPath);
        if (pages.isEmpty) {
          onProgress(IndexingProgress(message: 'Skipping empty book: $bookName'));
          continue;
        }

        List<Map<String, dynamic>> documents = [];
        for (int i = 0; i < pages.length; i++) {
          WordPage page = pages[i];
          for (int j = 0; j < page.ps.length; j++) {
            var paragraph = page.ps[j];
            if (paragraph.text.trim().isNotEmpty) {
              // Generate a unique and MeiliSearch-compatible ID
              // MeiliSearch IDs must be alphanumeric, hyphens, or underscores.
              // Base64 encode the bookPath to handle special characters and length,
              // then replace invalid base64 chars with underscores.
              String safeBookPath = base64Encode(utf8.encode(bookPath))
                  .replaceAll('+', '_')
                  .replaceAll('/', '_')
                  .replaceAll('=', ''); // Remove padding characters

              documents.add({
                'id': '${safeBookPath}_${i}_$j',
                'book_path': bookPath,
                'book_name': bookName,
                'page_number': i,
                'section_type': paragraph.sectionType,
                'content': paragraph.text,
                'raw_content': paragraph.text,
              });
            }
          }
        }

        // Send documents to MeiliSearch in batches
        int batchSize = 500;
        for (int i = 0; i < documents.length; i += batchSize) {
           if (cancellationNotifier.value) {
            onProgress(IndexingProgress(message: 'Indexing cancelled.'));
            return;
          }
          
          onProgress(IndexingProgress(
            message: 'Indexing: $bookName',
            totalBooks: totalBooks,
            currentBookNum: currentBookNum,
            totalPagesInBook: documents.length,
            currentPageNum: i + batchSize > documents.length ? documents.length : i + batchSize,
          ));

          final batch = documents.sublist(i, i + batchSize > documents.length ? documents.length : i + batchSize);
          print("MeiliSearchIndexer: Sending batch of ${batch.length} documents.");
          await _addDocuments(batch);
        }

      } catch (e) {
        onProgress(IndexingProgress(message: 'Error indexing $bookName: $e'));
      }
    }
     onProgress(IndexingProgress(
      message: 'Indexing complete for all books.',
      totalBooks: totalBooks,
      currentBookNum: totalBooks,
    ));
  }

  Future<void> _addDocuments(List<Map<String, dynamic>> documents) async {
    final url = Uri.parse('$_meiliUrl/indexes/$_indexName/documents');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(documents);

    try {
      final response = await _client.post(url, headers: headers, body: body);
      print("MeiliSearchIndexer: _addDocuments response status: ${response.statusCode}");
      print("MeiliSearchIndexer: _addDocuments response body: ${response.body}");
      if (response.statusCode == 202) {
        final data = jsonDecode(response.body);
        final taskUid = data['taskUid'];
        if (taskUid != null) {
          await _waitForTaskCompletion(taskUid);
        }
      } else {
        print("Error adding documents to MeiliSearch: ${response.body}");
      }
    } catch (e) {
      print("Error communicating with MeiliSearch during _addDocuments: $e");
    }
  }

  Future<void> _waitForTaskCompletion(int taskUid) async {
    final url = Uri.parse('$_meiliUrl/tasks/$taskUid');
    final headers = {'Content-Type': 'application/json'};

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500)); // Poll every 500ms
      try {
        final response = await _client.get(url, headers: headers);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          print("MeiliSearchIndexer: Task $taskUid status: $status");

          if (status == 'succeeded') {
            print("MeiliSearchIndexer: Task $taskUid completed successfully.");
            return;
          } else if (status == 'failed') {
            print("MeiliSearchIndexer: Task $taskUid failed. Error: ${data['error']}");
            return;
          }
        } else {
          print("MeiliSearchIndexer: Error polling task $taskUid: ${response.statusCode} - ${response.body}");
          return; // Exit on API error
        }
      } catch (e) {
        print("MeiliSearchIndexer: Error communicating with MeiliSearch while polling task $taskUid: $e");
        return; // Exit on network error
      }
    }
  }

  void dispose() {
    _client.close();
  }

  /// Retrieves a list of unique book paths and names from the MeiliSearch index.
  Future<List<Map<String, dynamic>>> getIndexedBooks() async {
    final url = Uri.parse('$_meiliUrl/indexes/$_indexName/documents?fields=book_path,book_name&limit=100000'); // Increased limit
    final headers = {'Content-Type': 'application/json'};

    try {
      final response = await _client.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> hits = data['results']; // MeiliSearch returns 'results' for documents endpoint
        // print("MeiliSearchIndexer: getIndexedBooks extracted hits: $hits");
        
        Set<String> uniqueBookPaths = {};
        List<Map<String, dynamic>> indexedBooks = [];

        for (var hit in hits) {
          final bookPath = hit['book_path'] as String;
          if (!uniqueBookPaths.contains(bookPath)) {
            uniqueBookPaths.add(bookPath);
            indexedBooks.add({
              'book_path': bookPath,
              'book_name': hit['book_name'] as String,
            });
          }
        }
        return indexedBooks;
      } else {
        print("Error getting indexed books from MeiliSearch: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error communicating with MeiliSearch to get indexed books: $e");
      return [];
    }
  }
}
