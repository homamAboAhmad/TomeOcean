---
name: footnotes-endnotes
description: مهارة التعامل مع الحواشي السفلية والختامية (Footnotes & Endnotes) في Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الحواشي، تأكد من:**
1. أن التعديل لا يكسر ترقيم الحواشي (numFmt + numStart + numRestart)
2. أن التعديل لا يؤثر على عرض رقم الحاشية كـ superscript في النص الرئيسي
3. أن التعديل لا يؤثر سلباً على الفقرات والـ runs داخل الحاشية
4. أن التعديل لا يكسر الفاصل (separator) بين النص والحواشي
5. الحواشي شائعة جداً في الكتب الإسلامية - أي خطأ يؤثر على آلاف الكتب

# 🔗 المهارات المرتبطة (الحاشية تحتوي محتوى كامل!)
- **paragraphs.md** + **runs.md** + **rpr.md** + **ppr.md** → محتوى الحاشية فقرات كاملة
- **images.md** → صور داخل الحاشية (نادر لكن ممكن)
- **tables.md** → جداول داخل الحاشية (نادر لكن ممكن)
- **fields-hyperlinks.md** → روابط داخل الحاشية
- **styles.md** → نمط FootnoteText / FootnoteReference
- **sections.md** → footnotePr / endnotePr في sectPr

# مرجع: ECMA-376 §17.11

## البنية
- **في النص**: `<w:footnoteReference w:id="1"/>` (مع rStyle superscript)
- **في footnotes.xml**: `<w:footnote w:id="1"><w:p>...</w:p></w:footnote>`
- أنواع خاصة: separator (id=-1), continuationSeparator (id=0)

## خصائص في sectPr
- pos: pageBottom / beneathText
- numFmt: decimal, arabicAbjad, hindiNumbers, chicago, ...
- numRestart: continuous, eachSect, eachPage
- numStart

## ملفات المشروع المرتبطة
- `lib/wordToHTML/DocFootNotes.dart`
- `lib/wordToHTML/FootNote.dart`
- `lib/wordToHTML/runT.dart`

## خطوات التحقق
1. رقم الحاشية superscript في النص الرئيسي
2. محتوى الحاشية يُعرض في أسفل الصفحة
3. الترقيم صحيح (numFmt, numStart, numRestart)
4. الفاصل (separator) يظهر
5. RTL يعمل
6. **تأكد أن التعديل لا يؤثر سلباً على محتوى الحاشية (فقرات/صور/جداول)**
