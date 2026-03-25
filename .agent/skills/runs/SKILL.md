---
name: runs
description: مهارة التعامل مع الـ Run (w:r) - Text Run handling in Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الـ Runs، تأكد من:**
1. أن التعديل لا يؤثر على عرض النص في الفقرات العادية والجداول والهيدر/الفوتر والحواشي
2. أن التعديل لا يسبب تكرار النص (bug سابق معروف مع search highlighting)
3. أن التعديل لا يكسر التنسيق العربي (Complex Script: bCs, iCs, szCs)
4. أن التعديل لا يؤثر على اختيار الخطوط للنصوص المختلطة (عربي + لاتيني)
5. اختبر مع عدة كتب مختلفة وليس كتاباً واحداً فقط

# 🔗 المهارات المرتبطة
الـ Run هو وحدة النص المنسق، لذا عند التعامل معه ستحتاج:
- **rpr.md** → خصائص الـ Run (الخط، اللون، الغامق، إلخ) - تُستخدم دائماً
- **paragraphs.md** → الفقرة الأم التي تحتوي الـ Run
- **ppr.md** → خصائص الفقرة قد تؤثر على الـ Run (مثل rPr في pPr)
- **images.md** → إذا الـ Run يحتوي صورة (w:drawing)
- **fields-hyperlinks.md** → إذا الـ Run يحتوي حقل (fldChar/instrText)
- **footnotes-endnotes.md** → إذا الـ Run يحتوي مرجع حاشية (footnoteReference)
- **styles.md** → لحساب التنسيق النهائي عبر تسلسل الأولوية
- **fonts-theme.md** → لحل الخطوط وألوان الثيم

# مرجع: ECMA-376 §17.3.2 - Run

## البنية الأساسية للـ Run (w:r)
```xml
<w:r>
  <w:rPr>            <!-- خصائص الـ Run (اختياري) -->
    <w:b/>
    <w:sz w:val="24"/>
  </w:rPr>
  <w:t xml:space="preserve">النص هنا</w:t>
</w:r>
```

## العناصر الأبناء المحتملة للـ Run

### خصائص الـ Run
- **w:rPr** - خصائص التنسيق (يجب أن يكون العنصر الأول إن وُجد)

### محتوى الـ Run (Run Content) - §17.3.3
1. **w:t** - نص عادي (`xml:space="preserve"` ضرورية للحفاظ على المسافات)
2. **w:br** - فاصل (page, column, textWrapping)
3. **w:tab** - حرف تبويب
4. **w:cr** - إرجاع (يعمل كفاصل سطر)
5. **w:sym** - حرف رمز (font + char code)
6. **w:drawing** - كائن DrawingML (صور وأشكال)
7. **w:object** - كائن مضمّن (OLE)
8. **w:pict** - صورة VML (legacy)
9. **w:fldChar** - حرف حقل معقد (begin/separate/end)
10. **w:instrText** - كود الحقل
11. **w:ruby** - نص فونيتيك
12. **w:softHyphen** - واصلة اختيارية
13. **w:noBreakHyphen** - واصلة غير قابلة للكسر
14. **w:lastRenderedPageBreak** - موقع آخر فاصل صفحة محسوب
15. **w:pgNum** - رقم الصفحة
16. **w:delText** - نص محذوف (تتبع تغييرات)
17. **w:ptab** - تبويب مطلق الموقع

## ملفات المشروع المرتبطة
- `lib/wordToHTML/runT.dart` - الموديل الرئيسي للـ Run
- `lib/wordToHTML/RPr.dart` - خصائص الـ Run
- `lib/wordToHTML/HyperLinkRun.dart` - Run داخل hyperlink
- `lib/wordToHTML/Paragraph.dart` - الفقرة الأم

## قواعد حاسمة

### 1. المسافات البيضاء - حرج جداً
- `w:t` بدون `xml:space="preserve"` → المسافات تُقَص
- `w:t` مع `xml:space="preserve"` → المسافات تُحفظ

### 2. تسلسل أولوية التنسيق (Style Hierarchy)
1. التنسيق المباشر (`w:r/w:rPr`) ← الأعلى
2. نمط الحرف (`w:rStyle`)
3. تنسيق علامة الفقرة (`w:pPr/w:rPr`)
4. نمط الفقرة المرتبط (`w:pStyle` → linked character style)
5. الافتراضيات (`w:docDefaults/w:rPrDefault`) ← الأدنى

### 3. Complex Script (مهم للعربية)
- `w:bCs`, `w:iCs`, `w:szCs` → للنص العربي
- `w:b`, `w:i`, `w:sz` → للنص اللاتيني
- `w:rtl` يحدد اتجاه RTL ويُفعّل Complex Script

### 4. Toggle Properties
- b, bCs, i, iCs, caps, smallCaps, strike, dstrike, outline, shadow, emboss, imprint, vanish
- قاعدة: نمط=true + مباشر=true → النتيجة=false (عكس)

### 5. عدم تكرار النص
- **bug سابق معروف**: احذر من إضافة النص مرتين عند search highlighting

### 6. الحقول المعقدة
- بين begin و separate → كود (لا يُعرض)
- بين separate و end → نتيجة (هذا ما يُعرض)

## خطوات التحقق
1. تأكد أن المسافات البيضاء تُعرض بشكل صحيح
2. تأكد أن Complex Script يعمل للنص العربي
3. تأكد أن الفواصل (breaks) تعمل
4. تأكد أن النص لا يتكرر
5. تأكد أن الرموز (w:sym) والحقول المعقدة تعمل
6. اختبر مع كتب عربية ولاتينية ومختلطة
7. **تأكد أن التعديل لا يؤثر سلباً على الـ runs في الجداول/الهيدر/الفوتر/الحواشي**
