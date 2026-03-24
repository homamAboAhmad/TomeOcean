---
name: sections
description: مهارة التعامل مع الأقسام (w:sectPr) - Sections in Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الأقسام، تأكد من:**
1. أن التعديل لا يكسر حساب حجم الصفحة والهوامش
2. أن التعديل لا يؤثر على وراثة الهيدر/الفوتر بين الأقسام
3. أن التعديل لا يكسر ترقيم الصفحات عبر الأقسام
4. أن التعديل لا يؤثر على الأقسام landscape vs portrait
5. اختبر مع كتب لها أقسام متعددة بإعدادات مختلفة

# 🔗 المهارات المرتبطة
- **headers.md** + **footers.md** → headerReference/footerReference في sectPr
- **paragraphs.md** → sectPr يكون داخل آخر فقرة في القسم
- **ppr.md** → docGrid يؤثر على snapToGrid في الفقرات
- **numbering.md** → ترقيم الصفحات (pgNumType)
- **fields-hyperlinks.md** → حقل PAGE يعتمد على pgNumType
- **tables.md** → عرض الجدول يتأثر بعرض الصفحة والهوامش

# مرجع: ECMA-376 §17.6 - Sections

## موقع sectPr
- **القسم الأخير**: ابن مباشر لـ w:body
- **أقسام أخرى**: داخل w:pPr لآخر فقرة في القسم

## العناصر الرئيسية
1. **pgSz** (§17.6.13) - w, h, orient (portrait/landscape), code
2. **pgMar** (§17.6.11) - top, bottom, left, right, header, footer, gutter
3. **pgBorders** (§17.6.10) - حدود الصفحة (top/left/bottom/right)
4. **cols** (§17.6.4) - أعمدة (num, space, equalWidth, sep)
5. **docGrid** (§17.6.5) - شبكة المستند (type, linePitch, charSpace)
6. **pgNumType** (§17.6.12) - fmt, start, chapSep, chapStyle
7. **type** (§17.6.22) - فاصل القسم: nextPage, continuous, evenPage, oddPage
8. **headerReference** / **footerReference** - أنواع: default, first, even
9. **titlePg** (§17.6.21) - تفعيل first header/footer
10. **bidi** (§17.6.1) - RTL section layout
11. **lnNumType** (§17.6.8) - ترقيم الأسطر
12. **rtlGutter** (§17.6.16) - gutter على اليمين
13. **vAlign** - محاذاة عمودية (top, center, both, bottom)

## أحجام شائعة (twips)
- A4: 11906×16838 | Letter: 12240×15840

## ملفات المشروع المرتبطة
- `lib/wordToHTML/SectPr.dart`
- `lib/Models/WordDocument.dart`, `lib/Models/WordPage.dart`
- `lib/Utils/PageNumberHelper.dart`

## خطوات التحقق
1. حجم الصفحة (خاصة landscape)
2. الهوامش (top, bottom, left, right, header, footer)
3. فواصل الأقسام
4. الأعمدة
5. ترقيم الصفحات (fmt, start)
6. وراثة الهيدر/الفوتر
7. titlePg و RTL
8. **تأكد أن التعديل لا يؤثر سلباً على الأقسام الأخرى في نفس المستند**
