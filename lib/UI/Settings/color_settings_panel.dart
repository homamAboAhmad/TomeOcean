import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'app_color_settings.dart';

class ColorSettingsPanel extends StatefulWidget {
  final AppColorDraft draft;
  final ValueChanged<AppColorDraft> onChanged;

  const ColorSettingsPanel({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  State<ColorSettingsPanel> createState() => _ColorSettingsPanelState();
}

class _ColorSettingsPanelState extends State<ColorSettingsPanel> {
  static const _famousColors = [
    primaryColor, secondaryColor, actionColor, accentColor,
    bgColor, mutedColor, borderColor, organicHighlightColor,
    Color(0xFF0E7490), Color(0xFF155E75), Color(0xFF0F766E), Color(0xFF047857),
    Color(0xFF065F46), Color(0xFF134E4A), Color(0xFF0F172A), Color(0xFF334155),
    Color(0xFF475569), Color(0xFF64748B), Color(0xFF94A3B8), Color(0xFFCBD5E1),
    Color(0xFFE0F2FE), Color(0xFFCCFBF1), Color(0xFFDCFCE7), Color(0xFFF0FDFA),
    Color(0xFFFEF3C7), Color(0xFFFDE68A), destructiveColor, Color(0xFF991B1B),
  ];

  final _hexController = TextEditingController();
  AppColorRole _selectedRole = AppColorRole.titles;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _syncHex();
  }

  @override
  void didUpdateWidget(ColorSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.colors[_selectedRole] != widget.draft.colors[_selectedRole]) {
      _syncHex();
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _restoreAllButton(),
        const SizedBox(height: 8),
        _roleList(),
        const Divider(height: 22),
        Expanded(child: _controls()),
      ],
    );
  }

  Widget _restoreAllButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => _replaceDraft(
          AppColorDraft.defaults(customColors: widget.draft.customColors),
        ),
        child: Text('استعادة جميع الألوان الافتراضية', style: smallStyle()),
      ),
    );
  }

  Widget _roleList() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: borderColor),
      ),
      child: ListView(
        children: [
          for (final role in AppColorRole.values) _roleRow(role),
        ],
      ),
    );
  }

  Widget _roleRow(AppColorRole role) {
    final selected = role == _selectedRole;
    final color = widget.draft.colors[role] ?? role.defaultColor;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _hexError = null;
          _syncHex();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? organicHoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            _swatch(color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                role.label,
                textAlign: TextAlign.right,
                style: normalStyle(fontSize: 13, color: accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final selectedColor =
        widget.draft.colors[_selectedRole] ?? _selectedRole.defaultColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _colorGrid('الألوان الأساسية', _famousColors, selectedColor),
              const SizedBox(height: 20),
              _customColorGrid(selectedColor),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(width: 210, child: _customColorEditor(selectedColor)),
      ],
    );
  }

  Widget _colorGrid(String label, List<Color> colors, Color selectedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.center, style: smallStyle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in colors) _colorButton(color, selectedColor),
          ],
        ),
      ],
    );
  }

  Widget _customColorGrid(Color selectedColor) {
    final colors = widget.draft.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('الألوان المخصصة', textAlign: TextAlign.center, style: smallStyle()),
        const SizedBox(height: 8),
        if (colors.isEmpty)
          Text(
            'لا توجد ألوان مخصصة بعد',
            textAlign: TextAlign.center,
            style: smallStyle(color: accentColor.withOpacity(0.68)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in colors) _colorButton(color, selectedColor),
            ],
          ),
      ],
    );
  }

  Widget _customColorEditor(Color selectedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('اللون الحالي', textAlign: TextAlign.center, style: smallStyle()),
        const SizedBox(height: 8),
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: selectedColor,
            borderRadius: BorderRadius.circular(AppChrome.radius),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hexController,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'Hex',
            errorText: _hexError,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _applyHex(addToCustom: false),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _applyHex(addToCustom: false),
          child: Text('تطبيق اللون', style: smallStyle()),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => _applyHex(addToCustom: true),
          child: Text('إضافة للألوان المخصصة', style: smallStyle()),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _resetSelected,
          child: Text('استعادة الافتراضي', style: smallStyle()),
        ),
      ],
    );
  }

  Widget _colorButton(Color color, Color selectedColor) {
    final selected = color.value == selectedColor.value;
    return InkWell(
      onTap: () => _updateSelectedColor(color),
      child: Container(
        width: 30,
        height: 24,
        padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: _swatch(color, size: 24),
      ),
    );
  }

  Widget _swatch(Color color, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor.withOpacity(0.85)),
      ),
    );
  }

  void _resetSelected() {
    _updateSelectedColor(_selectedRole.defaultColor);
  }

  void _applyHex({required bool addToCustom}) {
    final color = _parseHex(_hexController.text);
    if (color == null) {
      setState(() => _hexError = 'قيمة غير صحيحة');
      return;
    }

    final customColors = List<Color>.of(widget.draft.customColors);
    if (addToCustom && !customColors.any((item) => item.value == color.value)) {
      customColors.add(color);
    }
    _replaceDraft(_draftWithColor(color).copyWith(customColors: customColors));
    setState(() {
      _hexError = null;
      _hexController.text = _hexFromColor(color);
    });
  }

  void _updateSelectedColor(Color color) {
    _replaceDraft(_draftWithColor(color));
    setState(() {
      _hexError = null;
      _hexController.text = _hexFromColor(color);
    });
  }

  AppColorDraft _draftWithColor(Color color) {
    final colors = Map<AppColorRole, Color>.of(widget.draft.colors);
    colors[_selectedRole] = color;
    return widget.draft.copyWith(colors: colors);
  }

  void _replaceDraft(AppColorDraft next) {
    widget.onChanged(next);
  }

  void _syncHex() {
    final color = widget.draft.colors[_selectedRole] ?? _selectedRole.defaultColor;
    _hexController.text = _hexFromColor(color);
  }

  Color? _parseHex(String raw) {
    final value = raw.trim().replaceFirst('#', '');
    final normalized = value.length == 6 ? 'FF$value' : value;
    if (normalized.length != 8) return null;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  String _hexFromColor(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
