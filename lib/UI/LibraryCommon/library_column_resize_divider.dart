import 'package:flutter/material.dart';
import 'library_design_tokens.dart';

class LibraryColumnResizeDivider extends StatefulWidget {
  final GestureDragUpdateCallback onDragUpdate;
  final double extent;

  const LibraryColumnResizeDivider({
    super.key,
    required this.onDragUpdate,
    this.extent = LibraryDesignTokens.columnDividerHitExtent,
  });

  @override
  State<LibraryColumnResizeDivider> createState() =>
      _LibraryColumnResizeDividerState();
}

class _LibraryColumnResizeDividerState
    extends State<LibraryColumnResizeDivider> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _active = true),
        onPanEnd: (_) => setState(() => _active = false),
        onPanCancel: () => setState(() => _active = false),
        onPanUpdate: widget.onDragUpdate,
        child: SizedBox(
          width: widget.extent,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: _active ? 2 : 1,
              height: double.infinity,
              color: _active
                  ? LibraryDesignTokens.selectedBorder
                  : LibraryDesignTokens.divider,
            ),
          ),
        ),
      ),
    );
  }
}
