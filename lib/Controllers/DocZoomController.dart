import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocZoomController extends ValueNotifier<double> {
  final double minScale;
  final double maxScale;
  final double step;

  DocZoomController({
    double initialScale = 0.75,
    this.minScale = 0.5,
    this.maxScale = 3.0,
    this.step = 0.1,
  }) : super(initialScale);

  void zoomIn() {
    value = (value + step).clamp(minScale, maxScale);
  }

  void zoomOut() {
    value = (value - step).clamp(minScale, maxScale);
  }

  void resetZoom() {
    value = 1.0;
  }

  void setScale(double newScale) {
    value = newScale.clamp(minScale, maxScale);
  }

  void handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Check for Control key (Left or Right)
      final bool isCtrlPressed =
          HardwareKeyboard.instance.isLogicalKeyPressed(
            LogicalKeyboardKey.controlLeft,
          ) ||
          HardwareKeyboard.instance.isLogicalKeyPressed(
            LogicalKeyboardKey.controlRight,
          );

      if (isCtrlPressed) {
        if (event.scrollDelta.dy < 0) {
          zoomIn();
        } else {
          zoomOut();
        }
      }
    }
  }

  double _baseScale = 1.0;

  void handlePanZoomStart(PointerPanZoomStartEvent event) {
    _baseScale = value;
  }

  void handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // Only zoom if the scale is actually changing (pinch gesture)
    if (event.scale != 1.0) {
      setScale(_baseScale * event.scale);
    }
  }
}
