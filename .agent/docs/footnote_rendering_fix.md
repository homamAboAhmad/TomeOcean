# WordPage Layout & Sticky Footnotes Implementation

**Last Updated:** 2026-01-26
**Context:** Implementing a Microsoft Word-like page layout in Flutter where footnotes stick to the bottom of the page (`Sticky Footer`) regardless of content length, while maintaining a minimum page height (A4-like).

## The Core Challenge
The goal was to render a document page that:
1.  Has a **Minimum Height** (mimicking a physical page).
2.  Is **Expandable** if content exceeds the minimum height.
3.  Contains **Body Text** at the top.
4.  Contains **Footnotes** pinned to the absolute bottom.
5.  Keeps the **Separator Line** attached to the Body Text (or pushing footnotes down).
6.  Operates within a non-scrollable context (the page itself is a static block used within a pager).

### The Technical Constraint
Using `Expanded` or `Spacer` to push content down requires a parent with **Bounded Height**. However, to allow the page to expand infinitely for large content, the parent constraint usually allows `Infinity`. This conflict (`BoxConstraints forces an infinite height`) caused standard layouts (Stack, Column+Expanded) to crash or misbehave.

---

## 🏗️ The Final Solution Architecture

We implemented a **Conditional Hybrid Layout** in `lib/UI/WordPageScreen.dart` to handle different page states efficiently and robustly.

### 1. The Wrapper: `ConstrainedBox`
We wrap the entire page content in a `LayoutBuilder` (to access constraints if needed, though we primarily calculate manually based on `sectPr`) and then a `ConstrainedBox`.
```dart
ConstrainedBox(
  constraints: BoxConstraints(
    minHeight: calculatedPageHeight, // Enforces the A4 "feel"
  ),
  child: ...
)
```

### 2. The Logic: Smart Switching
To avoid overhead and potential "zero-size render box" errors, we check if footnotes exist.

#### Case A: Page WITHOUT Footnotes
We use a lightweight, safe standard structure.
*   **Widget:** Simple `Column`.
*   **Why:** No need for complex calculations. Using `IntrinsicHeight` here can cause crashes if children are empty or malformed.
```dart
if (widget.wordPage.fns.isEmpty) {
  return ConstrainedBox(..., child: Column(children: [BodyText]));
}
```

#### Case B: Page WITH Footnotes (The Complex Part)
We use `IntrinsicHeight` to solve the "Infinite vs Expanded" conflict.
*   **Widget:** `IntrinsicHeight` -> `Column` -> `Expanded` + `Footnotes`.
*   **How it works:** `IntrinsicHeight` calculates the exact height required by the content (or the minHeight constraint), effectively "bounding" the height for its children. This allows `Expanded` to work safely, pushing the footnotes to the bottom.
```dart
return ConstrainedBox(..., 
  child: IntrinsicHeight( // <--- The Savior
    child: Column(
      children: [
        Expanded(
          child: Column(
            children: [BodyText, Separator], // Kept together
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: 80), // Consistency
          child: Footnotes,
        ),
      ],
    ),
  ),
);
```

---

## ⚠️ Important Warnings & Trade-offs

> [!WARNING]
> **Do NOT Remove `IntrinsicHeight` in the Footnotes Case**
> Removing `IntrinsicHeight` while using `Expanded` inside a scrollable/unbounded parent will immediately cause a layout crash (`BoxConstraints forces an infinite height`). It is the essential bridge between the flexible layout and the infinite constraints.

> [!CAUTION]
> **Do NOT Use `IntrinsicHeight` for Empty Footnote Pages**
> Layouts without footnotes (or with zero-height render boxes) can cause `IntrinsicHeight` to fail or throw "Cannot hit test a render box with no size" errors. Always use the simple `Column` fallback for pages without footnotes.

> [!NOTE]
> **Footnote Minimum Height Strategy**
> We applied a `minHeight: 80` (approx 3-4 lines) to the footnote section.
> *   **Benefit:** Provides visual weight and consistency for pages with very short footnotes (prevents a single line looking "lost" at the bottom).
> *   **Trade-off:** On fully saturated pages, this consumes ~60px more space than strictly necessary. This was decided as an acceptable trade-off for layout stability and aesthetics.

> [!TIP]
> **Separator Positioning**
> The separator line is placed *inside* the Top `Column` (with the Body Text), not with the footnotes. This ensures it stays attached to the text block.

## Future Maintenance
If migrating to a different pagination system or `CustomPainter` approach:
1.  Ensure the definition of "Page Height" remains consistent across the app models (`WordPage`, `SectPr`).
2.  If performance issues arise on huge documents, profiling the `IntrinsicHeight` pass is the first step, though for single-page rendering it is negligible.
