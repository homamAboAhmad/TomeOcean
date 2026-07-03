part of '../HomePage.dart';

extension _HomePageDetachedTabResize on _HomePageState {
  static const double _resizeBorderWidth = 8;

  List<Widget> _resizeBorders(_DetachedHomeTabRecord record, Size bounds) {
    const w = _resizeBorderWidth;
    return [
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpDown,
          top: 0, left: w, right: w, height: w, topEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpDown,
          bottom: 0, left: w, right: w, height: w, bottomEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeLeftRight,
          left: 0, top: w, bottom: w, width: w, leftEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeLeftRight,
          right: 0, top: w, bottom: w, width: w, rightEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpLeftDownRight,
          top: 0, left: 0, width: w, height: w, topEdge: true, leftEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpRightDownLeft,
          top: 0, right: 0, width: w, height: w, topEdge: true, rightEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpRightDownLeft,
          bottom: 0, left: 0, width: w, height: w, bottomEdge: true, leftEdge: true),
      _resizeZone(record, bounds, SystemMouseCursors.resizeUpLeftDownRight,
          bottom: 0, right: 0, width: w, height: w, bottomEdge: true, rightEdge: true),
    ];
  }

  Widget _resizeZone(
    _DetachedHomeTabRecord record,
    Size bounds,
    MouseCursor cursor, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
    bool leftEdge = false,
    bool rightEdge = false,
    bool topEdge = false,
    bool bottomEdge = false,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() => _resizeDetachedTab(
                  record,
                  bounds,
                  details.delta,
                  leftEdge: leftEdge,
                  rightEdge: rightEdge,
                  topEdge: topEdge,
                  bottomEdge: bottomEdge,
                ));
          },
        ),
      ),
    );
  }

  void _resizeDetachedTab(
    _DetachedHomeTabRecord record,
    Size bounds,
    Offset delta, {
    required bool leftEdge,
    required bool rightEdge,
    required bool topEdge,
    required bool bottomEdge,
  }) {
    final offset = _offsetFor(record);
    final size = _sizeFor(record);
    var left = offset.dx;
    var top = offset.dy;
    var right = left + size.width;
    var bottom = top + size.height;

    if (leftEdge) left += delta.dx;
    if (rightEdge) right += delta.dx;
    if (topEdge) top += delta.dy;
    if (bottomEdge) bottom += delta.dy;
    if (right - left < _HomePageDetachedTabs._minDetachedWidth) {
      if (leftEdge) {
        left = right - _HomePageDetachedTabs._minDetachedWidth;
      } else {
        right = left + _HomePageDetachedTabs._minDetachedWidth;
      }
    }
    if (bottom - top < _HomePageDetachedTabs._minDetachedHeight) {
      if (topEdge) {
        top = bottom - _HomePageDetachedTabs._minDetachedHeight;
      } else {
        bottom = top + _HomePageDetachedTabs._minDetachedHeight;
      }
    }

    record.offset = Offset(left, top);
    record.size = Size(right - left, bottom - top);
    this._clampDetachedRecord(record, bounds);
  }
}
