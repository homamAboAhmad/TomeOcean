import 'dart:async';

import 'package:flutter/material.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/Services/WindowsFontCatalog.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'app_font_settings.dart';

class FontChoiceEditor extends StatelessWidget {
  final AppFontChoice choice;
  final List<WindowsFontFamily> allFamilies;
  final ValueChanged<AppFontChoice> onChanged;
  final String sample;
  final bool showScriptPicker;
  final bool showLineSpacingPicker;
  final bool showResetButton;
  final bool filterByScript;
  final double previewHeight;
  final AppFontChoice? defaultChoice;

  static const sizes = [6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 48];
  static const lineSpacings = [1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 2.0];

  const FontChoiceEditor({
    super.key,
    required this.choice,
    required this.allFamilies,
    required this.onChanged,
    required this.sample,
    this.showScriptPicker = true,
    this.showLineSpacingPicker = true,
    this.showResetButton = true,
    this.filterByScript = true,
    this.previewHeight = 82,
    this.defaultChoice,
  });

  @override
  Widget build(BuildContext context) {
    final script = _script(choice.script);
    final filteredFamilies = filterByScript ? allFamilies.where((family) => family.supportsCodePoint(script.codePoint)).toList() : allFamilies;
    final families = filteredFamilies.isEmpty ? allFamilies : filteredFamilies;
    final familyNames = ['', ...families.map((family) => family.name)];
    final selectedFamily = familyNames.contains(choice.fontFamily) ? choice.fontFamily : '';
    final styles = selectedFamily.isEmpty ? const ['Regular'] : _stylesForFamily(selectedFamily, families);
    final selectedStyle = styles.contains(choice.styleName) ? choice.styleName : styles.first;

    return Column(
      children: [
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 92, child: _sizeList(choice.fontSize)),
            const SizedBox(width: 8),
            SizedBox(width: 205, child: _styleList(styles, selectedStyle)),
            const SizedBox(width: 8),
            Expanded(child: _familyList(familyNames, selectedFamily)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showResetButton)
              OutlinedButton(onPressed: _reset, child: Text('استعادة الافتراضي', style: smallStyle())),
            if (showResetButton) const SizedBox(width: 12),
            Expanded(child: _preview(choice.copyWith(fontFamily: selectedFamily, styleName: selectedStyle))),
            if (showLineSpacingPicker) const SizedBox(width: 12),
            if (showLineSpacingPicker) SizedBox(width: 105, child: _lineSpacingPicker(choice.lineSpacing)),
            if (showScriptPicker) const SizedBox(width: 12),
            if (showScriptPicker) SizedBox(width: 200, child: _scriptPicker(choice.script)),
          ],
        ),
      ],
    );
  }

  Widget _familyList(List<String> families, String selected) {
    return _boxedList(
      label: 'الخط',
      child: ListView.builder(
        itemCount: families.length,
        itemBuilder: (_, index) {
          final family = families[index];
          final label = family.isEmpty ? 'خط التطبيق الافتراضي' : family;
          return _listItem(label, family == selected, () {
            final style = family.isEmpty ? 'Regular' : _stylesForFamily(family, allFamilies).first;
            _update(fontFamily: family, styleName: style);
            if (family.isNotEmpty) unawaited(loadKnownSystemFontsForDocument([family]));
          });
        },
      ),
    );
  }

  Widget _styleList(List<String> styles, String selected) {
    return _boxedList(
      label: 'نمط الخط',
      child: ListView(children: [
        for (final style in styles) _listItem(style, style == selected, () => _update(styleName: style)),
      ]),
    );
  }

  List<String> _stylesForFamily(String familyName, List<WindowsFontFamily> families) {
    final family = families.where((family) => family.name == familyName);
    final styles = family.isEmpty ? <String>['Regular'] : family.first.styles.toList();
    for (final fallback in const ['Regular', 'Bold', 'Italic', 'Bold Italic']) {
      if (!styles.any((style) => style.toLowerCase() == fallback.toLowerCase())) styles.add(fallback);
    }
    return styles..sort((a, b) => _styleRank(a).compareTo(_styleRank(b)));
  }

  int _styleRank(String style) {
    final lower = style.toLowerCase();
    if (lower == 'regular') return 0;
    if (lower == 'bold') return 1;
    if (lower == 'italic') return 2;
    if (lower == 'bold italic') return 3;
    if (lower.contains('semi')) return 4;
    if (lower.contains('bold')) return 5;
    return 10;
  }

  Widget _sizeList(double selected) {
    return _boxedList(
      label: 'الحجم',
      child: ListView(children: [
        for (final size in sizes)
          _listItem('$size', selected.round() == size, () => _update(fontSize: size.toDouble())),
      ]),
    );
  }

  Widget _boxedList({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.center, style: smallStyle()),
        const SizedBox(height: 3),
        Container(
          height: 240,
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400)),
          child: child,
        ),
      ],
    );
  }

  Widget _listItem(String text, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? organicHoverColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _scriptPicker(String value) {
    final selected = _script(value).id;
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'شكل الخط'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          items: [for (final script in appFontScripts) DropdownMenuItem(value: script.id, child: Text(script.label))],
          onChanged: (next) {
            if (next != null) _update(script: next, fontFamily: '', styleName: 'Regular');
          },
        ),
      ),
    );
  }

  Widget _lineSpacingPicker(double value) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'تباعد الأسطر'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: lineSpacings.contains(value) ? value : 1.0,
          isExpanded: true,
          items: [for (final spacing in lineSpacings) DropdownMenuItem(value: spacing, child: Text(spacing.toString()))],
          onChanged: (next) {
            if (next != null) _update(lineSpacing: next);
          },
        ),
      ),
    );
  }

  Widget _preview(AppFontChoice choice) {
    final style = normalStyle(fontSize: choice.fontSize, height: choice.lineSpacing).copyWith(
      fontFamily: choice.fontFamily.isEmpty ? null : choice.fontFamily,
      fontWeight: AppUiFonts.weightFor(choice.styleName),
      fontStyle: AppUiFonts.fontStyleFor(choice.styleName),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('نموذج:', style: smallStyle()),
        const SizedBox(height: 4),
        Container(
          height: previewHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
          child: Text(sample, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }

  AppFontScript _script(String id) {
    return appFontScripts.firstWhere((script) => script.id == id, orElse: () => appFontScripts.first);
  }

  void _reset() {
    onChanged(defaultChoice ?? const AppFontChoice(fontSize: 14));
  }

  void _update({String? fontFamily, String? styleName, double? fontSize, double? lineSpacing, String? script}) {
    onChanged(choice.copyWith(
      fontFamily: fontFamily,
      styleName: styleName,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      script: script,
    ));
  }
}
