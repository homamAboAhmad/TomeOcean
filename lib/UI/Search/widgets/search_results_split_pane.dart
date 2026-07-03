import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';

class SearchResultsSplitPane extends StatefulWidget {
  final Widget bookPane;
  final Widget resultsPanel;
  final bool resultsHidden;
  final double initialResultsFraction;

  const SearchResultsSplitPane({
    super.key,
    required this.bookPane,
    required this.resultsPanel,
    required this.resultsHidden,
    this.initialResultsFraction = 1 / 3,
  });

  @override
  State<SearchResultsSplitPane> createState() => _SearchResultsSplitPaneState();
}

class _SearchResultsSplitPaneState extends State<SearchResultsSplitPane> {
  late double _resultsFraction;
  double? _previewResultsFraction;

  @override
  void initState() {
    super.initState();
    _resultsFraction = widget.initialResultsFraction;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resultsHidden) return widget.bookPane;
    return LayoutBuilder(
      builder: (context, constraints) {
        const dividerHeight = 8.0;
        final height = constraints.maxHeight;
        final resultsHeight = (height * _resultsFraction)
            .clamp(height * 0.18, height * 0.75)
            .toDouble();
        final bookHeight = height - resultsHeight - dividerHeight;
        final previewTop = _previewResultsFraction == null
            ? null
            : height -
                (height * _previewResultsFraction!)
                    .clamp(height * 0.18, height * 0.75);
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: bookHeight,
                  child: RepaintBoundary(child: widget.bookPane),
                ),
                _ResizeDivider(
                  totalHeight: height,
                  currentFraction: () =>
                      _previewResultsFraction ?? _resultsFraction,
                  onPreviewChanged: (value) {
                    setState(() => _previewResultsFraction = value);
                  },
                  onCommitted: () {
                    setState(() {
                      _resultsFraction =
                          _previewResultsFraction ?? _resultsFraction;
                      _previewResultsFraction = null;
                    });
                  },
                  onCancelled: () {
                    setState(() => _previewResultsFraction = null);
                  },
                ),
                SizedBox(
                  height: resultsHeight,
                  child: RepaintBoundary(child: widget.resultsPanel),
                ),
              ],
            ),
            if (previewTop != null)
              Positioned(
                top: previewTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(height: 2, color: actionColor),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResizeDivider extends StatefulWidget {
  final double totalHeight;
  final double Function() currentFraction;
  final ValueChanged<double> onPreviewChanged;
  final VoidCallback onCommitted;
  final VoidCallback onCancelled;

  const _ResizeDivider({
    required this.totalHeight,
    required this.currentFraction,
    required this.onPreviewChanged,
    required this.onCommitted,
    required this.onCancelled,
  });

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  double _pendingDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (_) {
        _pendingDelta = 0;
        widget.onCommitted();
      },
      onVerticalDragCancel: () {
        _pendingDelta = 0;
        widget.onCancelled();
      },
      onVerticalDragUpdate: (details) {
        _pendingDelta += details.delta.dy;
        if (_pendingDelta.abs() < 6) return;
        final next = (widget.currentFraction() -
                _pendingDelta / widget.totalHeight)
            .clamp(0.18, 0.75)
            .toDouble();
        _pendingDelta = 0;
        widget.onPreviewChanged(next);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 8,
          color: mutedColor,
          alignment: Alignment.center,
          child: Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.58),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
