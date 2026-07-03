import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'app_citation_settings.dart';

class CitationSettingsPanel extends StatelessWidget {
  final AppCitationDraft draft;
  final ValueChanged<AppCitationDraft> onChanged;

  const CitationSettingsPanel({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => onChanged(const AppCitationDraft()),
            child: Text('استعادة الافتراضي', style: smallStyle()),
          ),
        ),
        const SizedBox(height: 8),
        _group('العزو', [
          _check(
            'إحاطة مصدر العزو بعلامتي تنصيص «»',
            draft.quoteSource,
            (value) => draft.copyWith(quoteSource: value),
          ),
          _check(
            'إحاطة رقم العزو بهلالين',
            draft.wrapPageRef,
            (value) => draft.copyWith(wrapPageRef: value),
          ),
          _check(
            'إحاطة العزو كاملًا بمعكوفين',
            draft.wrapFullCitation,
            (value) => draft.copyWith(wrapFullCitation: value),
          ),
        ]),
        const SizedBox(height: 8),
        _group('مكان وضع العزو', [
          _check(
            'وضع العزو قبل النص',
            draft.placeBeforeText,
            (value) => draft.copyWith(placeBeforeText: value),
          ),
          _check(
            'وضع العزو في سطر مستقل',
            draft.citationOnSeparateLine,
            (value) => draft.copyWith(citationOnSeparateLine: value),
          ),
        ]),
        const SizedBox(height: 8),
        _group('النص المنسوخ', [
          _check(
            'إحاطة النص المنسوخ بعلامتي تنصيص «»',
            draft.quoteCopiedText,
            (value) => draft.copyWith(quoteCopiedText: value),
          ),
          _check(
            'حذف التشكيل من النص المنسوخ',
            draft.removeDiacritics,
            (value) => draft.copyWith(removeDiacritics: value),
          ),
          _check(
            'حذف أرقام الحواشي من النص المنسوخ',
            draft.removeFootnoteNumbers,
            (value) => draft.copyWith(removeFootnoteNumbers: value),
          ),
        ]),
        const SizedBox(height: 10),
        Expanded(child: _example()),
      ],
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: const Color(0xFFFAFAFA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.right, style: smallStyle()),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _check(
    String label,
    bool value,
    AppCitationDraft Function(bool) change,
  ) {
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, textAlign: TextAlign.right, style: normalStyle(fontSize: 13)),
      value: value,
      onChanged: (next) => onChanged(change(next ?? false)),
    );
  }

  Widget _example() {
    final text =
        'قَالَ سَالِمُ بْنُ شُرَحْبِيلَ: هَذَا مِثَالٌ لِلنَّصِّ المَنْسُوخِ، وَفِيهِ رَقْمُ حَاشِيَةٍ(1).';
    final formatted = CitationFormatter.format(
      text: text,
      bookTitle: 'الكمال في أسماء الرجال',
      pageNumber: 93,
      settings: draft,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مثال', textAlign: TextAlign.right, style: smallStyle()),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                formatted,
                textAlign: TextAlign.right,
                style: normalStyle(fontSize: 20, height: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
