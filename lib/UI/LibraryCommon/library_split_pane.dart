import 'package:flutter/material.dart';
import 'library_design_tokens.dart';
import 'library_resize_divider.dart';

class LibrarySplitController extends ValueNotifier<double> {
  LibrarySplitController([super.value = 0.6]);
}

class LibrarySplitPane extends StatefulWidget {
  final Axis axis;
  final Widget first;
  final Widget second;
  final double initialRatio;
  final double? ratio;
  final ValueChanged<double>? onRatioChanged;
  final LibrarySplitController? controller;
  final double minRatio;
  final double maxRatio;

  const LibrarySplitPane({
    super.key,
    required this.axis,
    required this.first,
    required this.second,
    this.initialRatio = 0.6,
    this.ratio,
    this.onRatioChanged,
    this.controller,
    this.minRatio = 0.25,
    this.maxRatio = 0.75,
  });

  @override
  State<LibrarySplitPane> createState() => _LibrarySplitPaneState();
}

class _LibrarySplitPaneState extends State<LibrarySplitPane> {
  late double _ratio = widget.initialRatio;

  @override
  void didUpdateWidget(covariant LibrarySplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ratio != null && widget.ratio != oldWidget.ratio) {
      _ratio = widget.ratio!;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_syncController);
    if (widget.controller != null) _ratio = widget.controller!.value;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncController);
    super.dispose();
  }

  void _syncController() {
    if (_ratio != widget.controller!.value) {
      setState(() => _ratio = widget.controller!.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final firstSize =
            (total - LibraryDesignTokens.paneDividerExtent) * _ratio;
        final children = [
          SizedBox(
            width: widget.axis == Axis.horizontal ? firstSize : null,
            height: widget.axis == Axis.vertical ? firstSize : null,
            child: widget.first,
          ),
          _handle(total),
          Expanded(child: widget.second),
        ];
        return widget.axis == Axis.horizontal
            ? Row(textDirection: TextDirection.ltr, children: children)
            : Column(children: children);
      },
    );
  }

  Widget _handle(double total) {
    final horizontal = widget.axis == Axis.horizontal;
    return LibraryResizeDivider(
      axis: widget.axis,
      onDragUpdate: (details) {
        final delta = horizontal ? details.delta.dx : details.delta.dy;
        final next = (_ratio + delta / total).clamp(
          widget.minRatio,
          widget.maxRatio,
        );
        setState(() => _ratio = next);
        widget.controller?.value = next;
      },
    );
  }
}
