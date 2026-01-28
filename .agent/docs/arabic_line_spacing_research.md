# Arabic Line Spacing: Word vs Flutter - Research & Solutions

## Current Status (Jan 23, 2026)
- **Partially Solved:** The current implementation uses a static safety margin factor (`1.30`) in `PPr.dart`.
- **Known Issue:** `StrutStyle` with `forceStrutHeight: true` can cause overlapping text if `fontSize` is not passed or mismatched.
- **Resolution:** Inherited style logic was reverted to simplify for now. The cache was the primary culprit for recent overlaps.
- **Next Steps:** Postponed for now. Future work should implement the JSON Lookup Table solution.

---

## Problem Statement

When rendering `.docx` files in Flutter, Arabic text appears **cramped/tight** compared to Microsoft Word.
Attempts to fix this using `StrutStyle` with a constant factor (1.30) have revealed complex side effects.

---

## Root Cause Analysis

### 1. The Core Metrics Discrepancy
- Word uses **Windows Metrics** (`usWinAscent` + `usWinDescent`) + script-specific padding.
- Flutter uses typographic metrics (`hhea` or `OS/2 typo`).
- **Result:** Flutter's default lines are tighter.

### 2. The "StrutStyle" Dilemma
We attempted to force line height using `StrutStyle(height: 1.30, forceStrutHeight: true)`.
This creates a critical conflict:
- **Variant A (No fontSize in Strut):** Uses default 14px size.
  - *Result:* Large headers (e.g., 24px) are forced into 14px strut-lines -> **Overlap/Chaos**.
- **Variant B (With fontSize in Strut):** Uses paragraph-level default font size.
  - *Result:* If runs have explicit formatting (Direct Formatting) larger than the paragraph default, they still overlap.

**Conclusion:** Using `forceStrutHeight: true` is risky unless the `StrutStyle` font size **perfectly matches** the largest text in the line.

---

## Proposed Solutions (For Future Implementation)

### Solution 1: Dynamic Font Scaling (The "Google Model" integration)
Instead of forcing a global `1.30` strut, calculate the **correct height factor** for each font so that `height: 1.0` (or `1.15`) naturally behaves like Word.
- **Goal:** avoid `forceStrutHeight: true` if possible, OR use it with exact metrics.
- **Requires:** Accurate metrics (JSON table) per font.

### Solution 2: The "Max Font Size" Strut
If we must use `forceStrutHeight: true`:
- We must scan all runs in the paragraph.
- Find the **maximum font size**.
- Pass THAT size to `StrutStyle`.
- *Code path:* Update `Paragraph.dart` -> `_getTRunsW` to find max font size of spans.

### Solution 3: Revert to "Natural" Spacing (Safest)
- Remove `forceStrutHeight: true`.
- Accept that lines are slightly tighter than Word.
- Use `height: 1.5` (or similar) on `TextStyle` directly, not Strut. (Less accurate emulation, but safe).

---

## Recommended Action Plan

1. **Verify:** JSON Table solution (Solution 1) is the most robust long-term.
2. **Immediate Fix (Postponed):** Implement **Solution 2** (Max Font Size) if overlaps recur.

---
