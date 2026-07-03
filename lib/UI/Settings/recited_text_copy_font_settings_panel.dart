import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/WindowsFontCatalog.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'app_font_settings.dart';
import 'app_recited_text_copy_settings.dart';
import 'font_choice_editor.dart';

class RecitedTextCopyFontSettingsPanel extends StatefulWidget {
  final RecitedTextCopyDraft draft;
  final ValueChanged<RecitedTextCopyDraft> onChanged;

  const RecitedTextCopyFontSettingsPanel({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  State<RecitedTextCopyFontSettingsPanel> createState() =>
      _RecitedTextCopyFontSettingsPanelState();
}

class _RecitedTextCopyFontSettingsPanelState
    extends State<RecitedTextCopyFontSettingsPanel> {
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _restoreButton(),
            const SizedBox(height: 12),
            _sizeRow(
              title: 'خط المجمع',
              subtitle: 'ينسخ خط المجمع بهذا الحجم',
              value: widget.draft.complexFontSize,
              onChanged: (size) => _replace(widget.draft.copyWith(complexFontSize: size)),
            ),
            const Divider(height: 28),
            _sizeRow(
              title: 'الخط الأميري',
              subtitle: 'ينسخ الخط الأميري بهذا الحجم',
              value: widget.draft.amiriFontSize,
              onChanged: (size) => _replace(widget.draft.copyWith(amiriFontSize: size)),
            ),
            const Divider(height: 28),
            Text('خط العزو', textAlign: TextAlign.right, style: normalStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Expanded(
              child: FontChoiceEditor(
                choice: widget.draft.referenceFont,
                allFamilies: snapshot.data!,
                sample: 'قل هو الله أحد',
                showLineSpacingPicker: false,
                showResetButton: false,
                previewHeight: 96,
                onChanged: (font) => _replace(widget.draft.copyWith(referenceFont: font)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _restoreButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => _replace(const RecitedTextCopyDraft()),
        child: Text('استعادة الافتراضي', style: smallStyle()),
      ),
    );
  }

  Widget _sizeRow({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(title, textAlign: TextAlign.right, style: normalStyle(fontSize: 13)),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(subtitle, textAlign: TextAlign.right, style: smallStyle()),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 86,
          child: DropdownButtonFormField<double>(
            value: _sizes.contains(value.round()) ? value.roundToDouble() : 14.0,
            isDense: true,
            items: [
              for (final size in _sizes)
                DropdownMenuItem(value: size.toDouble(), child: Text('$size')),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    );
  }

  static const _sizes = [6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48];

  void _replace(RecitedTextCopyDraft next) => widget.onChanged(next);
}
