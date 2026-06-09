import 'package:flutter/material.dart';
import 'library_book_item.dart';
import 'library_column_resize_divider.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';

class LibraryBooksTable extends StatefulWidget {
  final List<LibraryBookItem> books;
  final String? selectedPath;
  final Set<String> favoritePaths;
  final Set<String> checkedPaths;
  final Set<String> highlightedPaths;
  final bool showCheckboxes;
  final void Function(LibraryBookItem) onSelected;
  final void Function(LibraryBookItem)? onDoubleTap;
  final void Function(LibraryBookItem, bool)? onFavoriteChanged;
  final void Function(LibraryBookItem, bool)? onCheckedChanged;
  final Widget Function(LibraryBookItem)? trailingBuilder;
  final Widget Function(LibraryBookItem)? additionalActionBuilder;

  const LibraryBooksTable({
    super.key,
    required this.books,
    required this.selectedPath,
    required this.favoritePaths,
    required this.onSelected,
    this.onDoubleTap,
    this.onFavoriteChanged,
    this.onCheckedChanged,
    this.trailingBuilder,
    this.additionalActionBuilder,
    this.checkedPaths = const {},
    this.highlightedPaths = const {},
    this.showCheckboxes = false,
  });

  @override
  State<LibraryBooksTable> createState() => _LibraryBooksTableState();
}

class _LibraryBooksTableState extends State<LibraryBooksTable> {
  final ValueNotifier<double> _bookRatio = ValueNotifier(0.6);
  late final ValueNotifier<String?> _selectedPathNotifier =
      ValueNotifier(widget.selectedPath);
  double get _actionsWidth => widget.additionalActionBuilder == null ? 34 : 68;

  @override
  void didUpdateWidget(covariant LibraryBooksTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPath != oldWidget.selectedPath) {
      _selectedPathNotifier.value = widget.selectedPath;
    }
  }

  @override
  void dispose() {
    _bookRatio.dispose();
    _selectedPathNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return const Center(child: Text('لا توجد كتب مطابقة'));
    }
    return Column(
      children: [
        _header(),
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                ListView.builder(
                  itemCount: widget.books.length,
                  itemExtent: LibraryDesignTokens.rowHeight,
                  itemBuilder: (context, index) =>
                      _row(widget.books[index], index.isOdd),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _bookRatio,
                  builder: (_, ratio, __) => Positioned(
                    top: 0,
                    bottom: 0,
                    right: (constraints.maxWidth - _actionsWidth) * ratio,
                    child: _fullHeightHandle(
                      constraints.maxWidth - _actionsWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() => Container(
        height: LibraryDesignTokens.headerHeight,
        color: LibraryDesignTokens.header,
        child: LayoutBuilder(
          builder: (_, constraints) => _columns(
            constraints.maxWidth - _actionsWidth,
            const Center(child: Text('الكتاب')),
            const Center(child: Text('المؤلف')),
            resizable: true,
          ),
        ),
      );

  Widget _row(LibraryBookItem item, bool alternate) {
    final highlighted = widget.highlightedPaths.contains(item.bookPath);
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap == null
          ? null
          : () => widget.onDoubleTap!(item),
      child: InkWell(
        onTapDown: (_) {
          if (_selectedPathNotifier.value != item.bookPath) {
            _selectedPathNotifier.value = item.bookPath;
            widget.onSelected(item);
          }
        },
        onTap: widget.showCheckboxes && widget.onCheckedChanged != null
            ? () => widget.onCheckedChanged!(
                  item,
                  !widget.checkedPaths.contains(item.bookPath),
                )
            : null,
        child: ValueListenableBuilder<String?>(
          valueListenable: _selectedPathNotifier,
          builder: (_, selectedPath, __) {
            final selected = item.bookPath == selectedPath;
            return Container(
              decoration: _rowDecoration(selected, highlighted, alternate),
              child: LayoutBuilder(
                builder: (_, constraints) => _columns(
                  constraints.maxWidth - _actionsWidth,
                  _bookCell(item),
                  _authorCell(item),
                  trailing: _trailing(item),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _rowDecoration(
    bool selected,
    bool highlighted,
    bool alternate,
  ) {
    return BoxDecoration(
      color: selected
          ? LibraryDesignTokens.selected
          : highlighted
              ? Colors.green.withOpacity(0.1)
              : alternate
                  ? LibraryDesignTokens.alternateRow
                  : Colors.white,
      border: Border.all(
        color: selected
            ? LibraryDesignTokens.selectedBorder
            : LibraryDesignTokens.rowDivider,
        width: selected ? 1 : 0.5,
      ),
    );
  }

  Widget _bookCell(LibraryBookItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const LibraryIcon(
            LibraryIconType.bookRow,
            size: 18,
            color: LibraryDesignTokens.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _authorCell(LibraryBookItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        item.authorDisplay,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _columns(
    double width,
    Widget book,
    Widget author, {
    Widget? trailing,
    bool resizable = false,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _bookRatio,
      builder: (_, ratio, __) => Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(width: width * ratio, child: book),
          if (resizable)
            _handle(width)
          else
            const SizedBox(width: LibraryDesignTokens.columnDividerHitExtent),
          Expanded(child: author),
          SizedBox(width: _actionsWidth, child: trailing),
        ],
      ),
    );
  }

  Widget _handle(double width) => SizedBox(
        width: LibraryDesignTokens.columnDividerHitExtent,
        height: LibraryDesignTokens.headerHeight,
        child: LibraryColumnResizeDivider(
          onDragUpdate: (details) => _resize(details.delta.dx, width),
        ),
      );

  Widget _fullHeightHandle(double width) => SizedBox(
        width: LibraryDesignTokens.columnDividerHitExtent,
        child: LibraryColumnResizeDivider(
          onDragUpdate: (details) => _resize(details.delta.dx, width),
        ),
      );

  void _resize(double delta, double width) {
    _bookRatio.value = (_bookRatio.value - delta / width).clamp(0.25, 0.8);
  }

  Widget _trailing(LibraryBookItem item) {
    if (widget.trailingBuilder != null) {
      return widget.trailingBuilder!(item);
    }
    if (widget.showCheckboxes) {
      return Checkbox(
        value: widget.checkedPaths.contains(item.bookPath),
        onChanged: widget.onCheckedChanged == null
            ? null
            : (value) => widget.onCheckedChanged!(item, value ?? false),
      );
    }
    final favorite = widget.favoritePaths.contains(item.bookPath);
    final favoriteButton = IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
      iconSize: 18,
      tooltip: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
      icon: Icon(
        favorite ? Icons.star : Icons.star_border,
        color: favorite ? Colors.amber : Colors.grey.shade300,
      ),
      onPressed: widget.onFavoriteChanged == null
          ? null
          : () => widget.onFavoriteChanged!(item, !favorite),
    );
    final additionalAction = widget.additionalActionBuilder?.call(item);
    if (additionalAction == null) return favoriteButton;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 34, height: 32, child: additionalAction),
        favoriteButton,
      ],
    );
  }
}
