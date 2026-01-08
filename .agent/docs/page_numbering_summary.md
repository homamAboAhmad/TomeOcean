# Word Open XML Page Numbering Summary

This document summarizes the mechanisms for handling page numbering within Word Open XML (`.docx`) documents. It covers section properties, numbering initialization, and the field codes used to display numbers.

## 1. Overview
Page numbering in Word is a combination of **Section Properties** (defining *how* numbers are calculated) and **Fields** (defining *where* numbers are displayed).

- **`w:sectPr` (Section Properties):** Stores configuration for page numbers (starting value, format).
- **`w:fldSimple` / `w:instrText` (Fields):** Placeholders in the document body (usually headers/footers) that render the current page number.

## 2. Section Properties (`w:sectPr`)
The `w:sectPr` element defines the layout and settings for a section. It can appear:
- As the last child of a `<w:p>` (paragraph) element (for section breaks).
- As the last child of the `w:body` element (for the final section of the document).

### `w:pgNumType` (Page Numbering Settings)
Inside `w:sectPr`, the `w:pgNumType` element controls the numbering behavior for that specific section.

**XML Structure:**
```xml
<w:sectPr>
    <w:pgNumType w:fmt="decimal" w:start="1" w:chapStyle="1" w:chapSep="hyphen"/>
    ...
</w:sectPr>
```

**Attributes:**

| Attribute | Description | Example Values |
| :--- | :--- | :--- |
| **`w:start`** | Specifies the starting page number for this section. If omitted, numbering continues from the previous section. | `1`, `10`, `100` |
| **`w:fmt`** | Defines the number format. | `decimal` (1, 2, 3)<br>`lowerRoman` (i, ii, iii)<br>`upperRoman` (I, II, III)<br>`lowerLetter` (a, b, c)<br>`upperLetter` (A, B, C)<br>`cardinalText` (One, Two)<br>`ordinalText` (First, Second) |
| **`w:chapStyle`** | (Optional) Refers to the *Style ID* of the heading style used for chapter numbering. Allows "1-1", "1-A" formats. | `1` (for Heading 1), `2` (for Heading 2) |
| **`w:chapSep`** | (Optional) Separator between chapter and page number. | `hyphen` (-), `period` (.), `colon` (:), `emDash` (—), `enDash` (–) |

## 3. Displaying Page Numbers (Field Codes)
The `w:pgNumType` only sets the *counter*. To actually see the number on the page, a **Field** must be inserted, typically in a Header or Footer.

### The `PAGE` Field
The `PAGE` field instructs the renderer to display the current page number.

**Simple Field Syntax (`w:fldSimple`):**
```xml
<w:p>
    <w:r>
        <w:t>Page </w:t>
    </w:r>
    <w:fldSimple w:instr=" PAGE \* MERGEFORMAT ">
        <w:r>
            <w:t>1</w:t> <!-- Cached/last calculated value -->
        </w:r>
    </w:fldSimple>
</w:p>
```

**Complex Field Syntax (`w:instrText`):**
Required for more complex instructions.
```xml
<w:p>
    <w:r>
        <w:fldChar w:fldCharType="begin"/>
    </w:r>
    <w:r>
        <w:instrText xml:space="preserve"> PAGE </w:instrText>
    </w:r>
    <w:r>
        <w:fldChar w:fldCharType="separate"/>
    </w:r>
    <w:r>
        <w:t>1</w:t>
    </w:r>
    <w:r>
        <w:fldChar w:fldCharType="end"/>
    </w:r>
</w:p>
```

### The `NUMPAGES` Field
Displays the total number of pages in the document.
```xml
<w:fldSimple w:instr=" NUMPAGES "/>
```

### The `SECTIONPAGES` Field
Displays the total number of pages in the current section.
```xml
<w:fldSimple w:instr=" SECTIONPAGES "/>
```

## 4. Common Scenarios

### Restarting Numbering
To restart numbering at 1 for a new chapter:
1. Insert a Section Break.
2. In the new section's `w:sectPr`, add `<w:pgNumType w:start="1"/>`.

### Continuous Numbering
To ensure numbering flows from the previous section:
1. Omit the `w:start` attribute in `w:pgNumType`.
2. OR explicitly set `<w:pgNumType w:chapStyle="" .../>` without a start index, implying continuation.

### Chapter-Page Format (e.g., "IV-12")
1. Ensure your chapters use a specific Heading style (e.g., Heading 1).
2. Sets `w:chapStyle="1"` (pointing to Heading 1's style ID).
3. Set `w:chapSep="hyphen"`.
4. Ensure the `PAGE` field is present.

## 5. References
- **ECMA-376 Part 1**: Fundamentals and Markup Language Reference (Section 17.6.12 `pgNumType`).
- **Microsoft Open XML SDK Documentation**: Classes `PageNumberType`, `SectionProperties`.
- **ISO/IEC 29500-1**: Office Open XML File Formats - Part 1: Fundamentals and Markup Language Reference.
