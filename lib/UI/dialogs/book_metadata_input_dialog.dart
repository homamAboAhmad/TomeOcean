import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:golden_shamela/Helpers/DocxParser.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/Models/Section.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:path/path.dart' as p;

class BookMetadataResult {
  final BookCard bookCard;
  final Author? newAuthor;
  final Section? newSection;

  BookMetadataResult({required this.bookCard, this.newAuthor, this.newSection});
}

class BookMetadataInputDialog extends StatefulWidget {
  final String filePath;

  const BookMetadataInputDialog({required this.filePath, super.key});

  @override
  State<BookMetadataInputDialog> createState() =>
      _BookMetadataInputDialogState();
}

class _BookMetadataInputDialogState extends State<BookMetadataInputDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _deathYearController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _editionController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedSectionId;
  String? _selectedBookType;
  bool _matchesPrinted = false;
  List<Author> _allAuthors = [];
  List<Section> _allSections = [];
  bool _isLoading = true;

  Author? _selectedAuthor;
  bool _isNewAuthor = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Load existing data
    final authors = await AuthorStorage().getAuthorsAsync();
    final sections = await SectionStorage().getSectionsAsync();

    // 2. Extract metadata from file
    final metadata = await DocxParser.extractMetadata(widget.filePath);

    if (mounted) {
      setState(() {
        _allAuthors = authors;
        _allSections = sections;

        _titleController.text = metadata['title']?.isNotEmpty == true
            ? metadata['title']!
            : p.basenameWithoutExtension(widget.filePath);

        final extractedAuthor = metadata['creator'];
        if (extractedAuthor != null && extractedAuthor.isNotEmpty) {
          _authorController.text = extractedAuthor;
          // Check if author exists
          final existingAuthor = _allAuthors.firstWhere(
            (a) => a.name == extractedAuthor,
            orElse: () => Author(name: ''),
          );
          if (existingAuthor.name.isNotEmpty) {
            _selectedAuthor = existingAuthor;
            _deathYearController.text = existingAuthor.deathYear ?? '';
          } else {
            _isNewAuthor = true;
          }
        }

        if (_allSections.isNotEmpty) {
          _selectedSectionId = _allSections.first.id;
        }

        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _deathYearController.dispose();
    _publisherController.dispose();
    _editionController.dispose();
    _pageCountController.dispose();
    _notesController.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات الكتاب الجديد',
                    style: bigStyle(fontSize: 20, color: primaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  _buildTextField(
                    controller: _titleController,
                    label: 'عنوان الكتاب',
                    validator: (v) =>
                        v?.isEmpty == true ? 'يرجى إدخال العنوان' : null,
                  ),
                  const SizedBox(height: 16),

                  // Author Autocomplete
                  _buildAuthorAutocomplete(),
                  if (_selectedAuthor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        '✓ هذا المؤلف موجود مسبقاً في مكتبتك',
                        style: normalStyle(
                          fontSize: 12,
                          color: Colors.green[700]!,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Death Year (visible if new author or existing author without death year)
                  if (_isNewAuthor || (_selectedAuthor != null))
                    _buildTextField(
                      controller: _deathYearController,
                      label: 'تاريخ وفاة المؤلف (هـ)',
                      hint: 'مثال: 545',
                      enabled:
                          _isNewAuthor || _selectedAuthor?.deathYear == null,
                    ),
                  const SizedBox(height: 16),

                  // Section Dropdown
                  _buildSectionDropdown(),
                  const SizedBox(height: 16),

                  _buildBookTypeDropdown(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: _matchesPrinted,
                          onChanged: (v) =>
                              setState(() => _matchesPrinted = v ?? false),
                          title: Text('موافق للمطبوع', style: normalStyle()),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _publisherController,
                    label: 'الناشر',
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _editionController,
                          label: 'الطبعة',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _pageCountController,
                          label: 'عدد الصفحات',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  _buildTextField(
                    controller: _notesController,
                    label: 'ملاحظات إضافية',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'إلغاء',
                            style: normalStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'متابعة',
                            style: normalStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBookType,
      decoration: InputDecoration(
        labelText: 'نوع الكتاب',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: BookMetadataOptions.bookTypes
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(BookMetadataOptions.typeLabel(type), style: normalStyle()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedBookType = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'يرجى اختيار نوع الكتاب' : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      maxLines: maxLines,
      validator: validator,
      enabled: enabled,
      style: normalStyle(),
    );
  }

  Widget _buildAuthorAutocomplete() {
    return Autocomplete<Author>(
      displayStringForOption: (Author a) => a.name,
      initialValue: TextEditingValue(text: _authorController.text),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const Iterable<Author>.empty();
        return _allAuthors.where((a) => a.name.contains(value.text));
      },
      onSelected: (Author a) {
        setState(() {
          _selectedAuthor = a;
          _authorController.text = a.name;
          _deathYearController.text = a.deathYear ?? '';
          _isNewAuthor = false;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (_authorController.text != controller.text &&
            _selectedAuthor == null) {
          // controller.text = _authorController.text;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'اسم المؤلف',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: const Icon(Icons.person_search),
          ),
          style: normalStyle(),
          onChanged: (v) {
            _authorController.text = v;
            setState(() {
              _selectedAuthor = _allAuthors.firstWhere(
                (a) => a.name == v,
                orElse: () => Author(name: ''),
              );
              if (_selectedAuthor!.name.isEmpty) {
                _selectedAuthor = null;
                _isNewAuthor = v.isNotEmpty;
              } else {
                _deathYearController.text = _selectedAuthor!.deathYear ?? '';
                _isNewAuthor = false;
              }
            });
          },
          validator: (v) => v?.isEmpty == true ? 'يرجى إدخال اسم المؤلف' : null,
        );
      },
    );
  }

  Widget _buildSectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSectionId,
      decoration: InputDecoration(
        labelText: 'التصنيف',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        ..._allSections.map(
          (s) => DropdownMenuItem(
            value: s.id,
            child: Text(s.title, style: normalStyle()),
          ),
        ),
        DropdownMenuItem(
          value: 'new',
          child: Text(
            '+ إضافة تصنيف جديد',
            style: normalStyle(color: primaryColor),
          ),
        ),
      ],
      onChanged: (val) async {
        if (val == 'new') {
          final newSection = await _showAddSectionDialog();
          if (newSection != null) {
            setState(() {
              _allSections.add(newSection);
              _selectedSectionId = newSection.id;
            });
          } else {
            // Reset if cancelled
            setState(() {});
          }
        } else {
          setState(() => _selectedSectionId = val);
        }
      },
    );
  }

  Future<Section?> _showAddSectionDialog() async {
    final controller = TextEditingController();
    return showDialog<Section>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إضافة تصنيف جديد', style: bigStyle(fontSize: 18)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'اسم التصنيف'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(ctx, Section(title: controller.text));
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      Author? newAuthor;
      String authorId;

      if (_selectedAuthor != null) {
        // فحص إذا تم تغيير سنة الوفاة لمؤلف موجود
        if (_deathYearController.text != (_selectedAuthor!.deathYear ?? '')) {
          final confirm = await _showConfirmUpdateAuthorDialog();
          if (confirm != true) return;
        }
        authorId = _selectedAuthor!.id;
      } else {
        newAuthor = Author(
          name: _authorController.text,
          deathYear: _deathYearController.text.isNotEmpty
              ? _deathYearController.text
              : null,
        );
        authorId = newAuthor.id;
      }

      final bookCard = BookCard(
        title: _titleController.text,
        authorId: authorId,
        sectionId: _selectedSectionId ?? '',
        description: _notesController.text,
        bookType: _selectedBookType ?? '',
        matchesPrinted: _matchesPrinted,
        publisher: _publisherController.text.trim(),
        edition: _editionController.text.trim(),
        pageCount: _pageCountController.text.trim(),
      );

      Section? newSection;
      if (_selectedSectionId != null) {
        final existingSection = _allSections.any(
          (s) => s.id == _selectedSectionId,
        );
        if (!existingSection) {
          newSection = _allSections.firstWhere(
            (s) => s.id == _selectedSectionId,
          );
        }
      }

      if (mounted) {
        Navigator.pop(
          context,
          BookMetadataResult(
            bookCard: bookCard,
            newAuthor: newAuthor,
            newSection: newSection,
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmUpdateAuthorDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تحديث بيانات مؤلف',
            style: bigStyle(fontSize: 18, color: Colors.orange),
          ),
          content: Text(
            'لقد قمت بتعديل سنة الوفاة لمؤلف موجود مسبقاً. هذا التعديل سيظهر في جميع كتب هذا المؤلف في مكتبتك. هل أنت متأكد؟',
            style: normalStyle(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('نعم، تحديث الكل'),
            ),
          ],
        ),
      ),
    );
  }
}
