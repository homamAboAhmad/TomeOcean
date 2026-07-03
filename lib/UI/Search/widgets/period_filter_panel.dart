import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/helpers/search_period_range.dart';

class PeriodFilterPanel extends StatefulWidget {
  final List<SearchPeriodRange> selectedPeriods;
  final ValueChanged<List<SearchPeriodRange>> onPeriodsAdded;
  final ValueChanged<List<SearchPeriodRange>> onPeriodsRemoved;

  const PeriodFilterPanel({
    super.key,
    required this.selectedPeriods,
    required this.onPeriodsAdded,
    required this.onPeriodsRemoved,
  });

  @override
  State<PeriodFilterPanel> createState() => _PeriodFilterPanelState();
}

class _PeriodFilterPanelState extends State<PeriodFilterPanel> {
  late final int _currentHijriYear = SearchPeriodRange.currentHijriYear();
  late final int _currentCentury = SearchPeriodRange.currentHijriCentury();
  late final TextEditingController _fromYearController =
      TextEditingController(text: '1');
  late final TextEditingController _toYearController =
      TextEditingController(text: _currentHijriYear.toString());
  int _fromCentury = 1;
  late int _toCentury = _currentCentury;

  @override
  void dispose() {
    _fromYearController.dispose();
    _toYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _yearCard()),
                const SizedBox(width: 14),
                Expanded(child: _centuryCard()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _selectedPeriodsCard(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        LibraryIcon.fromIcon(Icons.calendar_month, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'تحديد الفترة حسب وفاة المؤلف',
            style: mediumStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearCard() {
    return _rangeCard(
      title: 'الفترة بالعام',
      subtitle: 'اختر سنة وفاة المؤلف من وإلى',
      icon: Icons.event,
      children: [
        _yearField(
          label: 'من',
          controller: _fromYearController,
        ),
        const SizedBox(height: 12),
        _yearField(
          label: 'إلى',
          controller: _toYearController,
        ),
        const SizedBox(height: 10),
        _yearShortcuts(),
        const Spacer(),
        _addButton(
          label: 'إضافة الفترة بالعام',
          onPressed: _addYearRange,
        ),
      ],
    );
  }

  Widget _centuryCard() {
    return _rangeCard(
      title: 'الفترة بالقرن',
      subtitle: 'يشمل خيار قبل القرن الأول الهجري',
      icon: Icons.view_timeline,
      children: [
        _centuryDropdown(
          label: 'من',
          value: _fromCentury,
          onChanged: (value) => setState(() => _fromCentury = value),
        ),
        const SizedBox(height: 12),
        _centuryDropdown(
          label: 'إلى',
          value: _toCentury,
          onChanged: (value) => setState(() => _toCentury = value),
        ),
        const Spacer(),
        _addButton(
          label: 'إضافة الفترة بالقرن',
          onPressed: () => widget.onPeriodsAdded([
            SearchPeriodRange.century(
              fromCentury: _fromCentury,
              toCentury: _toCentury,
              currentHijriYear: _currentHijriYear,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _rangeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.fromBorderSide(AppChrome.borderSide()),
        borderRadius: BorderRadius.circular(AppChrome.radius),
        boxShadow: AppChrome.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LibraryIcon.fromIcon(icon, color: actionColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: mediumStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: smallStyle(color: accentColor.withOpacity(0.68))),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _yearField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      decoration: _inputDecoration(label).copyWith(
        suffixText: 'هـ',
        helperText: '1 - $_currentHijriYear',
      ),
    );
  }

  Widget _yearShortcuts() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _shortcutChip('من البداية', () => _fromYearController.text = '1'),
        _shortcutChip(
          'إلى الحالي',
          () => _toYearController.text = _currentHijriYear.toString(),
        ),
      ],
    );
  }

  Widget _shortcutChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: smallStyle(fontSize: 11)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      backgroundColor: organicHighlightColor,
      side: BorderSide(color: borderColor.withOpacity(0.85)),
    );
  }

  void _addYearRange() {
    final from = int.tryParse(_fromYearController.text.trim());
    final to = int.tryParse(_toYearController.text.trim());
    if (from == null || to == null) return;
    final safeFrom = from.clamp(1, _currentHijriYear);
    final safeTo = to.clamp(1, _currentHijriYear);
    widget.onPeriodsAdded([
      SearchPeriodRange.year(fromYear: safeFrom, toYear: safeTo),
    ]);
  }

  Widget _centuryDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: _inputDecoration(label),
      items: List.generate(_currentCentury + 1, (index) {
        return DropdownMenuItem(
          value: index,
          child: Text(
            SearchPeriodRange.centuryLabel(index, _currentHijriYear),
          ),
        );
      }),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: bgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        borderSide: AppChrome.borderSide(),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        borderSide: const BorderSide(color: primaryColor, width: 1.4),
      ),
    );
  }

  Widget _addButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const LibraryIcon(LibraryIconType.zoomIn, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppChrome.radius),
          ),
        ),
      ),
    );
  }

  Widget _selectedPeriodsCard() {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.fromBorderSide(AppChrome.borderSide()),
        borderRadius: BorderRadius.circular(AppChrome.radius),
      ),
      child: widget.selectedPeriods.isEmpty
          ? Center(
              child: Text(
                'لم تضف أي فترة بعد',
                style: normalStyle(color: accentColor.withOpacity(0.68)),
              ),
            )
          : SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.selectedPeriods.map(_periodChip).toList(),
              ),
            ),
    );
  }

  Widget _periodChip(SearchPeriodRange period) {
    return InputChip(
      label: Text(period.label, style: smallStyle(fontSize: 11)),
      avatar: const LibraryIcon(LibraryIconType.calendar, size: 16),
      deleteIcon: const LibraryIcon(LibraryIconType.close, size: 16),
      onDeleted: () => widget.onPeriodsRemoved([period]),
      backgroundColor: organicHighlightColor,
      side: BorderSide(color: borderColor.withOpacity(0.9)),
    );
  }
}
