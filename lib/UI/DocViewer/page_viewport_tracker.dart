import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PageViewportTracker {
  PageViewportTracker({
    required this.scrollController,
    required this.totalPages,
    required this.zoomScale,
    required this.basePageHeightFor,
  });

  final ScrollController scrollController;
  final int Function() totalPages;
  final double Function() zoomScale;
  final double Function(int pageIndex) basePageHeightFor;

  final Map<int, double> _pageTopOffsets = {};
  final Map<int, double> _pageExtents = {};
  bool _suppressScrollTracking = false;

  bool get suppressScrollTracking => _suppressScrollTracking;

  void clearMeasurements() {
    _pageTopOffsets.clear();
    _pageExtents.clear();
  }

  void beginProgrammaticJump() {
    _suppressScrollTracking = true;
  }

  void endProgrammaticJump() {
    _suppressScrollTracking = false;
  }

  void capturePageMetrics({
    required Map<int, GlobalKey> pageKeys,
    required int pageIndex,
  }) {
    final pageContext = pageKeys[pageIndex]?.currentContext;
    if (pageContext == null) return;

    final renderObject = pageContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final viewport = RenderAbstractViewport.of(renderObject);
    if (viewport == null) return;

    final top = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final bottom = viewport.getOffsetToReveal(renderObject, 1.0).offset;
    final extent = (bottom - top).abs();

    _pageTopOffsets[pageIndex] = top;
    if (extent > 0) {
      _pageExtents[pageIndex] = extent;
    }
  }

  void jumpToPage({
    required int pageIndex,
    required Map<int, GlobalKey> pageKeys,
    required VoidCallback onSettled,
    int remainingAttempts = 8,
  }) {
    if (!scrollController.hasClients) {
      endProgrammaticJump();
      return;
    }

    final targetContext = pageKeys[pageIndex]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.0,
        duration: Duration.zero,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        capturePageMetrics(pageKeys: pageKeys, pageIndex: pageIndex);
        onSettled();
        endProgrammaticJump();
      });
      return;
    }

    final exactOffset = _pageTopOffsets[pageIndex];
    if (exactOffset != null) {
      final clamped = exactOffset.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent,
      ).toDouble();
      scrollController.jumpTo(clamped);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpToPage(
          pageIndex: pageIndex,
          pageKeys: pageKeys,
          onSettled: onSettled,
          remainingAttempts: remainingAttempts - 1,
        );
      });
      return;
    }

    if (remainingAttempts <= 0) {
      endProgrammaticJump();
      return;
    }

    double offset = estimatePageOffset(pageIndex);
    if (offset < 0) offset = 0;
    final maxOffset = scrollController.position.maxScrollExtent;
    if (offset > maxOffset) offset = maxOffset;
    scrollController.jumpTo(offset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpToPage(
        pageIndex: pageIndex,
        pageKeys: pageKeys,
        onSettled: onSettled,
        remainingAttempts: remainingAttempts - 1,
      );
    });
  }

  int resolveCurrentPageFromScroll(double scrollOffset) {
    if (_pageTopOffsets.isNotEmpty) {
      final probeOffset = scrollOffset + 20.0;
      final measuredPages = _pageTopOffsets.keys.toList()..sort();
      int resolved = 0;
      bool matchedMeasuredPage = false;

      for (final page in measuredPages) {
        final top = _pageTopOffsets[page]!;
        final nextTop = _pageTopOffsets[page + 1];
        if (probeOffset >= top) {
          resolved = page;
          matchedMeasuredPage = true;
          if (nextTop != null && probeOffset < nextTop) {
            break;
          }
        }
      }

      if (matchedMeasuredPage) {
        return resolved.clamp(0, totalPages() - 1);
      }
    }

    double accumulated = 20.0;
    for (int page = 0; page < totalPages(); page++) {
      accumulated += estimatedPageExtent(page);
      if (scrollOffset < accumulated) {
        return page;
      }
    }

    return totalPages() - 1;
  }

  double estimatePageOffset(int pageIndex) {
    final lowerPages = _pageTopOffsets.keys.where((page) => page < pageIndex).toList()
      ..sort();
    if (lowerPages.isNotEmpty) {
      final anchorPage = lowerPages.last;
      double offset = _pageTopOffsets[anchorPage]!;
      for (int page = anchorPage; page < pageIndex; page++) {
        offset += estimatedPageExtent(page);
      }
      return offset;
    }

    final upperPages = _pageTopOffsets.keys.where((page) => page > pageIndex).toList()
      ..sort();
    if (upperPages.isNotEmpty) {
      final anchorPage = upperPages.first;
      double offset = _pageTopOffsets[anchorPage]!;
      for (int page = anchorPage - 1; page >= pageIndex; page--) {
        offset -= estimatedPageExtent(page);
      }
      return offset;
    }

    double offset = 20.0;
    for (int page = 0; page < pageIndex; page++) {
      offset += estimatedPageExtent(page);
    }
    return offset;
  }

  double estimatedPageExtent(int pageIndex) {
    final exactExtent = _pageExtents[pageIndex];
    if (exactExtent != null) {
      return exactExtent + 20.0;
    }

    return (basePageHeightFor(pageIndex) * zoomScale()) + 20.0;
  }
}
