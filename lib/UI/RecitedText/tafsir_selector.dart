import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';

class TafsirSelector extends StatelessWidget {
  final List<TafsirResource> resources;
  final TafsirResource? selected;
  final ValueChanged<TafsirResource?> onChanged;

  const TafsirSelector({
    super.key,
    required this.resources,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<TafsirResource>(
      value: selected,
      isDense: true,
      underline: const SizedBox.shrink(),
      style: normalStyle(fontSize: 13),
      items: resources.map((resource) {
        return DropdownMenuItem<TafsirResource>(
          value: resource,
          child: Text(
            _title(resource),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _title(TafsirResource resource) {
    final language = _languageLabel(resource.languageName);
    if (language == null) return resource.name;
    return '${resource.name} ($language)';
  }

  String? _languageLabel(String languageName) {
    switch (languageName.trim().toLowerCase()) {
      case '':
      case 'arabic':
        return null;
      case 'urdu':
        return 'الأردية';
      case 'bengali':
        return 'البنغالية';
      case 'english':
        return 'الإنجليزية';
      case 'russian':
        return 'الروسية';
      case 'kurdish':
        return 'الكردية';
    }
    return languageName;
  }
}
