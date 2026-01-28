import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';

/// A specialized utility to inject page markers into Table of Contents (TOC) paragraphs.
///
/// This class focuses EXCLUSIVELY on paragraphs identified as TOC rows (e.g., `isSdtRow="True"`).
/// It respects the original Word document pagination by detecting `w:lastRenderedPageBreak`
/// elements and injecting `{{PG:X}}` markers accordingly.
class TocPageInjector {
  /// Processes a list of XML paragraphs and injects page markers into TOC entries.
  ///
  /// [allPs] The list of all paragraph elements (including TOC rows).
  /// [startPage] The page number where the TOC begins (usually determined from the context).
  ///
  /// Returns the modified list of paragraphs (modifications happen in-place on fragments).
  static void injectPageMarkers(List<XmlElement> allPs, int startPage) {
    // 1. Find the range of the TOC (Index rows)
    int firstTocIndex = -1;
    for (int i = 0; i < allPs.length; i++) {
      if (allPs[i].getAttribute("isSdtRow") == "True") {
        firstTocIndex = i;
        break;
      }
    }

    // If no TOC found, nothing to do
    if (firstTocIndex == -1) return;

    // 2. Determine Start Page
    // We scan backwards from the paragraph BEFORE the TOC.
    // If we find a page marker, that's our start page. Otherwise, default to [startPage] (usually 1).
    int currentPage = startPage;

    // Optimization (User Request): Check paragraphs preceding the TOC only.
    for (int i = firstTocIndex - 1; i >= 0; i--) {
      int? foundPage = _extractPageNumber(allPs[i]);
      if (foundPage != null) {
        currentPage = foundPage;
        debugPrint(
          "TOC Optimization: Found start page $currentPage at index $i",
        );
        break;
      }
    }

    debugPrint(
      "--- TOC Page Injection Start: Initial Page $currentPage (TOC starts at index $firstTocIndex) ---",
    );
    int tocRowsCount = 0;
    int breaksFound = 0;

    // 3. Process TOC Rows ONLY
    // We only iterate effectively through the TOC section
    for (int i = firstTocIndex; i < allPs.length; i++) {
      var para = allPs[i];
      bool isTocRow = para.getAttribute("isSdtRow") == "True";

      // If we hit a non-TOC row after starting TOC, we might be done.
      // However, sometimes TOC is split or there are loose paragraphs.
      // For safety, we only process if it IS a TOC row.
      if (!isTocRow) {
        continue;
      }

      tocRowsCount++;

      // Check for breaks
      bool hasBreak = _hasRenderedBreak(para);
      bool breakAtStart = false;

      if (hasBreak) {
        breakAtStart = _isBreakAtStart(para);
        // If break is at the very beginning (before text), we are already on the NEXT page
        if (breakAtStart) {
          currentPage++;
          breaksFound++;
          // debugPrint("TOC: Found START break in para. Moving to $currentPage");
        }
      }

      // Inject Marker
      if (!_hasPageMarker(para)) {
        _injectMarker(para, currentPage);
      }

      // If break is NOT at start (i.e. at end or middle), we move to next page AFTER this paragraph
      if (hasBreak && !breakAtStart) {
        currentPage++;
        breaksFound++;
        // debugPrint("TOC: Found END/MID break in para. Next para will be ${currentPage}");
      }
    }

    debugPrint(
      "--- TOC Page Injection End. Last Page: $currentPage. TOC Rows: $tocRowsCount. Breaks: $breaksFound ---",
    );
  }

  /// Checks if the paragraph already contains a {{PG:X}} marker.
  static bool _hasPageMarker(XmlElement para) {
    // Simple text search is faster and sufficient for this check
    return para.innerText.contains(RegExp(r'\{\{PG:\d+\}\}'));
  }

  /// Injects the {{PG:X}} marker into the paragraph.
  ///
  /// Strategy: Insert a new <w:r> at the beginning of the paragraph containing the marker.
  /// This ensures it's detected by the pagination logic without disrupting the visual content
  /// because the pagination logic usually strips these markers.
  static void _injectMarker(XmlElement para, int pageNum) {
    // Construct the run element: <w:r><w:t>{{PG:X}}</w:t></w:r>
    var markerRun = XmlElement(XmlName('w:r'), [], [
      XmlElement(XmlName('w:t'), [], [XmlText('{{PG:$pageNum}}')]),
    ]);

    // Find index to insert at (after pPr if it exists, otherwise 0)
    int insertIndex = 0;
    for (int i = 0; i < para.children.length; i++) {
      var child = para.children[i];
      if (child is XmlElement && child.name.local == 'pPr') {
        insertIndex = i + 1;
        break; // pPr comes first, so we can stop after finding it
      }
    }

    // Insert at the determined position
    if (insertIndex < para.children.length) {
      para.children.insert(insertIndex, markerRun);
    } else {
      para.children.add(markerRun);
    }
  }

  /// Checks for the existence of `w:lastRenderedPageBreak` in any descendant.
  static bool _hasRenderedBreak(XmlElement para) {
    // We search for local name "lastRenderedPageBreak" to avoid namespace prefix issues (w:...)
    return para
            .findAllElements('lastRenderedPageBreak', namespace: '*')
            .isNotEmpty ||
        para.findAllElements('w:lastRenderedPageBreak').isNotEmpty;
  }

  /// Checks if the page break is at the "start" of the paragraph.
  /// "Start" means it appears before any significant text (<w:t> with content).
  static bool _isBreakAtStart(XmlElement para) {
    // We iterate through runs <w:r>
    // If we find <lastRenderedPageBreak> FIRST, it's a start break.
    // If we find significant text FIRST, it's an end break.

    // Get all runs
    var runs = para.findAllElements('w:r');

    for (var run in runs) {
      // Check children of run in order
      for (var child in run.children) {
        if (child is XmlElement) {
          // Check for lastRenderedPageBreak (ignoring namespace prefix logic since we check local name)
          if (child.name.local == 'lastRenderedPageBreak') {
            return true; // Found break before text
          }
          if (child.name.local == 't') {
            if (child.innerText.trim().isNotEmpty) {
              return false; // Found text before break
            }
          }
        }
      }
    }
    return false; // Default
  }

  /// Extracts the page number from a {{PG:X}} marker if present.
  static int? _extractPageNumber(XmlElement para) {
    var text = para.innerText;
    var match = RegExp(r'\{\{PG:(\d+)\}\}').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
