import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/RecitedText/tafsir_selector.dart';

class TafsirPane extends StatelessWidget {
  final List<TafsirResource> resources;
  final TafsirResource? selectedResource;
  final ValueChanged<TafsirResource?> onResourceChanged;
  final String? selectedPassageKey;
  final Future<Map<String, String>>? tafsirFuture;
  final VoidCallback onClose;

  const TafsirPane({
    super.key,
    required this.resources,
    required this.selectedResource,
    required this.onResourceChanged,
    required this.selectedPassageKey,
    required this.tafsirFuture,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: LibraryDesignTokens.divider)),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 34,
      color: LibraryDesignTokens.header,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Text('التفسير', style: normalStyle(fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: TafsirSelector(
              resources: resources,
              selected: selectedResource,
              onChanged: onResourceChanged,
            ),
          ),
          IconButton(
            tooltip: 'إغلاق التفسير',
            icon: const LibraryIcon(LibraryIconType.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (selectedPassageKey == null || selectedResource == null) {
      return const Center(child: Text('اختر آية لعرض تفسيرها'));
    }
    final future = tafsirFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<Map<String, String>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('تعذر تحميل التفسير المختار'));
        }
        final text = snapshot.data![selectedPassageKey] ??
            'لا يوجد تفسير لهذه الآية في المصدر المختار';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: normalStyle(fontSize: 17, height: 1.8),
          ),
        );
      },
    );
  }
}
