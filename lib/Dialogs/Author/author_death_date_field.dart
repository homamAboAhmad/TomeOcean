import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';

enum _DeathInputMode {
  exact,
  approximate,
  before,
  after,
  century,
  beforeHijri,
  contemporary,
  unknown,
}

class AuthorDeathDateField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;

  const AuthorDeathDateField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  State<AuthorDeathDateField> createState() => _AuthorDeathDateFieldState();
}

class _AuthorDeathDateFieldState extends State<AuthorDeathDateField> {
  late _DeathInputMode _mode;
  late final TextEditingController _yearController;
  int _century = 1;

  @override
  void initState() {
    super.initState();
    final parsed = AuthorDeathDateParser.parse(widget.controller.text);
    _mode = _modeFromParsed(parsed);
    _yearController = TextEditingController(text: parsed.year?.toString() ?? '');
    _century = parsed.century ?? 1;
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تاريخ الوفاة (هجري)',
            style: normalStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_DeathInputMode>(
            value: _mode,
            isExpanded: true,
            decoration: _decoration('نوع التاريخ'),
            items: const [
              DropdownMenuItem(
                value: _DeathInputMode.exact,
                child: Text('سنة محددة'),
              ),
              DropdownMenuItem(
                value: _DeathInputMode.approximate,
                child: Text('نحو سنة'),
              ),
              DropdownMenuItem(value: _DeathInputMode.before, child: Text('قبل سنة')),
              DropdownMenuItem(value: _DeathInputMode.after, child: Text('بعد سنة')),
              DropdownMenuItem(
                value: _DeathInputMode.century,
                child: Text('بالقرن'),
              ),
              DropdownMenuItem(
                value: _DeathInputMode.beforeHijri,
                child: Text('قبل القرن الأول الهجري'),
              ),
              DropdownMenuItem(
                value: _DeathInputMode.contemporary,
                child: Text('معاصر'),
              ),
              DropdownMenuItem(
                value: _DeathInputMode.unknown,
                child: Text('غير معروف'),
              ),
            ],
            onChanged: widget.enabled
                ? (mode) {
                    if (mode == null) return;
                    setState(() => _mode = mode);
                    _syncController();
                  }
                : null,
          ),
          if (_needsYear) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: _decoration('السنة').copyWith(
                suffixText: 'هـ',
                hintText: 'مثال: 250',
              ),
              onChanged: (_) => _syncController(),
              validator: _validateYear,
            ),
          ],
          if (_mode == _DeathInputMode.century) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _century,
              isExpanded: true,
              decoration: _decoration('القرن'),
              items: List.generate(15, (index) {
                final century = index + 1;
                return DropdownMenuItem(
                  value: century,
                  child: Text(_centuryLabel(century)),
                );
              }),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _century = value);
                _syncController();
              },
            ),
          ],
        ],
      ),
    );
  }

  bool get _needsYear =>
      _mode == _DeathInputMode.exact ||
      _mode == _DeathInputMode.approximate ||
      _mode == _DeathInputMode.before ||
      _mode == _DeathInputMode.after;

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  String? _validateYear(String? value) {
    if (!_needsYear) return null;
    final year = int.tryParse((value ?? '').trim());
    if (year == null) return 'أدخل سنة هجرية صحيحة';
    if (year < 1 || year > 2000) return 'السنة يجب أن تكون بين 1 و 2000';
    return null;
  }

  void _syncController() {
    final year = _yearController.text.trim();
    final value = switch (_mode) {
      _DeathInputMode.exact => year.isEmpty ? '' : '$year هـ',
      _DeathInputMode.approximate => year.isEmpty ? '' : 'نحو $year هـ',
      _DeathInputMode.before => year.isEmpty ? '' : 'قبل $year هـ',
      _DeathInputMode.after => year.isEmpty ? '' : 'بعد $year هـ',
      _DeathInputMode.century => 'ق $_century هـ',
      _DeathInputMode.beforeHijri => 'قبل القرن الأول الهجري',
      _DeathInputMode.contemporary => AuthorDeathDateParser.contemporaryValue,
      _DeathInputMode.unknown => 'غير معروف',
    };
    if (widget.controller.text != value) {
      widget.controller.text = value;
    }
  }

  _DeathInputMode _modeFromParsed(AuthorDeathDate parsed) {
    switch (parsed.kind) {
      case AuthorDeathDateKind.exact:
        return _DeathInputMode.exact;
      case AuthorDeathDateKind.approximate:
        return _DeathInputMode.approximate;
      case AuthorDeathDateKind.before:
        return _DeathInputMode.before;
      case AuthorDeathDateKind.after:
        return _DeathInputMode.after;
      case AuthorDeathDateKind.century:
        return _DeathInputMode.century;
      case AuthorDeathDateKind.beforeHijri:
        return _DeathInputMode.beforeHijri;
      case AuthorDeathDateKind.contemporary:
        return _DeathInputMode.contemporary;
      case AuthorDeathDateKind.unknown:
        return parsed.rawValue.isEmpty
            ? _DeathInputMode.exact
            : _DeathInputMode.unknown;
    }
  }

  String _centuryLabel(int century) {
    const names = [
      '',
      'الأول',
      'الثاني',
      'الثالث',
      'الرابع',
      'الخامس',
      'السادس',
      'السابع',
      'الثامن',
      'التاسع',
      'العاشر',
      'الحادي عشر',
      'الثاني عشر',
      'الثالث عشر',
      'الرابع عشر',
      'الخامس عشر',
    ];
    return 'القرن ${names[century]} الهجري';
  }
}
