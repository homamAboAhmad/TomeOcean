import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';

class LibraryResizableDialogFrame extends StatefulWidget {
  final double minWidth;
  final double minHeight;
  final Widget child;

  const LibraryResizableDialogFrame({
    super.key,
    required this.minWidth,
    required this.minHeight,
    required this.child,
  });

  @override
  State<LibraryResizableDialogFrame> createState() =>
      _LibraryResizableDialogFrameState();
}

class _LibraryResizableDialogFrameState
    extends State<LibraryResizableDialogFrame> {
  static const double _margin = 10;
  static const double _edge = 7;
  static const double _corner = 18;
  final ValueNotifier<Rect?> _rectNotifier = ValueNotifier(null);
  Rect? _pendingRect;
  bool _frameScheduled = false;

  @override
  void dispose() {
    _rectNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final bounds = Rect.fromLTWH(
      _margin,
      _margin,
      math.max(widget.minWidth, viewport.width - (_margin * 2)),
      math.max(widget.minHeight, viewport.height - (_margin * 2)),
    );
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox.expand(
        child: ValueListenableBuilder<Rect?>(
          valueListenable: _rectNotifier,
          child: RepaintBoundary(child: widget.child),
          builder: (context, value, content) {
            final rect = _normalizedRect(bounds, value);
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Material(
                    elevation: 14,
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        color: LibraryDesignTokens.divider,
                      ),
                    ),
                    child: Column(
                      children: [
                        _titleBar(rect, bounds),
                        Expanded(child: content!),
                      ],
                    ),
                  ),
                ),
                ..._resizeHandles(rect, bounds),
              ],
            );
          },
        ),
      ),
    );
  }

  Rect _normalizedRect(Rect bounds, Rect? current) {
    final initial = current ??
        Rect.fromCenter(
          center: bounds.center,
          width: math.min(LibraryDesignTokens.pickerInitialWidth, bounds.width),
          height: math.min(LibraryDesignTokens.pickerInitialHeight, bounds.height),
        );
    final width = initial.width.clamp(widget.minWidth, bounds.width).toDouble();
    final height =
        initial.height.clamp(widget.minHeight, bounds.height).toDouble();
    final left = initial.left
        .clamp(bounds.left, bounds.right - width)
        .toDouble();
    final top = initial.top
        .clamp(bounds.top, bounds.bottom - height)
        .toDouble();
    return Rect.fromLTWH(left, top, width, height);
  }

  Widget _titleBar(Rect rect, Rect bounds) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => _move(rect, bounds, details.delta),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: LibraryDesignTokens.surface,
          border: const Border(
            bottom: BorderSide(color: LibraryDesignTokens.divider),
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 18,
              color: LibraryDesignTokens.primary,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'اختيار كتاب',
                style: TextStyle(fontFamily: LibraryDesignTokens.fontFamily),
              ),
            ),
            IconButton(
              tooltip: 'إغلاق',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resizeHandles(Rect rect, Rect bounds) {
    return [
      _edgeHandle(
        rect: Rect.fromLTWH(rect.left + _corner, rect.top, rect.width - 36, _edge),
        cursor: SystemMouseCursors.resizeUpDown,
        onDrag: (delta) => _resize(rect, bounds, top: delta.dy),
      ),
      _edgeHandle(
        rect: Rect.fromLTWH(
          rect.left + _corner,
          rect.bottom - _edge,
          rect.width - 36,
          _edge,
        ),
        cursor: SystemMouseCursors.resizeUpDown,
        onDrag: (delta) => _resize(rect, bounds, bottom: delta.dy),
      ),
      _edgeHandle(
        rect: Rect.fromLTWH(rect.left, rect.top + _corner, _edge, rect.height - 36),
        cursor: SystemMouseCursors.resizeLeftRight,
        onDrag: (delta) => _resize(rect, bounds, left: delta.dx),
      ),
      _edgeHandle(
        rect: Rect.fromLTWH(
          rect.right - _edge,
          rect.top + _corner,
          _edge,
          rect.height - 36,
        ),
        cursor: SystemMouseCursors.resizeLeftRight,
        onDrag: (delta) => _resize(rect, bounds, right: delta.dx),
      ),
      _cornerHandle(rect.topLeft, SystemMouseCursors.resizeUpLeftDownRight,
          (delta) => _resize(rect, bounds, left: delta.dx, top: delta.dy)),
      _cornerHandle(
        Offset(rect.right - _corner, rect.top),
        SystemMouseCursors.resizeUpRightDownLeft,
        (delta) => _resize(rect, bounds, right: delta.dx, top: delta.dy),
      ),
      _cornerHandle(
        Offset(rect.left, rect.bottom - _corner),
        SystemMouseCursors.resizeUpRightDownLeft,
        (delta) => _resize(rect, bounds, left: delta.dx, bottom: delta.dy),
      ),
      _cornerHandle(
        Offset(rect.right - _corner, rect.bottom - _corner),
        SystemMouseCursors.resizeUpLeftDownRight,
        (delta) => _resize(rect, bounds, right: delta.dx, bottom: delta.dy),
      ),
    ];
  }

  Widget _cornerHandle(
    Offset offset,
    MouseCursor cursor,
    ValueChanged<Offset> onDrag,
  ) {
    return _edgeHandle(
      rect: Rect.fromLTWH(offset.dx, offset.dy, _corner, _corner),
      cursor: cursor,
      onDrag: onDrag,
    );
  }

  Widget _edgeHandle({
    required Rect rect,
    required MouseCursor cursor,
    required ValueChanged<Offset> onDrag,
  }) {
    return Positioned.fromRect(
      rect: rect,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (details) => onDrag(details.delta),
        ),
      ),
    );
  }

  void _resize(
    Rect rect,
    Rect bounds, {
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final base = _pendingRect ?? rect;
    var nextLeft = base.left;
    var nextTop = base.top;
    var nextRight = base.right;
    var nextBottom = base.bottom;

    if (left != null) {
      nextLeft = (base.left + left)
          .clamp(bounds.left, base.right - widget.minWidth)
          .toDouble();
    } else if (right != null) {
      nextRight = (base.right + right)
          .clamp(base.left + widget.minWidth, bounds.right)
          .toDouble();
    }

    if (top != null) {
      nextTop = (base.top + top)
          .clamp(bounds.top, base.bottom - widget.minHeight)
          .toDouble();
    } else if (bottom != null) {
      nextBottom = (base.bottom + bottom)
          .clamp(base.top + widget.minHeight, bounds.bottom)
          .toDouble();
    }

    _queueRect(Rect.fromLTRB(nextLeft, nextTop, nextRight, nextBottom));
  }

  void _move(Rect rect, Rect bounds, Offset delta) {
    final base = _pendingRect ?? rect;
    final left = (base.left + delta.dx)
        .clamp(bounds.left, bounds.right - base.width)
        .toDouble();
    final top = (base.top + delta.dy)
        .clamp(bounds.top, bounds.bottom - base.height)
        .toDouble();
    _queueRect(Rect.fromLTWH(left, top, base.width, base.height));
  }

  void _queueRect(Rect rect) {
    _pendingRect = rect;
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      final pending = _pendingRect;
      _pendingRect = null;
      if (mounted && pending != null) {
        _rectNotifier.value = pending;
      }
    });
  }
}
