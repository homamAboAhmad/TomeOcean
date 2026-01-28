# Zoom Implementation Documentation

## Objective
Implement robust zoom functionality for `DocViewer` that supports:
1.  **Mouse**: Ctrl + Wheel.
2.  **Keyboard**: Ctrl + (+), Ctrl + (-), Ctrl + (0) to reset.
3.  **Trackpad**: Pinch-to-zoom without conflicting with scrolling.

## Implementation Details

### 1. `DocZoomController`
Separated zoom logic into a dedicated controller (`lib/Controllers/DocZoomController.dart`) adhering to the **Single Responsibility Principle**.
- **State**: Manages `minScale`, `maxScale`, `currentScale`.
- **Logic**:
    - `zoomIn()`, `zoomOut()`, `resetZoom()`.
    - `handlePointerSignal`: Handles Mouse Wheel + Ctrl events.
    - `handlePanZoomStart`, `handlePanZoomUpdate`: Handles Trackpad "pinch" gestures specifically.

### 2. `DocViewer` Integration
Refactored `lib/UI/DocViewer.dart`:
- **Removed**: Local state variables (`_zoomScale`, `_baseScale`, `_handleZoom`, etc.).
- **Added**: `DocZoomController` initialization and disposal.
- **Trackpad Support**:
    - Replaced `GestureDetector` (which consumed scroll events) with `Listener`.
    - Used `onPointerPanZoomStart` and `onPointerPanZoomUpdate` to intercept native trackpad zoom gestures.
    - This ensures **Two-finger Scroll** is handled by the `ListView` (Scrolling), while **Two-finger Pinch** is handled by `DocZoomController` (Zooming).
- **Shortcuts**: Added keyboard shortcuts via `CallbackShortcuts` connected to the controller.

## Usage
- **Zoom In**: `Ctrl + =` or `Ctrl + +` or `Ctrl + Wheel Up` or `Pin Out`.
- **Zoom Out**: `Ctrl + -` or `Ctrl + Wheel Down` or `Pin In`.
- **Reset**: `Ctrl + 0`.
