# Table Styling and Cell Properties Fix Session
# جلسة إصلاح تنسيق الجداول وخصائص الخلايا

**Session Date | تاريخ الجلسة:** 2024-12-22
**Focus Area | المجال:** Table Cell Styling, Row Heights, Vertical Alignment, and Numbering

---

## Problem Statement | وصف المشكلة

### English
Multiple table rendering issues were identified:
1. **Cell heights inconsistent** - Cells in the same row had different heights
2. **Table borders not showing** - Borders defined in table styles weren't applied
3. **Cell shading missing** - Background colors from table styles not rendered
4. **Row numbers displaying vertically** - Numbers like "10" appeared as stacked digits ("1" over "0")
5. **vAlign not working** - Vertical alignment (top/center/bottom) wasn't applied to cell content
6. **Numbering counter incrementing on re-render** - Row numbers kept increasing with each page reload

### العربية
تم تحديد مشاكل متعددة في عرض الجداول:
1. **عدم تساوي ارتفاعات الخلايا** - الخلايا في نفس الصف لها ارتفاعات مختلفة
2. **الحدود لا تظهر** - الحدود المعرفة في أنماط الجدول لم تُطبق
3. **تظليل الخلايا مفقود** - ألوان الخلفية من أنماط الجدول لم تُعرض
4. **أرقام الصفوف تظهر عمودياً** - الأرقام مثل "10" تظهر مكدسة ("1" فوق "0")
5. **vAlign لا يعمل** - المحاذاة العمودية (أعلى/وسط/أسفل) لم تُطبق
6. **عداد الترقيم يزيد عند إعادة العرض** - أرقام الصفوف تستمر بالزيادة مع كل إعادة تحميل

---

## Root Causes Identified | الأسباب الجذرية

### 1. Cell Height Issue
**Cause:** `CrossAxisAlignment.start` was used instead of `stretch` in the Row widget
**Solution:** Changed to `CrossAxisAlignment.stretch` with `IntrinsicHeight` wrapper

### 2. Table Borders Issue
**Cause:** Borders were defined in `styles.xml` via `w:tblStyle`, not inline in table XML
**Solution:** Added `getTableStyleBorders()` function in `DocumentStyles.dart` and integrated as fallback in `_getCellBorder()`

### 3. Row Numbers Stacking Issue
**Cause:** `ListParagraph` numbering adds large `paddingLeft/paddingRight` from `indentLeft`, designed for full-page paragraphs. Inside narrow table cells, this caused text wrapping.

**Key Learning from Word XML Spec:**
> "When a ListParagraph is placed inside a table cell, its numbering and indentation are applied RELATIVE to the cell boundaries, rather than the document's overall margins."

**Solution:** Reset `paddingLeft` and `paddingRight` to 0 for paragraphs inside table cells.

### 4. vAlign Issue
**Cause:** The `Container` returned by `getCellWidget` didn't utilize height constraints correctly
**Solution:** Wrap cell content with `Align` widget using appropriate `Alignment` values (topCenter, center, bottomCenter)

### 5. Numbering Counter Issue
**Cause:** `Paragraph.fromXml()` calls `PPr.checkNumbering()` which calls `wordDocument.addParagraphNum()`, incrementing the global counter on every re-render
**Solution:** Added `skipNumberingCounter` flag to skip counter increment for table cells, and manually set `paragraphNumber = rowIndex + 1`

---

## Files Modified | الملفات المعدلة

### 1. `lib/wordToHTML/ParagraphTable.dart`

| Change | Purpose | الغرض |
|--------|---------|-------|
| `IntrinsicHeight` wrapper | Makes all cells in row same height | جعل كل الخلايا في الصف بنفس الارتفاع |
| `CrossAxisAlignment.stretch` | Cells expand to fill row height | الخلايا تتمدد لملء ارتفاع الصف |
| `_getRowHeightInfo()` returns `hRule` | Supports "exact" vs "atLeast" row heights | دعم ارتفاعات "exact" و "atLeast" |
| Reset `paddingLeft/paddingRight` | Fixes text wrapping in narrow cells | إصلاح التفاف النص في الخلايا الضيقة |
| `_getCellTextDirection()` | Detects vertical text (tbRl, btLr) | اكتشاف النص العمودي |
| `_getCellVerticalAlignment()` | Returns `Alignment` for vAlign | إرجاع Alignment للمحاذاة العمودية |
| `skipNumberingCounter: true` | Prevents counter increment on re-render | منع زيادة العداد عند إعادة العرض |
| `paragraphNumber = rowIndex + 1` | Sets correct sequence for table rows | تعيين الترتيب الصحيح لصفوف الجدول |

### 2. `lib/wordToHTML/DocumentStyles.dart`

| Change | Purpose | الغرض |
|--------|---------|-------|
| `getTableStyleBorders()` | Retrieves `w:tblBorders` from table style definition | استرجاع حدود الجدول من تعريف النمط |

### 3. `lib/wordToHTML/PPr.dart`

| Change | Purpose | الغرض |
|--------|---------|-------|
| `skipNumberingCounter` flag | Controls whether to increment numbering counter | التحكم بزيادة عداد الترقيم |
| Modified `fromXml()` signature | Accepts `skipNumberingCounter` parameter | قبول معامل `skipNumberingCounter` |
| Modified `checkNumbering()` | Skips counter when flag is true | تخطي العداد عندما يكون العلم true |

### 4. `lib/wordToHTML/Paragraph.dart`

| Change | Purpose | الغرض |
|--------|---------|-------|
| Modified `fromXml()` signature | Accepts `skipNumberingCounter` parameter | قبول معامل `skipNumberingCounter` |
| Passes flag to `PPr.fromXml()` | Propagates skip behavior | نقل سلوك التخطي |

---

## Key Technical Learnings | الدروس التقنية المستفادة

### Word Table XML Structure

```xml
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="PlainTable11"/>  <!-- Style reference -->
    <w:tblBorders>...</w:tblBorders>    <!-- Direct borders (higher priority) -->
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="2000"/>  <!-- Column widths in twips -->
  </w:tblGrid>
  <w:tr>  <!-- Table Row -->
    <w:trPr>
      <w:trHeight w:val="500" w:hRule="exact"/>  <!-- Row height -->
    </w:trPr>
    <w:tc>  <!-- Table Cell -->
      <w:tcPr>
        <w:tcW w:w="2000" w:type="dxa"/>  <!-- Cell width -->
        <w:vAlign w:val="center"/>         <!-- Vertical alignment -->
        <w:textDirection w:val="tbRl"/>    <!-- Vertical text -->
        <w:shd w:fill="CCCCCC"/>           <!-- Background color -->
        <w:tcBorders>...</w:tcBorders>     <!-- Cell borders -->
      </w:tcPr>
      <w:p>...</w:p>  <!-- Paragraph content -->
    </w:tc>
  </w:tr>
</w:tbl>
```

### Border Priority System
1. **Priority 1 (Highest):** Cell-level borders (`w:tcBorders`)
2. **Priority 2:** Table-level borders (`w:tblBorders` in table XML)
3. **Priority 3:** Table style borders (from `styles.xml`)

### Row Height Rules (w:hRule)
| Value | Behavior | السلوك |
|-------|----------|--------|
| `exact` | Fixed height, content may clip | ارتفاع ثابت، المحتوى قد يُقطع |
| `atLeast` | Minimum height, can grow | حد أدنى للارتفاع، يمكن أن ينمو |
| `auto` | Height determined by content | الارتفاع يتحدد بالمحتوى |

### Vertical Text Direction (w:textDirection)
| Value | Meaning | المعنى |
|-------|---------|--------|
| `tbRl` | Top to Bottom, Right to Left | من أعلى لأسفل، من اليمين لليسار |
| `btLr` | Bottom to Top, Left to Right | من أسفل لأعلى، من اليسار لليمين |
| `lrTb` | Default horizontal | أفقي افتراضي |

---

## Known Limitations | القيود المعروفة

### 1. Table Numbering Across Pages
**Issue:** When tables span multiple pages, numbering resets for each page fragment instead of continuing.
**Reason:** Each page contains a separate table fragment with its own `rowIndex`.
**Impact:** Table rows show 1-5 on page 1, then 1-5 again on page 2, instead of 1-5 then 6-10.
**Status:** Documented as known limitation, requires deeper refactor to fix.

### 2. Table Style Shading
**Issue:** Cell shading from table style conditional formatting (firstRow, firstCol) not fully applied.
**Reason:** Requires tracking cell position relative to table for conditional style matching.
**Status:** Basic shading works, conditional formatting needs enhancement.

### 3. Bold Text in Tables
**Issue:** Bold text may not display correctly in some table cells.
**Status:** Needs investigation.

---

## Development Pattern Discovered | نمط التطوير المكتشف

When working with table formatting in this project:

1. **Check direct cell properties first** (`w:tcPr`)
2. **Fallback to table properties** (`w:tblPr`)
3. **Finally check table style** (from `styles.xml`)

This mirrors Word's style inheritance hierarchy.

---

## Testing Notes | ملاحظات الاختبار

### Cache Clearing Command
Always clear the book cache before testing table changes:
```powershell
Remove-Item -Recurse -Force "C:\Users\nkxa2\Documents\tome_ocean\[BOOK_NAME]"
```

### Key Test Cases
1. Tables with explicit row heights (`w:trHeight`)
2. Tables using styles (e.g., `PlainTable11`)
3. Tables with automatic numbering (`w:numPr`)
4. Tables with vertical text
5. Tables with merged cells
6. Tables spanning multiple pages

---

## Related Documentation | التوثيق ذو الصلة

- `WordXmlDoumentation/key_sections.txt` - ECMA-376 reference for table elements
- `.agent/table_pagination_fix_session.md` - Related session on table pagination
- `.agent/warnings.md` - Critical project warnings

---

## Summary | الملخص

This session significantly improved table rendering by:
1. ✅ Fixing cell height consistency with `IntrinsicHeight` + `CrossAxisAlignment.stretch`
2. ✅ Adding table style border support as fallback
3. ✅ Fixing row number display by resetting paragraph padding in table cells
4. ✅ Implementing `vAlign` support using `Align` widget
5. ✅ Preventing numbering counter overflow with `skipNumberingCounter` flag
6. ⚠️ Known limitation: Numbering doesn't continue across page fragments
