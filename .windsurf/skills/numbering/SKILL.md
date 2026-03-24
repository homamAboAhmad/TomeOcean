---
name: numbering
description: مهارة التعامل مع الترقيم (Numbering) في Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الترقيم، تأكد من:**
1. أن التعديل لا يكسر عداد الترقيم عبر الفقرات المتتالية
2. أن التعديل لا يسبب إعادة بدء خاطئة للترقيم عند تقسيم الصفحات
3. أن التعديل لا يؤثر على الترقيم في الجداول
4. أن التعديل لا يكسر bullet lists أو ترقيم متعدد المستويات
5. أن numId=0 (إلغاء الترقيم) لا يتأثر
6. اختبر مع كتب تحتوي ترقيم متنوع

# 🔗 المهارات المرتبطة
- **ppr.md** → w:numPr (ilvl + numId) في خصائص الفقرة
- **paragraphs.md** → الفقرة المرقمة
- **styles.md** → الأنماط قد تحتوي numPr ضمنياً (مثل Heading1)
- **rpr.md** → تنسيق الرقم/الرمز (rPr في lvl)
- **fonts-theme.md** → خط الرمز (Symbol, Wingdings) في bullet lists
- **tables.md** → الترقيم داخل الجداول (قيد معروف: إعادة بدء)

# مرجع: ECMA-376 §17.9 - Numbering

## ثلاث طبقات
1. **abstractNum** (numbering.xml) - التعريف المجرد مع المستويات (lvl 0-8)
2. **num** (numbering.xml) - مثيل يُحيل إلى abstractNum + overrides
3. **الفقرة** (document.xml) - numPr (ilvl + numId)

## خصائص المستوى (lvl)
- **start** - رقم البدء
- **numFmt** - التنسيق: decimal, arabicAlpha, arabicAbjad, bullet, upperRoman, lowerRoman, hindiNumbers, none, ...
- **lvlText** - نمط العرض: "%1." أو "%1.%2." أو رمز bullet
- **lvlJc** - محاذاة الرقم: left/center/right
- **pPr/ind** - إزاحة الفقرة (left + hanging)
- **rPr** - تنسيق الرقم (خط، لون، حجم)
- **suff** - ما بعد الرقم: tab (افتراضي), space, nothing
- **lvlRestart** - إعادة بدء عند تغير مستوى أعلى
- **isLgl** - ترقيم قانوني

## ملفات المشروع المرتبطة
- `lib/wordToHTML/Num.dart` + `lib/wordToHTML/abstractNum.dart`
- `lib/wordToHTML/DocNumbering.dart`
- `lib/wordToHTML/PPr.dart` (numId, ilvl)
- `lib/Utils/DiplayWordNumber.dart`

## قيود معروفة
- **الترقيم قد يُعاد بدؤه لكل صفحة** بسبب نظام التقسيم إلى صفحات

## خطوات التحقق
1. العداد يزداد بشكل صحيح
2. إعادة البدء (restart) مع المستويات
3. numFmt الصحيح (خاصة العربي)
4. lvlText مع %1, %2
5. الإزاحة (hanging indent)
6. bullet lists بالرمز والخط الصحيح
7. lvlOverride و startOverride
8. numId=0 يلغي الترقيم الموروث
9. **تأكد أن التعديل لا يؤثر سلباً على الترقيم في الجداول أو عند تقسيم الصفحات**
