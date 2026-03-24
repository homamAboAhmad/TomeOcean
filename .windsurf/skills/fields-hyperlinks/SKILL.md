---
name: fields-hyperlinks
description: مهارة التعامل مع الحقول والروابط التشعبية (Fields & Hyperlinks) في Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الحقول والروابط، تأكد من:**
1. أن التعديل لا يعرض كود الحقل بدلاً من النتيجة (بين begin و separate لا يُعرض!)
2. أن التعديل لا يكسر الروابط التشعبية (r:id → relationship → URL)
3. أن التعديل لا يؤثر على جدول المحتويات (TOC)
4. أن التعديل لا يؤثر سلباً على الحقول في الهيدر/الفوتر (PAGE, NUMPAGES)
5. اختبر مع كتب تحتوي حقول وروابط متنوعة

# 🔗 المهارات المرتبطة
- **runs.md** → الحقول والروابط تكون داخل runs (fldChar, instrText)
- **rpr.md** → تنسيق نص الرابط (عادة أزرق + تسطير)
- **paragraphs.md** → w:hyperlink عنصر ابن للفقرة
- **headers.md** / **footers.md** → حقول PAGE/NUMPAGES شائعة جداً
- **toc-indexes.md** → جدول المحتويات يعتمد على حقل TOC
- **sections.md** → pgNumType يؤثر على حقل PAGE

# مرجع: ECMA-376 §17.16

## أنواع الحقول
1. **البسيطة** - `<w:fldSimple w:instr=" PAGE "><w:r><w:t>5</w:t></w:r></w:fldSimple>`
2. **المعقدة** - fldChar begin → instrText → fldChar separate → نتيجة → fldChar end

## الروابط التشعبية
```xml
<w:hyperlink r:id="rId5" w:tooltip="...">
  <w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>نص</w:t></w:r>
</w:hyperlink>
```
- r:id → URL في document.xml.rels
- w:anchor → إشارة مرجعية داخلية

## حقول شائعة
- PAGE, NUMPAGES, SECTIONPAGES, PAGEREF, REF, TOC, SEQ, HYPERLINK, DATE, AUTHOR

## ملفات المشروع المرتبطة
- `lib/wordToHTML/HyperLinkRun.dart`
- `lib/wordToHTML/ParagraphHyperLink.dart`
- `lib/wordToHTML/runT.dart`
- `lib/wordToHTML/DocRelations.dart`

## خطوات التحقق
1. الحقول المعقدة تعرض النتيجة فقط
2. الروابط تعمل (r:id و anchor)
3. حقل PAGE صحيح
4. TOC يُعرض بشكل صحيح
5. **تأكد أن التعديل لا يؤثر سلباً على الحقول في الهيدر/الفوتر**
