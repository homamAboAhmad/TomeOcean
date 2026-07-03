import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'library_column_resize_divider.dart';
import 'library_design_tokens.dart';

class LibraryEntityRow {
  final String id;
  final String title;
  final String? secondary;
  final int count;

  const LibraryEntityRow({
    required this.id,
    required this.title,
    required this.count,
    this.secondary,
  });
}

class LibraryEntitiesTable extends StatefulWidget {
  final List<LibraryEntityRow> rows;
  final String? selectedId;
  final String titleHeader;
  final String secondaryHeader;
  final ValueChanged<String> onSelected;
  final Set<String> checkedIds;
  final Set<String> highlightedIds;
  final bool showCheckboxes;
  final bool showCountColumn;
  final void Function(String, bool)? onCheckedChanged;
  final VoidCallback? onToggleAll;
  final VoidCallback? onTitleHeaderTap;
  final VoidCallback? onSecondaryHeaderTap;

  const LibraryEntitiesTable({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.titleHeader,
    required this.secondaryHeader,
    required this.onSelected,
    this.checkedIds = const {},
    this.highlightedIds = const {},
    this.showCheckboxes = false,
    this.showCountColumn = true,
    this.onCheckedChanged,
    this.onToggleAll,
    this.onTitleHeaderTap,
    this.onSecondaryHeaderTap,
  });

  @override
  State<LibraryEntitiesTable> createState() => _LibraryEntitiesTableState();
}

class _LibraryEntitiesTableState extends State<LibraryEntitiesTable> {
  double _titleRatio = 0.66;
  double _availableWidth = 300;
  double _countWidth = 58;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة'));
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        _availableWidth = constraints.maxWidth;
        return Stack(
          children: [
            Column(
              children: [
                _header(),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.rows.length,
                    itemExtent: LibraryDesignTokens.rowHeight,
                    itemBuilder: (context, index) => _row(widget.rows[index]),
                  ),
                ),
              ],
            ),
            if (widget.showCountColumn)
              Positioned(
                top: 0,
                bottom: 0,
                right: _countDividerOffset,
                child: _countResizeDivider(),
              ),
            if (widget.secondaryHeader.isNotEmpty)
              Positioned(
                top: 0,
                bottom: 0,
                right: _secondaryDividerOffset,
                child: _resizeDivider(),
              ),
          ],
        );
      },
    );
  }

  double get _secondaryDividerOffset {
    final checkboxWidth = widget.showCheckboxes ? 40.0 : 0.0;
    final countWidth = widget.showCountColumn
        ? _countWidth + LibraryDesignTokens.dividerExtent
        : 0;
    final columnsWidth = _availableWidth -
        checkboxWidth -
        countWidth -
        LibraryDesignTokens.dividerExtent;
    return checkboxWidth + (columnsWidth * _titleRatio);
  }

  double get _countDividerOffset =>
      _availableWidth - _countWidth - LibraryDesignTokens.dividerExtent;

  Widget _header() {
    final showSecondary = widget.secondaryHeader.isNotEmpty;
    return Container(
      height: LibraryDesignTokens.headerHeight,
      decoration: const BoxDecoration(
        color: LibraryDesignTokens.header,
        border: Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          if (widget.showCheckboxes) _headerCheckbox(),
          Expanded(
            flex: (_titleRatio * 100).round(),
            child: InkWell(
              onTap: widget.onTitleHeaderTap,
              child: Center(child: Text(widget.titleHeader)),
            ),
          ),
          if (showSecondary) ...[
            const SizedBox(width: LibraryDesignTokens.dividerExtent),
            Expanded(
              flex: ((1 - _titleRatio) * 100).round(),
              child: InkWell(
                onTap: widget.onSecondaryHeaderTap,
                child: Center(child: Text(widget.secondaryHeader)),
              ),
            ),
          ],
          if (widget.showCountColumn) ...[
            const SizedBox(width: LibraryDesignTokens.dividerExtent),
            SizedBox(
              width: _countWidth,
              child: const Center(child: Text('الكتب')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCheckbox() {
    return SizedBox(
      width: 40,
      child: Checkbox(
        value: widget.rows.isNotEmpty &&
            widget.checkedIds.length == widget.rows.length,
        tristate: true,
        onChanged: (_) => widget.onToggleAll?.call(),
      ),
    );
  }

  Widget _row(LibraryEntityRow row) {
    final selected = row.id == widget.selectedId;
    final checked = widget.checkedIds.contains(row.id);
    final highlighted = widget.highlightedIds.contains(row.id);
    final showSecondary = widget.secondaryHeader.isNotEmpty;
    return InkWell(
      onTap: () => widget.onSelected(row.id),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? LibraryDesignTokens.selected
              : checked
                  ? LibraryDesignTokens.chipSelected
                  : Colors.transparent,
          border: Border.all(
            color: selected
                ? LibraryDesignTokens.selectedBorder
                : checked
                    ? LibraryDesignTokens.chipBorder
                : LibraryDesignTokens.rowDivider,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            if (widget.showCheckboxes) _rowCheckbox(row.id),
            Expanded(
              flex: (_titleRatio * 100).round(),
              child: _textCell(
                row.title,
                TextAlign.right,
                highlighted: highlighted,
              ),
            ),
            if (showSecondary) ...[
              const SizedBox(width: LibraryDesignTokens.dividerExtent),
              Expanded(
                flex: ((1 - _titleRatio) * 100).round(),
                child: _textCell(
                  row.secondary ?? '',
                  TextAlign.center,
                  highlighted: highlighted,
                ),
              ),
            ],
            if (widget.showCountColumn) ...[
              const SizedBox(width: LibraryDesignTokens.dividerExtent),
              SizedBox(
                width: _countWidth,
                child: Text('${row.count}', textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowCheckbox(String id) {
    return SizedBox(
      width: 40,
      child: Checkbox(
        value: widget.checkedIds.contains(id),
        onChanged: widget.onCheckedChanged == null
            ? null
            : (value) => widget.onCheckedChanged!(id, value ?? false),
      ),
    );
  }

  Widget _textCell(
    String text,
    TextAlign alignment, {
    required bool highlighted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        textAlign: alignment,
        overflow: TextOverflow.ellipsis,
        style: AppUiFonts.style(
          AppFontRole.bookLists,
          TextStyle(
          color: Colors.black,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
          ),
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _countResizeDivider() => LibraryColumnResizeDivider(
        extent: LibraryDesignTokens.dividerExtent,
        onDragUpdate: (details) => setState(() {
          final maxCountWidth = (_availableWidth * 0.72).clamp(150.0, 420.0);
          _countWidth =
              (_countWidth + details.delta.dx).clamp(45, maxCountWidth);
        }),
      );

  Widget _resizeDivider() => LibraryColumnResizeDivider(
        extent: LibraryDesignTokens.dividerExtent,
        onDragUpdate: (details) => setState(() {
          _titleRatio = (_titleRatio - details.delta.dx / _availableWidth)
              .clamp(0.3, 0.85);
        }),
      );
}
