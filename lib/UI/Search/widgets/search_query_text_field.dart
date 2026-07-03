import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Search/helpers/search_history_store.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';

class SearchQueryTextField extends StatefulWidget {
  final int index;
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  const SearchQueryTextField({
    super.key,
    required this.index,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  State<SearchQueryTextField> createState() => _SearchQueryTextFieldState();
}

class _SearchQueryTextFieldState extends State<SearchQueryTextField> {
  late final FocusNode _focusNode;
  late final List<String> _terms;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _terms = _historyTerms();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppOtherSettings.instance.draft();
    return Row(
      children: [
        if (settings.showSearchFieldNumbers) ...[
          SizedBox(
            width: 20,
            child: Text('${widget.index + 1}', style: normalStyle(fontSize: 10)),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: settings.showSearchAutocomplete
              ? _autocompleteField()
              : _plainField(widget.controller, _focusNode),
        ),
      ],
    );
  }

  Widget _autocompleteField() {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim();
        if (query.isEmpty) return const Iterable<String>.empty();
        return _terms
            .where((term) => term.startsWith(query))
            .take(12);
      },
      onSelected: (value) {
        widget.controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return _plainField(controller, focusNode);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(option, style: normalStyle(fontSize: 12)),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _plainField(TextEditingController controller, FocusNode focusNode) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        isDense: true,
      ),
      style: normalStyle(fontSize: 11),
      onSubmitted: (_) => widget.onSubmitted(),
    );
  }

  List<String> _historyTerms() {
    final seen = <String>{};
    final terms = <String>[];
    for (final record in SearchHistoryStore().loadRecords()) {
      for (final query in record.queries) {
        final value = query.trim();
        if (value.isNotEmpty && seen.add(value)) terms.add(value);
      }
    }
    return terms;
  }
}
