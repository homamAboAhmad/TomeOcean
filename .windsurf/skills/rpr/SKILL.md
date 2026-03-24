---
name: rpr
description: مهارة التعامل مع خصائص الـ Run (w:rPr) - Run Properties in Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود خصائص الـ Run، تأكد من:**
1. أن التعديل لا يكسر عرض النص العربي (szCs, bCs, iCs, cs font)
2. أن التعديل لا يؤثر على حل ألوان الثيم (themeColor + tint/shade)
3. أن التعديل لا يكسر Toggle Properties (العكس عند الوراثة)
4. أن التعديل لا يؤثر سلباً على rPr في سياقات أخرى (جداول، هيدر، فوتر، حواشي، ترقيم)
5. أن اختيار الخط حسب Unicode range لا يتأثر
6. اختبر مع عدة كتب عربية ولاتينية ومختلطة

# 🔗 المهارات المرتبطة
- **runs.md** → الـ Run الذي يحتوي rPr
- **paragraphs.md** → الفقرة الأم
- **ppr.md** → rPr داخل pPr (تنسيق علامة الفقرة)
- **styles.md** → rStyle ووراثة الأنماط
- **fonts-theme.md** → حل الخطوط من الثيم وألوان الثيم
- **tables.md** → التنسيق الشرطي قد يؤثر على rPr

## دروس عملية من rPr في مسار رقم الصفحة

### 1. `rPr` الخاص بنتيجة حقل `PAGE` قد يختلف عن `rPr` الخاص بتعليمات الحقل نفسها
- افحص run النتيجة الفعلية (`w:t`) لا run `w:instrText` فقط
- قد يكون الخلل في تنسيق النتيجة المعروضة لا في الحقل كتعليمة

### 2. `w:spacing` على مستوى run قد يكون مهماً فعلاً
- في بعض الهيدرات/الفوترات العربية يظهر `w:spacing` داخل `w:rPr` الخاص بالرقم نفسه
- لا تثبّت `letterSpacing: 0` قبل التأكد من هذا العنصر
- لكن لا تحوّله إلى قاعدة عامة إلا بعد مقارنة بمرجع Word وسلوك كتب أخرى

### 3. لا تخلط بين مشكلة شكل الحرف ومشكلة موضعه
- `rPr` قد يفسر:
  - الخط
  - الحجم
  - اللون
  - التباعد الأفقي
- لكنه لا يفسر وحده كل انزياح رأسي؛ عندها يجب الرجوع أيضاً إلى `pPr` و line metrics

# مرجع: ECMA-376 §17.3.2.28 - Run Properties (rPr)

## البنية الأساسية
```xml
<w:rPr>
  <w:rStyle w:val="Strong"/>
  <w:rFonts w:ascii="Arial" w:cs="Traditional Arabic"/>
  <w:b/> <w:bCs/>  <w:i/> <w:iCs/>
  <w:sz w:val="24"/> <w:szCs w:val="28"/>
  <w:color w:val="FF0000"/>
  <w:u w:val="single"/>
  <w:rtl/>
</w:rPr>
```

## جميع عناصر rPr المؤثرة على العرض

### 1. الخطوط - w:rFonts (§17.3.2.26)
- ascii (U+0000-007F), hAnsi, cs (عربي/عبري), eastAsia
- asciiTheme, hAnsiTheme, cstheme, eastAsiaTheme, hint

### 2. أحجام الخط
- **w:sz** - لاتيني بـ half-points (24=12pt)
- **w:szCs** - عربي بـ half-points (**مهم للعربية**)

### 3. الغامق والمائل (Toggle)
- **w:b**/w:bCs, **w:i**/w:iCs
- Toggle: نمط=true + مباشر=true → false

### 4. اللون - w:color (§17.3.2.6)
- val (hex/auto), themeColor, themeTint, themeShade
- أسماء بديلة: background1→light1, text1→dark1

### 5. التسطير - w:u (§17.3.2.40)
- val: single, double, thick, dotted, dash, wave, words, none, ...

### 6. الشطب - w:strike (مفرد) / w:dstrike (مزدوج)

### 7. التظليل
- **w:highlight** - ألوان محددة فقط
- **w:shd** - ألوان RGB مخصصة

### 8. الموقع والحجم
- w:position (half-points), w:vertAlign, w:w (نسبة مئوية), w:kern, w:fitText

### 9. تأثيرات بصرية (Toggle)
- caps, smallCaps, outline, shadow, emboss, imprint, vanish, em

### 10. الحدود - w:bdr, الاتجاه - w:rtl/w:cs, اللغة - w:lang

### 11. النمط - w:rStyle

## تسلسل أولوية التنسيق
1. التنسيق المباشر ← الأعلى
2. نمط الحرف (rStyle)
3. تنسيق علامة الفقرة (pPr/rPr)
4. النمط المرتبط بنمط الفقرة
5. سلسلة basedOn
6. الافتراضيات (docDefaults/rPrDefault) ← الأدنى

## ملفات المشروع المرتبطة
- `lib/wordToHTML/RPr.dart` - الموديل الرئيسي
- `lib/wordToHTML/runT.dart` - الـ Run
- `lib/wordToHTML/DocTheme.dart` - ألوان الثيم

## خطوات التحقق
1. szCs للعربي وليس sz
2. bCs/iCs للعربي
3. ألوان الثيم مع tint/shade
4. Toggle properties مع الوراثة
5. الخط الصحيح حسب Unicode range
6. "auto" color
7. عند PAGE field: افحص `rPr` لنتيجة الرقم نفسها لا تعليمات الحقل فقط
8. **تأكد أن التعديل لا يؤثر سلباً على rPr في أي سياق آخر**
