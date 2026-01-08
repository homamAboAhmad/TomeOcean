import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _booksDirectoryPath;
  String _searchWindowMode = 'separate'; // 'separate' or 'in_app'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final savedPath = PreferencesHelper.prefs.getString(
        'books_directory_path',
      );
      if (savedPath != null && await Directory(savedPath).exists()) {
        setState(() => _booksDirectoryPath = savedPath);
      }
      final savedSearchMode = PreferencesHelper.prefs.getString(
        'search_window_mode',
      );
      if (savedSearchMode != null) {
        setState(() => _searchWindowMode = savedSearchMode);
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBooksDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        await PreferencesHelper.prefs.setString(
          'books_directory_path',
          selectedDirectory,
        );
        setState(() => _booksDirectoryPath = selectedDirectory);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حفظ مسار المجلد: $selectedDirectory',
                style: normalStyle(color: Colors.white),
              ),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء اختيار المجلد: $e',
              style: normalStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateSearchWindowMode(String? value) async {
    if (value != null) {
      await PreferencesHelper.prefs.setString('search_window_mode', value);
      setState(() => _searchWindowMode = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF5F5F5,
        ), // Lighter than standard grey for cleaner look
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: secondaryColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('الإعدادات', style: bigStyle(color: secondaryColor)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 24.0,
                ),
                children: [
                  _buildSectionHeader('المكتبة وإدارة الملفات'),
                  const SizedBox(height: 12),
                  _buildBookDirectoryCard(),
                  const SizedBox(height: 32),

                  _buildSectionHeader('تفضيلات العرض والبحث'),
                  const SizedBox(height: 12),
                  _buildSearchWindowCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: mediumStyle(color: primaryColor.withOpacity(0.8), fontSize: 18),
      ),
    );
  }

  Widget _buildBookDirectoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.library_books_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مجلد الكتب',
                        style: normalStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المسار الذي يحتوي على ملفات الكتب (.docx)',
                        style: smallStyle(
                          color: Colors.grey[600]!,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _booksDirectoryPath ?? 'لم يتم اختيار مجلد',
                      style: normalStyle(
                        fontSize: 13,
                        color: _booksDirectoryPath != null
                            ? Colors.black87
                            : Colors.grey[500]!,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectBooksDirectory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shadowColor: primaryColor.withOpacity(0.3),
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      color: secondaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تغيير المجلد',
                      style: normalStyle(color: secondaryColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchWindowCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نمط نافذة البحث',
                        style: normalStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اختر كيف تريد عرض نتائج البحث',
                        style: smallStyle(
                          color: Colors.grey[600]!,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSelectionTile(
              title: 'نافذة مستقلة',
              subtitle: 'فتح البحث في نافذة منفصلة لسهولة التنقل',
              value: 'separate',
              icon: Icons.open_in_new_rounded,
            ),
            const SizedBox(height: 12),
            _buildSelectionTile(
              title: 'داخل التطبيق',
              subtitle: 'فتح البحث كنافذة منبثقة داخل النافذة الحالية',
              value: 'in_app',
              icon: Icons.web_asset_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _searchWindowMode == value;
    return InkWell(
      onTap: () => _updateSearchWindowMode(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: normalStyle(
                      fontSize: 15,
                      color: isSelected ? primaryColor : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: smallStyle(
                      fontSize: 11,
                      color: isSelected
                          ? primaryColor.withOpacity(0.7)
                          : Colors.grey[500]!,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
