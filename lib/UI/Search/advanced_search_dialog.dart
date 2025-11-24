import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

// Data model for a single search result from MeiliSearch
class MeiliSearchHit {
  final String id;
  final String bookPath;
  final String bookName;
  final int pageNumber;
  final String sectionType;
  final String content;
  final String? rawContent;
  final Map<String, dynamic> formatted;

  MeiliSearchHit({
    required this.id,
    required this.bookPath,
    required this.bookName,
    required this.pageNumber,
    required this.sectionType,
    required this.content,
    this.rawContent,
    required this.formatted,
  });

  factory MeiliSearchHit.fromJson(Map<String, dynamic> json) {
    return MeiliSearchHit(
      id: json['id'],
      bookPath: json['book_path'],
      bookName: json['book_name'],
      pageNumber: json['page_number'],
      sectionType: json['section_type'],
      content: json['content'],
      rawContent: json['raw_content'],
      formatted: json['_formatted'] ?? {},
    );
  }

  String get snippet => formatted['content'] ?? content;
}

class AdvancedSearchDialog extends StatefulWidget {
  final Function(String, int) onResultTapped;
  final List<Map<String, dynamic>> indexedBooks;
  const AdvancedSearchDialog({Key? key, required this.onResultTapped, required this.indexedBooks}) : super(key: key);

  @override
  _AdvancedSearchDialogState createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _queryControllers = List.generate(5, (_) => TextEditingController());
  final _queryOperators = ['و (AND)', 'و (AND)', 'و (AND)', 'و (AND)'];
  
  final Map<String, bool> _searchSections = {
    'main': true,
    'footnote': false,
    'comment': false,
    'title': false,
  };

  bool _isExactMatch = false; // The new single switch for exact matching

  // State for search results
  final http.Client _client = http.Client();
  bool _isLoading = false;
  List<MeiliSearchHit> _results = [];
  int _totalCount = 0;
  String? _errorMessage;

  late Map<String, bool> _selectedBooks;

  @override
  void initState() {
    super.initState();
    _selectedBooks = { for (var book in widget.indexedBooks) book['book_path'] as String : true };
  }

  @override
  void dispose() {
    for (var controller in _queryControllers) {
      controller.dispose();
    }
    _client.close();
    super.dispose();
  }

  String _buildFilter(String query) {
    List<String> filters = [];

    // Book filter
    final selectedBookPaths = _selectedBooks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    if (selectedBookPaths.isNotEmpty && selectedBookPaths.length < widget.indexedBooks.length) {
       final bookFilters = selectedBookPaths.map((path) {
        // Escape backslashes for the filter string
        final escapedPath = path.replaceAll(r'\', r'\\');
        return 'book_path = "$escapedPath"';
      }).join(' OR ');
      filters.add('($bookFilters)');
    }

    // Section filter
    final selectedSections = _searchSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedSections.isNotEmpty && selectedSections.length < _searchSections.length) {
      final sectionFilters = selectedSections.map((sec) => 'section_type = "$sec"').join(' OR ');
      filters.add('($sectionFilters)');
    }

    // Exact match filter
    if (_isExactMatch && query.isNotEmpty) {
      // Escape double quotes in the user's query
      final escapedQuery = query.replaceAll('"', '\"');
      filters.add('raw_content CONTAINS "$escapedQuery"');
    }
    
    return filters.join(' AND ');
  }

  void _performSearch() async {
    String query = _queryControllers[0].text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _totalCount = 0;
      _errorMessage = null;
    });

    final filter = _buildFilter(query);
    final url = Uri.parse('http://127.0.0.1:7700/indexes/books/search');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'q': query,
      'filter': filter,
      'attributesToRetrieve': ['id', 'book_path', 'book_name', 'page_number', 'section_type', 'content', 'raw_content'],
      'attributesToHighlight': ['content'],
      'highlightPreTag': '<b>',
      'highlightPostTag': '</b>',
    });


    try {
      final response = await _client.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> hits = data['hits'];
        setState(() {
          _results = hits.map((hit) => MeiliSearchHit.fromJson(hit)).toList();
          _totalCount = data['estimatedTotalHits'] ?? 0;
        });
      } else {
        setState(() {
          _errorMessage = "Error from MeiliSearch: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to connect to MeiliSearch: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('بحث متقدم (MeiliSearch)', style: bigStyle()),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchQueryInputs(),
                const SizedBox(height: 20),
                _buildSearchScope(),
                const SizedBox(height: 20),
                _buildAdvancedOptions(),
                const SizedBox(height: 20),
                Divider(),
                _buildResultsView(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء', style: normalStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('بحث', style: normalStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchQueryInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. ماذا تريد أن تبحث عنه؟', style: mediumStyle()),
        const SizedBox(height: 10),
        // For now, only the first text field is used for the query.
        // The others are placeholders to maintain the UI.
        _buildSingleQueryRow(0),
        _buildSingleQueryRow(1, operatorIndex: 0),
        _buildSingleQueryRow(2, operatorIndex: 1),
        _buildSingleQueryRow(3, operatorIndex: 2),
        _buildSingleQueryRow(4, operatorIndex: 3),
      ],
    );
  }

  Widget _buildSingleQueryRow(int index, {int? operatorIndex}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (operatorIndex != null)
            Container(
              width: 100,
              child: DropdownButton<String>(
                value: _queryOperators[operatorIndex],
                isExpanded: true,
                items: ['و (AND)', 'أو (OR)', 'ليس (NOT)']
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: normalStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: null, // Disabled for now
              ),
            )
          else
            SizedBox(width: 100),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _queryControllers[index],
              decoration: InputDecoration(
                labelText: 'كلمة أو عبارة ${index + 1}',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              style: normalStyle(),
              enabled: index == 0, // Only first field enabled
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScope() {
    // This UI remains the same, the logic is now in _buildFilter()
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2. أين تريد البحث؟', style: mediumStyle()),
        const SizedBox(height: 10),
        Text('حدد الكتب:', style: normalStyle()),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
          ),
          child: ListView.builder(
            itemCount: widget.indexedBooks.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return CheckboxListTile(
                  title: Text('كلها', style: normalStyle()),
                  value: _selectedBooks.values.every((isSelected) => isSelected),
                  onChanged: (val) => setState(() => _selectedBooks.updateAll((key, value) => val!)),
                );
              }
              if (index == 1) {
                return CheckboxListTile(
                  title: Text('عكس التحديد', style: normalStyle()),
                  value: false,
                  onChanged: (val) => setState(() => _selectedBooks.updateAll((key, value) => !value)),
                );
              }
              final book = widget.indexedBooks[index - 2];
              final bookPath = book['book_path'] as String;
              final bookTitle = p.basenameWithoutExtension(bookPath);
              return CheckboxListTile(
                title: Text(bookTitle, style: normalStyle()),
                value: _selectedBooks[bookPath] ?? false,
                onChanged: (val) => setState(() => _selectedBooks[bookPath] = val!),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text('حدد أقسام النص:', style: normalStyle()),
        Wrap(
          spacing: 4.0,
          runSpacing: 0.0,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(value: _searchSections['main'], onChanged: (val) => setState(() => _searchSections['main'] = val!)),
              Text('المتن', style: normalStyle()),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(value: _searchSections['footnote'], onChanged: (val) => setState(() => _searchSections['footnote'] = val!)),
              Text('الحواشي', style: normalStyle()),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(value: _searchSections['comment'], onChanged: (val) => setState(() => _searchSections['comment'] = val!)),
              Text('التعليقات', style: normalStyle()),
            ]),
             Row(mainAxisSize: MainAxisSize.min, children: [
               Checkbox(value: _searchSections['title'], onChanged: (val) => setState(() => _searchSections['title'] = val!)),
               Text('العناوين', style: normalStyle()),
             ]),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3. خيارات البحث المتقدمة', style: mediumStyle()),
        SwitchListTile(
          title: Text('بحث مطابق تماماً', style: normalStyle()),
          subtitle: Text('إذا تم التفعيل، سيتم البحث بشكل دقيق مطابق للهمزات والتشكيل.', style: smallStyle()),
          value: _isExactMatch,
          onChanged: (bool value) {
            setState(() {
              _isExactMatch = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      print(_errorMessage);
      return Center(child: Text('حدث خطأ: $_errorMessage', style: normalStyle(color: Colors.red)));
    }

    if (_results.isEmpty) {
      return Center(child: Text('لا توجد نتائج', style: normalStyle()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('النتائج: $_totalCount', style: mediumStyle()),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final result = _results[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(result.bookName, style: normalStyle(fontWeight: FontWeight.bold)),
                subtitle: _buildSnippetText(result.snippet),
                leading: Text('ص ${result.pageNumber + 1}', style: normalStyle(color: primaryColor)),
                onTap: () {
                  widget.onResultTapped(result.bookPath, result.pageNumber);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSnippetText(String snippet) {
    List<TextSpan> spans = [];
    final normalStyle = smallStyle();
    final boldStyle = smallStyle().copyWith(fontWeight: FontWeight.bold);

    snippet.splitMapJoin(
      RegExp(r'<b>(.*?)</b>'),
      onMatch: (m) {
        spans.add(TextSpan(text: m.group(1), style: boldStyle));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(text: n, style: normalStyle));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
    );
  }
}
