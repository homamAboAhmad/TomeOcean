import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:path/path.dart' as p;

class BatchMetadataInputDialog extends StatefulWidget {
  final List<String> filePaths;

  const BatchMetadataInputDialog({required this.filePaths, super.key});

  @override
  State<BatchMetadataInputDialog> createState() =>
      _BatchMetadataInputDialogState();
}

class _BatchMetadataItem {
  final String filePath;
  final TextEditingController titleController;
  final TextEditingController authorController;
  Author? selectedAuthor;
  String? sectionId;

  _BatchMetadataItem({
    required this.filePath,
    required String initialTitle,
    String initialAuthor = '',
    this.selectedAuthor,
    this.sectionId,
  }) : titleController = TextEditingController(text: initialTitle),
       authorController = TextEditingController(text: initialAuthor);

  void dispose() {
    titleController.dispose();
    authorController.dispose();
  }
}

class _BatchMetadataInputDialogState extends State<BatchMetadataInputDialog> {
  final List<_BatchMetadataItem> _items = [];
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  bool _isLoading = true;

  // Global values for "Apply to all"
  Author? _commonAuthor;
  final TextEditingController _commonAuthorController = TextEditingController();
  String? _commonSectionId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authors = await AuthorStorage().getAuthorsAsync();
    final sections = await SectionStorage().getSectionsAsync();

    _allAuthors = authors;
    _allSections = sections;

    for (final path in widget.filePaths) {
      _items.add(
        _BatchMetadataItem(
          filePath: path,
          initialTitle: p.basenameWithoutExtension(path),
          sectionId: sections.isNotEmpty ? sections.first.id : null,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    _commonAuthorController.dispose();
    super.dispose();
  }

  void _applyCommonAuthor() {
    setState(() {
      for (var item in _items) {
        item.selectedAuthor = _commonAuthor;
        item.authorController.text = _commonAuthorController.text;
      }
    });
  }

  void _applyCommonSection() {
    setState(() {
      for (var item in _items) {
        item.sectionId = _commonSectionId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'بيانات الكتب الجديدة',
                style: bigStyle(fontSize: 22, color: primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Global controls
              _buildGlobalControls(),
              const Divider(height: 32),

              // Table Header
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'اسم الكتاب',
                      style: normalStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'المؤلف',
                      style: normalStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'التصنيف',
                      style: normalStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // List of items
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildItemRow(_items[index]),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text('إلغاء', style: normalStyle()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'بدأ الاستيراد',
                      style: normalStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تطبيق سريع على الكل:',
            style: normalStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAuthorAutocomplete(
                  controller: _commonAuthorController,
                  onSelected: (a) {
                    _commonAuthorController.text = a.name;
                    setState(() => _commonAuthor = a);
                  },
                  onChanged: (v) {
                    _commonAuthorController.text = v;
                    _commonAuthor = _allAuthors.firstWhere(
                      (a) => a.name == v,
                      orElse: () => Author(name: ''),
                    );
                    if (_commonAuthor!.name.isEmpty) _commonAuthor = null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyCommonAuthor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                ),
                child: const Text('تطبيق المؤلف'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSectionDropdown(
                  value: _commonSectionId,
                  onChanged: (v) => setState(() => _commonSectionId = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyCommonSection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                ),
                child: const Text('تطبيق التصنيف'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(_BatchMetadataItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.titleController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              style: normalStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _buildAuthorAutocomplete(
              controller: item.authorController,
              onSelected: (a) {
                item.authorController.text = a.name;
                item.selectedAuthor = a;
              },
              onChanged: (v) {
                item.authorController.text = v;
                item.selectedAuthor = _allAuthors.firstWhere(
                  (a) => a.name == v,
                  orElse: () => Author(name: ''),
                );
                if (item.selectedAuthor!.name.isEmpty)
                  item.selectedAuthor = null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildSectionDropdown(
              value: item.sectionId,
              onChanged: (v) => setState(() => item.sectionId = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAutocomplete({
    required TextEditingController controller,
    required Function(Author) onSelected,
    required Function(String) onChanged,
  }) {
    return Autocomplete<Author>(
      displayStringForOption: (Author a) => a.name,
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const Iterable<Author>.empty();
        return _allAuthors.where((a) => a.name.contains(value.text));
      },
      onSelected: (Author selection) {
        controller.text = selection.name;
        onSelected(selection);
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            // Syncing logic
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (fieldController.text != controller.text) {
                fieldController.text = controller.text;
              }
            });

            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'اسم المؤلف',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              style: normalStyle(fontSize: 14),
              onChanged: onChanged,
            );
          },
    );
  }

  Widget _buildSectionDropdown({
    String? value,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true, // لضمان عدم قص النص
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: _allSections
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(
                s.title,
                style: normalStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  void _submit() {
    final Map<String, BookCard> results = {};
    final Map<String, Author> consolidatedNewAuthors = {};

    for (var item in _items) {
      Author? author = item.selectedAuthor;
      if (author == null && item.authorController.text.isNotEmpty) {
        final name = item.authorController.text.trim();
        if (consolidatedNewAuthors.containsKey(name)) {
          author = consolidatedNewAuthors[name];
        } else {
          author = Author(name: name);
          consolidatedNewAuthors[name] = author!;
        }
      }

      results[item.filePath] = BookCard(
        title: item.titleController.text,
        authorId: author?.id ?? '',
        sectionId: item.sectionId ?? '',
      );
    }

    Navigator.pop(context, {
      'results': results,
      'newAuthors': consolidatedNewAuthors.values.toList(),
    });
  }
}
