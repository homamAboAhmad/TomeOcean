# Project Workflows | سير العمل في المشروع

---

## Debugging Headers and Footers | تصحيح الهيدر والفوتر

### When to Use
When headers/footers are not displaying correctly or showing wrong content.

### متى تستخدم
عندما لا يُعرض الهيدر/الفوتر بشكل صحيح أو يعرض محتوى خاطئ.

### Steps

1. **Enable debug logging** in `SectPr.dart`:
   - Look for `📄 SECTION DEBUG` and `📄 HEADER` messages
   - Check `titlePg` and `evenAndOddHeaders` settings

2. **Check section ranges**:
   - Look for `🔍 FINDING SECTION for page X`
   - Verify correct section is being used

3. **Check header paths**:
   - `headerFirstPath`, `headerDefaultPath`, `headerOddPath`, `headerEvenPath`
   - `null` means no header defined, should inherit from previous section

4. **Verify inheritance**:
   - Look for `→ Inherited` messages
   - If no inheritance message and path is null, header will be blank

---

## Debugging Page Numbering | تصحيح ترقيم الصفحات

### When to Use
When page numbers are skipping, resetting unexpectedly, or showing wrong values.

### Steps

1. **Check `PAGE NUM CALC` logs**:
   ```
   📄 PAGE NUM CALC: pageIndex=X, firstRange=Y, pgNumStart=Z, start=A, relativeIndex=B, value=C
   ```

2. **Verify section ranges**:
   - `firstRange` should be ≤ `pageIndex` ≤ `lastRange`
   - Check `🔍 FINDING SECTION` to see which section is used

3. **Check `pgNumStart`**:
   - If `null`, numbering continues from previous section
   - If specified, numbering starts from that value

4. **Common issues**:
   - Sections with `firstRange > lastRange` are invalid
   - Multiple sections with overlapping ranges

---

## Adding New Word XML Feature | إضافة ميزة Word XML جديدة

### Before Starting

// turbo-all

1. **Consult Word XML documentation**:
   ```
   d:\ImportantProjects\golden_shamela\WordXmlDoumentation\
   ```

2. **Search for relevant elements**:
   ```bash
   grep -r "element_name" WordXmlDoumentation/
   ```

3. **Understand the behavior** from the spec, don't assume

### Implementation Pattern

1. **Parse the XML** in appropriate file (`SectPr.dart`, `Paragraph.dart`, etc.)
2. **Store the value** in the model class
3. **Apply the logic** in the rendering/widget code
4. **Add debug logging** for troubleshooting
5. **Test with multiple documents**

---

## Testing Changes | اختبار التغييرات

### Quick Test

1. Hot reload (r) for UI changes
2. Hot restart (R) for parsing logic changes (re-parses the document)

### Full Test

1. Close the app completely
2. Delete cached data if needed
3. Restart and open a test document

---

## Project Structure Reference | مرجع هيكل المشروع

```
golden_shamela/
├── lib/
│   ├── Models/
│   │   ├── WordDocument.dart   # Main document model
│   │   └── WordPage.dart       # Page model
│   ├── UI/
│   │   ├── WordPageScreen.dart # Page rendering
│   │   └── DocViewer.dart      # Document viewer
│   ├── wordToHTML/
│   │   ├── SectPr.dart         # Section properties
│   │   ├── Paragraph.dart      # Paragraph parsing
│   │   ├── runT.dart           # Text run
│   │   └── AddDocData.dart     # Document parsing
│   └── Utils/
│       ├── ImageParser.dart    # Image parsing
│       └── WordUtils.dart      # Pagination logic
├── WordXmlDoumentation/        # Word XML reference docs
└── .agent/
    ├── project_knowledge.md    # This knowledge document
    └── workflows/              # Workflow files
```
