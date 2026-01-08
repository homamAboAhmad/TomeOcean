# Word Open XML Page Numbering Details / تفاصيل ترقيم الصفحات في Word Open XML

This document provides a detailed reference for handling page numbering within `.docx` files.
يوفر هذا المستند مرجعاً تفصيلياً للتعامل مع ترقيم الصفحات داخل ملفات `.docx`.

---

## 1. The Data Model: Section Properties (`w:sectPr`) / نموذج البيانات: خصائص القسم

Page numbering is **not** global; it is scoped to **Sections**. Each section can have its own numbering scheme.
ترقيم الصفحات **ليس** عاماً؛ فهو محدد بنطاق **الأقسام (Sections)**. يمكن لكل قسم أن يكون له نظام ترقيم خاص به.

The core element is `<w:pgNumType>`, which resides inside `<w:sectPr>`.
العنصر الأساسي هو `<w:pgNumType>`، والذي يوجد داخل `<w:sectPr>`.

### Structure / الهيكلية
```xml
<w:document ...>
  <w:body>
    <!-- Content of Section 1 / محتوى القسم الأول -->
    <w:p>...</w:p>
    
    <!-- Section Break defining Section 1's properties / فاصل مقطعي يحدد خصائص القسم الأول -->
    <w:p>
      <w:pPr>
        <w:sectPr>
           <!-- Page numbering for Section 1 / ترقيم الصفحات للقسم الأول -->
           <w:pgNumType w:start="1" w:fmt="lowerRoman"/> 
        </w:sectPr>
      </w:pPr>
    </w:p>

    <!-- Content of Section 2 / محتوى القسم الثاني -->
    <w:p>...</w:p>

    <!-- Final Section properties / خصائص القسم الأخير -->
    <w:sectPr>
       <!-- Page numbering for Section 2 / ترقيم الصفحات للقسم الثاني -->
       <w:pgNumType w:fmt="decimal"/> <!-- No start means convert from previous / عدم وجود بداية يعني الاستمرار من السابق -->
    </w:sectPr>
  </w:body>
</w:document>
```

### `<w:pgNumType>` Attributes / خصائص العنصر

| Attribute / الخاصية | Description / الوصف |
| :--- | :--- |
| **`w:fmt`** | **Number Format / تنسيق الرقم**<br>Common values: `decimal` (1, 2, 3), `lowerRoman` (i, ii, iii), `upperLetter` (A, B, C), `cardinalText` (One, Two).<br>القيم الشائعة: أرقام، أرقام رومانية، أحرف، نصوص. |
| **`w:start`** | **Start Value / قيمة البدء**<br>The integer value to start numbering at for this section. **If omitted, numbering continues** from the previous section.<br>القيمة الرقمية لبدء الترقيم في هذا القسم. **إذا حذفت، يستمر الترقيم** من القسم السابق. |
| **`w:chapStyle`** | **Chapter Style / نمط الفصل**<br>The style index to include in chapter numbering (e.g., "1-1").<br>فهرس النمط لتضمينه في ترقيم الفصول (مثل "1-1"). |
| **`w:chapSep`** | **Separator / الفاصل**<br>Separator between chapter and page number (e.g., `hyphen`, `colon`).<br>الفاصل بين رقم الفصل ورقم الصفحة. |

---

## 2. The Render Model: Fields / نموذج العرض: الحقول

The XML does not store "Page 1" text directly. It stores a `PAGE` field instruction.
ملف XML لا يخزن النص "الصفحة 1" مباشرة. بل يخزن تعليمة حقل `PAGE`.

### The `PAGE` Field / حقل الصفحة
Instructs the engine to calculate the page number.
يوجه المحرك لحساب رقم الصفحة.

#### Simple Field (`w:fldSimple`) / الحقل البسيط
```xml
<w:fldSimple w:instr="PAGE">
  <w:r>
    <w:t>3</w:t> <!-- Cached value / القيمة المخزنة مؤقتاً -->
  </w:r>
</w:fldSimple>
```

#### Complex Field (`w:fldChar`) / الحقل المعقد
Used for formatting switches.
يستخدم لمفاتيح التنسيق المعقدة.

```xml
<w:r><w:fldChar w:fldCharType="begin"/></w:r>
<w:r><w:instrText> PAGE \* MERGEFORMAT </w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>
<w:r><w:t>3</w:t></w:r>
<w:r><w:fldChar w:fldCharType="end"/></w:r>
```

---

## 3. Implementation Logic / منطق التنفيذ

To correctly calculate the page number:
لحساب رقم الصفحة بشكل صحيح:

1.  **Traverse Sections:** Iterate through the document's sections.
    **تتبع الأقسام:** مر على أقسام المستند بالترتيب.
2.  **Track Global Counter:** Keep a counter.
    **تتبع العداد العام:** احتفظ بعداد للصفحات.
3.  **Handle `w:sectPr`:**
    **عالج خصائص القسم:**
    *   **Restart?** If `w:start` exists, reset counter to it.
        **إعادة تعيين؟** إذا وجدت `w:start`، أعد تعيين العداد إليها.
    *   **Continue?** If not, continue from previous + 1.
        **استمرار؟** إذا لم توجد، استمر من السابق + 1.
4.  **Formatting:** Convert integer to format (e.g., `1` -> `i`) during display.
    **التنسيق:** حول الرقم إلى التنسيق المطلوب (مثلاً `1` -> `i`) عند العرض.
