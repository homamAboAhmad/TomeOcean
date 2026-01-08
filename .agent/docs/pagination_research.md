# Word Open XML Pagination & Page Division Research / بحث حول تقسيم الصفحات في ملفات الوورد
*Confidential & Proprietary - Research Notes*

## 1. Introduction / مقدمة
This document summarizes research into how Microsoft Word and the Open XML standard handle pagination, specifically regarding programmatic page division.
يلخص هذا المستند البحث حول كيفية تعامل Microsoft Word ومعيار Open XML مع تقسيم الصفحات، وتحديداً كيفية تحديد فواصل الصفحات برمجياً.

## 2. Core Concept: Flow Document / المفهوم الأساسي: وثيقة متدفقة
Word is a **Flow Document** format. It does not store "pages" natively. Pages are calculated at runtime by the rendering engine.
ملفات الوورد هي وثائق "متدفقة". لا يتم تخزين "الصفحات" بشكل أصلي، بل يتم حسابها وقت العرض.

## 3. `w:lastRenderedPageBreak` - The Key to Splitting / مفتاح تقسيم الفقرات
This is the most critical element for our goal.
هذا هو العنصر الأهم لهدفنا.

*   **Definition:** An informational tag inserted by Word when it saves.
    **التعريف:** وسم معلوماتي يضيفه الوورد عند الحفظ.
*   **Behavior:** It appears *inside* a paragraph (specifically inside a `w:r` run) exactly where the line split to the next page.
    **السلوك:** يظهر *داخل* الفقرة (تحديداً داخل `w:r`) في المكان الذي انتقل فيه النص للصفحة التالية.
*   **Reliability:** It reflects the pagination *at the time of the last save*. If we trust how the document was saved, we can use it.
    **الموثوقية:** يعكس تقسيم الصفحات *وقت آخر حفظ*.

### Splitting Algorithm / خوارزمية تقسيم الفقرة
To split a paragraph that spans two pages:
لتقسيم فقرة تمتد على صفحتين:
1.  Iterate through `w:r` (runs) in the paragraph.
2.  Find `<w:lastRenderedPageBreak/>`.
3.  Split the paragraph into two:
    *   **Part 1:** All runs *before* the break (assigned Page X).
    *   **Part 2:** All runs *after* the break (assigned Page X+1).

## 4. Python Solution Strategy / استراتيجية الحل بالبايثون
Since `python-docx` does not calculate pages, we have two paths:
بما أن `python-docx` لا تحسب الصفحات، لدينا مساران:

### A. The "Scan & Inject" Method (Recommended) / طريقة الفحص والحقن (موصى بها)
Use `pageRender.py` to:
1.  Force Word (via COM automation) to repaginate: `doc.Repaginate()`.
2.  Iterate through paragraphs.
3.  Inject a custom property `w:pageNum="X"` into `w:pPr`.
4.  **Handle Splits:** If `lastRenderedPageBreak` is found, strictly split the XML element into two paragraphs.

### B. External Libraries / مكتبات خارجية
*   **Aspose.Words**: Can calculate pages accurately but is commercial/complex.
*   **Spire.Doc**: Similar to Aspose.

## 5. Conclusion / الخاتمة
The best approach is to use the existing COM automation in `pageRender.py` to ensure `lastRenderedPageBreak` tags are fresh (via `Repaginate`), then scan XML to inject numbers.
أفضل نهج هو استخدام الأتمتة الموجودة لضمان تحديث وسوم الفواصل، ثم فحص الـ XML لحقن الأرقام.
