import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/WindowsFontCatalog.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'app_font_settings.dart';
import 'font_choice_editor.dart';

class FontSettingsPanel extends StatefulWidget {
  final Map<AppFontRole, AppFontChoice> draft;
  final ValueChanged<Map<AppFontRole, AppFontChoice>> onChanged;

  const FontSettingsPanel({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  State<FontSettingsPanel> createState() => _FontSettingsPanelState();
}

class _FontSettingsPanelState extends State<FontSettingsPanel> {
  late AppFontRole _selectedRole = AppFontRole.bookLists;
  late Future<List<WindowsFontFamily>> _familiesFuture;

  @override
  void initState() {
    super.initState();
    _familiesFuture = WindowsFontCatalog.familiesAsync();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WindowsFontFamily>>(
      future: _familiesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _restoreAllButton(),
            const SizedBox(height: 8),
            _roleList(),
            const Divider(height: 22),
            Expanded(child: _controls(snapshot.data!)),
          ],
        );
      },
    );
  }

  Widget _restoreAllButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => _replaceDraft({
          for (final role in AppFontRole.values)
            role: AppFontChoice(fontSize: role.defaultSize),
        }),
        child: Text('استعادة جميع الخطوط الافتراضية', style: smallStyle()),
      ),
    );
  }

  Widget _roleList() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: borderColor),
      ),
      child: ListView(
        children: [
          for (final role in AppFontRole.values) _roleRow(role),
        ],
      ),
    );
  }

  Widget _roleRow(AppFontRole role) {
    final selected = role == _selectedRole;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? organicHoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          role.label,
          textAlign: TextAlign.right,
          style: normalStyle(
            fontSize: 13,
            color: selected ? accentColor : accentColor.withOpacity(0.86),
          ),
        ),
      ),
    );
  }

  Widget _controls(List<WindowsFontFamily> allFamilies) {
    final choice = widget.draft[_selectedRole]!;
    final sample = appFontScripts
        .firstWhere(
          (script) => script.id == choice.script,
          orElse: () => appFontScripts.first,
        )
        .sample;
    return FontChoiceEditor(
      choice: choice,
      allFamilies: allFamilies,
      sample: sample,
      defaultChoice: AppFontChoice(fontSize: _selectedRole.defaultSize),
      onChanged: (nextChoice) {
        final next = Map<AppFontRole, AppFontChoice>.of(widget.draft);
        next[_selectedRole] = nextChoice;
        _replaceDraft(next);
      },
    );
  }

  void _replaceDraft(Map<AppFontRole, AppFontChoice> next) {
    widget.onChanged(next);
  }
}
