# Golden Shamela - Project Knowledge Document
# وثيقة معرفة مشروع الشاملة الذهبية

---

## Project Overview | نظرة عامة على المشروع

### English
**Golden Shamela** is a sophisticated Flutter application designed for viewing and interacting with `.docx` files, with a particular focus on documents containing rich Arabic text and complex formatting. It functions as a `.docx` reader, meticulously parsing the Word document XML structure and rendering it accurately within the Flutter framework.

The application is intended to be a digital library or reader specifically designed for Islamic texts, likely in `.docx` format. It aims to provide a rich, accurate, and user-friendly viewing experience for such documents.

### العربية
**الشاملة الذهبية** هو تطبيق Flutter متطور مصمم لعرض والتفاعل مع ملفات `.docx`، مع التركيز بشكل خاص على المستندات التي تحتوي على نصوص عربية غنية وتنسيقات معقدة. يعمل كقارئ `.docx`، يحلل بنية XML لمستند Word بدقة ويعرضها بشكل صحيح ضمن إطار Flutter.

التطبيق مخصص ليكون مكتبة رقمية أو قارئ مصمم خصيصاً للنصوص الإسلامية بتنسيق `.docx`. يهدف إلى توفير تجربة عرض غنية ودقيقة وسهلة الاستخدام لهذه المستندات.

---

## Core Architecture | البنية الأساسية

### Key Components | المكونات الرئيسية

| Component | Path | Description (EN) | الوصف (ع) |
|-----------|------|------------------|-----------|
| `WordDocument` | `lib/Models/WordDocument.dart` | Main document model, holds pages, styles, sections | نموذج المستند الرئيسي، يحتوي الصفحات والأنماط والأقسام |
| `WordPage` | `lib/Models/WordPage.dart` | Single page model with paragraphs and footnotes | نموذج صفحة واحدة مع الفقرات والحواشي |
| `Paragraph` | `lib/wordToHTML/Paragraph.dart` | Paragraph parsing and rendering | تحليل وعرض الفقرة |
| `runT` | `lib/wordToHTML/runT.dart` | Text run with formatting properties | نص مع خصائص التنسيق |
| `SectPr` | `lib/wordToHTML/SectPr.dart` | Section properties (headers, footers, page numbering) | خصائص القسم (الهيدر، الفوتر، ترقيم الصفحات) |
| `ImageParser` | `lib/Utils/ImageParser.dart` | Image and TextBox parsing | تحليل الصور ومربعات النص |
| `WordPageScreen` | `lib/UI/WordPageScreen.dart` | Page rendering UI | واجهة عرض الصفحة |

---

## Word XML Reference | مرجع XML لـ Word

The project includes comprehensive Word XML documentation in:
- `WordXmlDoumentation/key_sections.txt`
- `WordXmlDoumentation/extracted_reference.txt`

**Important:** Always consult this documentation for Word XML behavior before implementing features.

يتضمن المشروع وثائق شاملة لـ Word XML في:
- `WordXmlDoumentation/key_sections.txt`
- `WordXmlDoumentation/extracted_reference.txt`

**مهم:** استشر هذه الوثائق دائماً لسلوك Word XML قبل تنفيذ الميزات.

---

## Headers & Footers System | نظام الهيدر والفوتر

### Header Types | أنواع الهيدر

| Type | Attribute | Usage (EN) | الاستخدام (ع) |
|------|-----------|------------|---------------|
| First | `w:type="first"` | First page of section when `titlePg` enabled | الصفحة الأولى من القسم عند تفعيل `titlePg` |
| Default/Odd | `w:type="default"` | All pages (or odd pages if `evenAndOddHeaders`) | جميع الصفحات (أو الفردية إذا `evenAndOddHeaders`) |
| Even | `w:type="even"` | Even pages when `evenAndOddHeaders` enabled | الصفحات الزوجية عند تفعيل `evenAndOddHeaders` |

### Header Inheritance Rules (Per Word XML Spec) | قواعد وراثة الهيدر

**Reference:** Lines 32677-32699 in `extracted_reference.txt`

1. **First Page Header** (`titlePg` enabled):
   - If `headerFirst` exists → use it
   - If not → **inherit from previous section**
   - If first section → **create blank header**
   - **Do NOT fallback to default/odd header**

2. **Even Page Header** (`evenAndOddHeaders` enabled):
   - If `headerEven` exists → use it
   - If not → **inherit from previous section**
   - If first section → **create blank header**

3. **Odd/Default Page Header**:
   - If `headerOdd` or `headerDefault` exists → use it
   - If not → **inherit from previous section**
   - If first section → **create blank header**

**الملخص:** الوراثة من القسم السابق، وليس fallback لنوع آخر من الهيدر!

---

## Page Numbering System | نظام ترقيم الصفحات

### Key Properties | الخصائص الرئيسية

- `w:pgNumType` in `sectPr`:
  - `w:start`: Starting page number for section
  - `w:fmt`: Number format (decimal, roman, etc.)

### Continuation vs Reset | الاستمرار مقابل إعادة الترقيم

**Per Word XML Spec (Lines 17622-17626):**

- If `w:start` is **specified** → numbering starts from that value
- If `w:start` is **omitted** → numbering continues from where previous section ended

**Code Implementation:**
```dart
// In SectPr.calculatePageNumber()
if (pgNumStart != null) {
  start = pgNumStart!;
} else {
  // Continue from previous section
  int prevLastPageNum = prevSectPr._calculateLastPageNumber();
  start = prevLastPageNum + 1;
}
```

---

## Section Range Management | إدارة نطاقات الأقسام

### Problem Identified | المشكلة المكتشفة

Sections were getting `firstRange > lastRange` (e.g., `firstRange=1, lastRange=0`), making them invalid.

### Solution | الحل

1. **During Parsing** (`WordDocument.addSectPr()`):
   - Set `firstRange` and `lastRange` = current page number

2. **Post-Processing** (`AddDocData.dart`):
   - Recalculate `firstRange` for each section = previous section's `lastRange + 1`
   - First section always starts at page 0
   - Last section's `lastRange` = total pages - 1

---

## Z-Order / Layering System | نظام ترتيب الطبقات

### Image Layering Properties | خصائص طبقات الصور

| Property | Value | Behavior (EN) | السلوك (ع) |
|----------|-------|---------------|------------|
| `behindDoc` | `true` / `1` | Image behind text | الصورة خلف النص |
| `behindDoc` | `false` / `0` | Image in front of text | الصورة أمام النص |
| `relativeHeight` | Integer | Z-order within same `behindDoc` group | ترتيب Z داخل نفس مجموعة `behindDoc` |

### Stack Order in WordPageScreen | ترتيب الـ Stack في شاشة الصفحة

```
1. Background Images (behindDoc=true)     ← Bottom/الأسفل
2. Header
3. Content + Footnotes
4. Footer
5. Foreground Images (behindDoc=false)    ← Top/الأعلى
```

**Implementation:**
- `WordPage.getBackgroundImages()` - returns images with `behindDoc=true`
- `WordPage.getForegroundImages()` - returns images with `behindDoc=false`

---

## TextBox Page Number Replacement | استبدال رقم الصفحة في مربع النص

### Problem | المشكلة

Page numbers in headers are often inside TextBoxes. The TextBox stores a static value (e.g., "38") from when the Word file was saved.

### Solution | الحل

1. **Detection** (`ImageParser.parseTextBox()`):
   - Check for `w:fldSimple` with `PAGE` instruction
   - Check for `w:instrText` containing `PAGE`
   - Set `ImageData.containsPageField = true`

2. **Replacement** (`Paragraph._getPositionedImages()`):
   - If `containsPageField == true` and `customPageNumber` is available
   - Replace TextBox text with actual page number

---

## Files Modified in Recent Sessions | الملفات المعدلة في الجلسات الأخيرة

### Core Logic Files

| File | Changes |
|------|---------|
| `lib/wordToHTML/SectPr.dart` | Header inheritance, page number calculation, footer logic |
| `lib/Models/WordDocument.dart` | Section range management, `addSectPr()` with page number |
| `lib/wordToHTML/AddDocData.dart` | Section range recalculation post-parsing |
| `lib/Models/WordPage.dart` | Background/foreground image separation |
| `lib/UI/WordPageScreen.dart` | Z-order layering for images, headers, content |
| `lib/Utils/ImageParser.dart` | `containsPageField` detection for TextBoxes |
| `lib/wordToHTML/Paragraph.dart` | TextBox page number replacement |

---

## Debugging Tips | نصائح التصحيح

### Console Logs to Look For | رسائل الـ Console المهمة

| Prefix | Purpose |
|--------|---------|
| `📄 SECTION DEBUG` | Section info for current page |
| `📄 HEADER` | Header selection rule applied |
| `📄 PAGE NUM CALC` | Page number calculation details |
| `🔍 FINDING SECTION` | Section lookup for a page |
| `📋 SECTION ADDED` | New section added during parsing |
| `🔢 TextBox PAGE replaced` | Page number replaced in TextBox |
| `→ Inherited` | Header inherited from previous section |

### Common Issues | المشاكل الشائعة

1. **Page numbers skipping**: Check section ranges and `pgNumStart`
2. **Wrong header showing**: Check `titlePg`, `evenAndOddHeaders` settings and inheritance
3. **Images covering content unexpectedly**: Check `behindDoc` attribute
4. **Header not showing**: Check if header path is `null` or inheritance failed

---

## Best Practices | أفضل الممارسات

1. **Always consult Word XML documentation** before implementing Word-related features
2. **Use debug logging** extensively when troubleshooting
3. **Test with multiple document types** - different Word versions may have variations
4. **Section boundaries are critical** - many features depend on correct section ranges
5. **Header/footer inheritance is complex** - follow Word spec exactly, don't make assumptions

---

## Future Considerations | اعتبارات مستقبلية

1. **Footer inheritance**: Apply same inheritance logic as headers
2. **Cache invalidation**: Consider caching parsed headers/footers per section
3. **Performance**: Large documents may need lazy loading optimization
4. **RTL optimization**: Further improvements for Arabic text rendering

---

*Last Updated: 2024-12-18*
*آخر تحديث: 2024-12-18*
