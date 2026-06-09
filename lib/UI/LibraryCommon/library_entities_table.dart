import 'package:flutter/material.dart';
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
  final VoidCallback? onTitleHeaderTap;
  final VoidCallback? onSecondaryHeaderTap;

  const LibraryEntitiesTable({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.titleHeader,
    required this.secondaryHeader,
    required this.onSelected,
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
                    itemBuilder: (context, index) =>
                        _row(widget.rows[index]),
                  ),
                ),
              ],
            ),
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
    final columnsWidth =
        _availableWidth - _countWidth - (LibraryDesignTokens.dividerExtent * 2);
    return columnsWidth * _titleRatio;
  }

  double get _countDividerOffset =>
      _availableWidth - _countWidth - LibraryDesignTokens.dividerExtent;

  Widget _header() {
    final showSecondary = widget.secondaryHeader.isNotEmpty;
    return Container(
      height: LibraryDesignTokens.headerHeight,
      decoration: BoxDecoration(
        color: LibraryDesignTokens.header,
        border: const Border(
          bottom: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
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
          const SizedBox(width: LibraryDesignTokens.dividerExtent),
          SizedBox(width: _countWidth, child: const Center(child: Text('الكتب'))),
        ],
      ),
    );
  }

  Widget _row(LibraryEntityRow row) {
    final selected = row.id == widget.selectedId;
    final showSecondary = widget.secondaryHeader.isNotEmpty;
    return InkWell(
      onTap: () => widget.onSelected(row.id),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? LibraryDesignTokens.selected : Colors.transparent,
          border: Border.all(
            color: selected
                ? LibraryDesignTokens.selectedBorder
                : LibraryDesignTokens.rowDivider,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              flex: (_titleRatio * 100).round(),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
                child: Text(
                  row.title,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            if (showSecondary) ...[
              const SizedBox(width: LibraryDesignTokens.dividerExtent),
              Expanded(
                flex: ((1 - _titleRatio) * 100).round(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    row.secondary ?? '',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
            const SizedBox(width: LibraryDesignTokens.dividerExtent),
            SizedBox(
              width: _countWidth,
              child: Text(
                '${row.count}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
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
