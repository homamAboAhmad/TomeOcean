import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/IndexItem.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';

class BookIndexUI extends StatefulWidget {
  final Function(int) goTo;
  final WordDocument wordDocument;

  const BookIndexUI(this.wordDocument, {super.key, required this.goTo});

  @override
  State<BookIndexUI> createState() => _BookIndexUIState();
}

class _BookIndexUIState extends State<BookIndexUI> {
  static final RegExp _headingLevelRegex = RegExp(r'Heading(\d)');

  Map<IndexItem, List<IndexItem>> subItems = {};
  final Set<String> _expandedIds = {};
  int _rootLevel = 1;

  int _getLevel(IndexItem item) {
    final match = _headingLevelRegex.firstMatch(item.type);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  @override
  Widget build(BuildContext context) {
    _buildIndexMap();

    if (widget.wordDocument.index.isEmpty) {
      return SizedBox(
        width: 250,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LibraryIcon.fromIcon(Icons.collections_bookmark,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('لا يوجد فهرس في هذا الكتاب',
                    style: normalStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 250,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.only(right: 8, left: 8, top: 12),
          children: subItems.keys
              .map((item) => _buildHeadingGroup(item))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildHeadingGroup(IndexItem item) {
    final children = subItems[item] ?? [];
    final isExpanded = _expandedIds.contains(item.id);
    final canExpand = children.isNotEmpty;
    final baseLevel = _rootLevel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIndexRow(
          item,
          canExpand: canExpand,
          isExpanded: isExpanded,
          baseLevel: baseLevel,
        ),
        if (isExpanded && canExpand)
          ...children.map(
            (child) => _buildIndexRow(child, baseLevel: baseLevel),
          ),
      ],
    );
  }

  Widget _buildIndexRow(
    IndexItem item, {
    bool canExpand = false,
    bool isExpanded = false,
    int? baseLevel,
  }) {
    final isSelected = widget.wordDocument.selectedIndexItem == item.id;
    final rawLevel = _getLevel(item);
    final level = (rawLevel - (baseLevel ?? 1) + 1).clamp(1, 9).toInt();
    final indent = (level - 1) * 18.0;
    final titleColor = AppUiColors.color(AppColorRole.titles);

    return InkWell(
      onTap: () {
        setState(() => widget.wordDocument.selectedIndexItem = item.id);
        widget.goTo(item.page);
      },
      child: Container(
        color: isSelected
            ? titleColor.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: EdgeInsets.only(
          right: 8.0 + indent,
          left: 4,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            if (canExpand)
              InkWell(
                onTap: () => setState(() {
                  isExpanded
                      ? _expandedIds.remove(item.id)
                      : _expandedIds.add(item.id);
                }),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: LibraryIcon.fromIcon(
                    isExpanded ? Icons.expand_more : Icons.chevron_left,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              const SizedBox(width: 22),
            LibraryIcon.fromIcon(
              canExpand ? Icons.folder_outlined : Icons.article_outlined,
              size: 16,
              color: isSelected
                  ? titleColor
                  : (level == 1
                      ? titleColor
                      : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                style: AppUiFonts.style(
                  AppFontRole.headingTree,
                  normalStyle(
                  fontSize: level == 1 ? 13 : 12,
                  fontWeight: level == 1 ? FontWeight.bold : FontWeight.normal,
                  color: isSelected || level == 1 ? titleColor : Colors.black87,
                  ),
                  sizeOffset: level == 1 ? 0 : -1,
                  fontWeight: level == 1 ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _buildIndexMap() {
    final index = widget.wordDocument.index;
    subItems.clear();
    if (index.isEmpty) {
      _rootLevel = 1;
      return;
    }

    _rootLevel = index
        .map(_getLevel)
        .reduce((left, right) => left < right ? left : right);
    IndexItem? lastRoot;

    for (final item in index) {
      final level = _getLevel(item);
      if (level <= _rootLevel || lastRoot == null) {
        lastRoot = item;
        subItems[lastRoot] = [];
      } else {
        subItems[lastRoot]!.add(item);
      }
    }
  }
}
