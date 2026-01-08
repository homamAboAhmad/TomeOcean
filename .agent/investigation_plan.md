
# Investigation Plan: 1-Page Discrepancy

The user noticed a difference of 1 page in two of the tested files (`ex3_10p.docx` and `HomamIbraheemCV.docx`).
Orig: 13, Calc: 12
Orig: 3,  Calc: 2

**Hypothesis:** This often happens due to:
1.  **Title Page:** Word sometimes counts the title page as 0 or doesn't number it, while our `lastRenderedPageBreak` logic starts at 1 and counts breaks.
2.  **Last Page Break:** If the document ends with a break or content pushes to a new page without a `lastRenderedPageBreak` tag (e.g., implicit end), we might be off.
3.  **Hidden Text:** If Word counts hidden text that pushes a page but our renderer hides it? (Unlikely, we inject hidden text).

**Strategy:**
I will inspect `ex3_10p.docx` XML content specifically around page breaks to see how they are marked.
I'll extract the XML and count the actual `lastRenderedPageBreak` tags vs `br` page breaks.

## Steps
1.  Extract `word/document.xml` from `ex3_10p.docx` (using python script).
2.  Count occurs of `w:lastRenderedPageBreak` and `w:br type="page"`.
3.  Analyze structure to see if we missed an implicit start page or if `current_page` should start at 0 or 1 differently based on `w:sectPr`.
