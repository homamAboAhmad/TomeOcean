import 'package:flutter/material.dart';
import 'library_design_tokens.dart';

class LibraryResizeDivider extends StatefulWidget {
  final Axis axis;
  final GestureDragUpdateCallback onDragUpdate;
  final double extent;
  final double gripExtent;
  final bool showBorders;

  const LibraryResizeDivider({
    super.key,
    required this.axis,
    required this.onDragUpdate,
    this.extent = LibraryDesignTokens.paneDividerExtent,
    this.gripExtent = LibraryDesignTokens.dividerGripExtent,
    this.showBorders = true,
  });

  @override
  State<LibraryResizeDivider> createState() => _LibraryResizeDividerState();
}

class _LibraryResizeDividerState extends State<LibraryResizeDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: widget.onDragUpdate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: horizontal ? widget.extent : double.infinity,
          height: horizontal ? double.infinity : widget.extent,
          decoration: BoxDecoration(
            color: _hovered
                ? LibraryDesignTokens.handleHover
                : LibraryDesignTokens.handle,
            border: widget.showBorders
                ? Border.symmetric(
                    vertical: horizontal
                        ? const BorderSide(
                            color: LibraryDesignTokens.divider,
                          )
                        : BorderSide.none,
                    horizontal: horizontal
                        ? BorderSide.none
                        : const BorderSide(
                            color: LibraryDesignTokens.divider,
                          ),
                  )
                : null,
          ),
          child: Center(
            child: Container(
              width: horizontal ? 3 : widget.gripExtent,
              height: horizontal ? widget.gripExtent : 3,
              decoration: BoxDecoration(
                color: LibraryDesignTokens.handleGrip,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
