import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/WindowsStartupActions.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'Settings/app_color_settings.dart';
import 'Settings/app_citation_settings.dart';
import 'Settings/app_font_settings.dart';
import 'Settings/app_other_settings.dart';
import 'Settings/app_recited_text_copy_settings.dart';
import 'Settings/citation_settings_panel.dart';
import 'Settings/color_settings_panel.dart';
import 'Settings/comments_exchange_panel.dart';
import 'Settings/font_settings_panel.dart';
import 'Settings/other_settings_panel.dart';
import 'Settings/recited_text_copy_font_settings_panel.dart';

class SettingsScreen extends StatefulWidget {
  final String initialSection;

  const SettingsScreen({
    super.key,
    this.initialSection = 'fonts',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<AppFontRole, AppFontChoice> _fontDraft;
  late AppColorDraft _colorDraft;
  late AppCitationDraft _citationDraft;
  late RecitedTextCopyDraft _recitedTextCopyDraft;
  late AppOtherDraft _otherDraft;
  late String _selectedSection;
  bool _saving = false;

  static const _sections = [
    _SettingsSection('fonts', 'خطوط', Icons.font_download),
    _SettingsSection('colors', 'ألوان', Icons.palette),
    _SettingsSection('copyFont', 'خط نسخ الآية', Icons.menu_book),
    _SettingsSection('copyExport', 'النسخ والعزو', Icons.copy),
    _SettingsSection('bookView', 'عرض الكتاب', Icons.chrome_reader_mode),
    _SettingsSection('other', 'إعدادات أخرى', Icons.build),
    _SettingsSection('images', 'مجلد المصورات', Icons.picture_as_pdf),
    _SettingsSection('comments', 'التعليقات', Icons.comment),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _fontDraft = AppFontSettings.instance.draft();
    _colorDraft = AppColorSettings.instance.draft();
    _citationDraft = AppCitationSettings.instance.draft();
    _recitedTextCopyDraft = RecitedTextCopySettings.instance.draft();
    _otherDraft = AppOtherSettings.instance.draft();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 850,
          height: 820,
          child: Column(
            children: [
              _titleBar(context),
              Expanded(
                child: Row(
                  children: [
                    _sideMenu(),
                    const VerticalDivider(width: 1),
                    Expanded(child: _content()),
                  ],
                ),
              ),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(bottom: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          const LibraryIcon(LibraryIconType.settings, size: 20, color: primaryColor),
          const SizedBox(width: 8),
          Text('الإعدادات', style: mediumStyle(fontSize: 17)),
          const Spacer(),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () => Navigator.pop(context),
            icon: const LibraryIcon(LibraryIconType.close),
          ),
        ],
      ),
    );
  }

  Widget _sideMenu() {
    return SizedBox(
      width: 172,
      child: ListView(
        padding: const EdgeInsets.all(4),
        children: [
          for (final section in _sections)
            _sectionButton(section, section.id == _selectedSection),
        ],
      ),
    );
  }

  Widget _sectionButton(_SettingsSection section, bool selected) {
    return InkWell(
      onTap: () => setState(() => _selectedSection = section.id),
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? organicHoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppChrome.radius),
          border: selected ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          children: [
            LibraryIcon.fromIcon(section.icon, color: primaryColor, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.label,
                style: normalStyle(
                  fontSize: 16,
                  color: selected ? accentColor : accentColor.withOpacity(0.86),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_selectedSection == 'fonts') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: FontSettingsPanel(
          draft: _fontDraft,
          onChanged: (next) => setState(() => _fontDraft = next),
        ),
      );
    }

    if (_selectedSection == 'copyFont') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: RecitedTextCopyFontSettingsPanel(
          draft: _recitedTextCopyDraft,
          onChanged: (next) => setState(() => _recitedTextCopyDraft = next),
        ),
      );
    }

    if (_selectedSection == 'colors') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: ColorSettingsPanel(
          draft: _colorDraft,
          onChanged: (next) => setState(() => _colorDraft = next),
        ),
      );
    }

    if (_selectedSection == 'copyExport') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: CitationSettingsPanel(
          draft: _citationDraft,
          onChanged: (next) => setState(() => _citationDraft = next),
        ),
      );
    }

    if (_selectedSection == 'other') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: OtherSettingsPanel(
          draft: _otherDraft,
          onChanged: (next) => setState(() => _otherDraft = next),
        ),
      );
    }

    if (_selectedSection == 'comments') {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: CommentsExchangePanel(),
      );
    }

    return Center(
      child: Text(
        'سيضاف هذا القسم لاحقًا',
        style: normalStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(top: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 92,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? '...' : 'موافق'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _saving = true);
    await AppFontSettings.instance.save(_fontDraft);
    await AppColorSettings.instance.save(_colorDraft);
    await AppCitationSettings.instance.save(_citationDraft);
    await RecitedTextCopySettings.instance.save(_recitedTextCopyDraft);
    await AppOtherSettings.instance.save(_otherDraft);
    await WindowsStartupActions.applyAfterSettingsSave();
    if (context.mounted) Navigator.pop(context);
  }
}

class _SettingsSection {
  final String id;
  final String label;
  final IconData icon;

  const _SettingsSection(this.id, this.label, this.icon);
}
