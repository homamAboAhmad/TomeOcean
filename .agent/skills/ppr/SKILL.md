---
name: ppr
description: مهارة التعامل مع خصائص الفقرة (w:pPr) - Paragraph Properties in Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود خصائص الفقرة، تأكد من:**
1. أن التعديل لا يكسر المحاذاة في الفقرات RTL و LTR
2. أن التعديل لا يؤثر على التباعد بين الفقرات في كتب أخرى
3. أن التعديل لا يكسر الإزاحة (ind) خاصة مع bidi والترقيم
4. أن التعديل لا يؤثر سلباً على الفقرات داخل الجداول أو الهيدر/الفوتر أو الحواشي
5. أن وراثة الأنماط (style hierarchy) لا تتأثر سلباً
6. اختبر مع عدة كتب مختلفة وليس كتاباً واحداً فقط

# 🔗 المهارات المرتبطة
- **paragraphs.md** → الفقرة الأم التي تحتوي pPr
- **rpr.md** → w:rPr داخل pPr (تنسيق علامة الفقرة)
- **numbering.md** → w:numPr (ترقيم الفقرة)
- **styles.md** → w:pStyle ووراثة الأنماط وdocDefaults
- **tables.md** → cnfStyle (التنسيق الشرطي داخل الجداول)
- **sections.md** → docGrid وتأثير القسم على الفقرة
- **fonts-theme.md** → ألوان الثيم في التظليل والحدود

## دروس عملية من pPr في مشاكل الهيدر/رقم الصفحة

### 1. عند انزياح رقم الصفحة لا تبدأ من الحقل قبل فحص `pPr`
- إذا كانت قيمة الرقم صحيحة لكن موضعه خاطئ، فقد يكون السبب في:
  - `w:jc`
  - `w:tabs`
  - `w:spacing`
  - `w:ind`
- هذه الخصائص قد تغير موضع الرقم حتى مع صحة النص المستبدل

### 2. `w:spacing` على مستوى الفقرة وارتفاع السطر يجب التعامل معهما بحذر شديد في العربية
- أي correction factor عام قد يكون مناسباً للنص العادي لكنه لا يلزم أن يطابق الهيدر/الفوتر دائماً
- قبل تعميم أي تعديل على `lineHeight` أو `forceStrutHeight`، اختبر الهيدر والفوتر لا body فقط

### 3. لا تفسر أي فرق رأسي صغير مباشرة بأنه margin problem
- قد يكون السبب في line metrics أو paragraph layout لا في `pgMar`
- اربط `pPr` دائماً مع:
  - `rPr`
  - أسلوب العرض الفعلي في Flutter
  - السياق (body/header/footer)

# مرجع: ECMA-376 §17.3.1.25 / §17.3.1.26 - Paragraph Properties (pPr)

## البنية الأساسية
```xml
<w:pPr>
  <w:pStyle w:val="Heading1"/>
  <w:bidi/>
  <w:jc w:val="center"/>
  <w:ind w:left="720" w:hanging="360"/>
  <w:spacing w:before="240" w:after="200" w:line="276" w:lineRule="auto"/>
  <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
  <w:tabs><w:tab w:val="left" w:pos="720"/></w:tabs>
  <w:pBdr><w:top w:val="single" w:sz="4" w:space="1" w:color="000000"/></w:pBdr>
  <w:shd w:val="clear" w:fill="FFFF00"/>
  <w:rPr><w:b/></w:rPr>
</w:pPr>
```

## جميع العناصر الأبناء لـ w:pPr

### المحاذاة والاتجاه
1. **w:jc** (§17.3.1.13) - محاذاة: `start`, `end`, `center`, `both`, `distribute`
   - في RTL: `start`=يمين, `end`=يسار
2. **w:bidi** (§17.3.1.6) - اتجاه RTL (يؤثر على ind, jc, tab)
3. **w:textDirection** (§17.3.1.41) - اتجاه تدفق النص
4. **w:textAlignment** (§17.3.1.39) - محاذاة عمودية على السطر

### الإزاحة
5. **w:ind** (§17.3.1.12) - إزاحة الفقرة (بـ twips)
   - `w:left`/`w:start`, `w:right`/`w:end`, `w:firstLine`, `w:hanging`
   - **تحذير**: firstLine و hanging متعارضان
   - **مهم في RTL**: w:left يصبح الجهة اليمنى عند w:bidi

### التباعد
6. **w:spacing** (§17.3.1.33) - التباعد
   - `w:before`/`w:after` بـ twips، `w:beforeLines`/`w:afterLines` بالمئات
   - `w:line` + `w:lineRule` (auto→240ths، exact/atLeast→twips)
   - **مهم**: بين فقرتين = max(after الأولى, before الثانية)
7. **w:contextualSpacing** (§17.3.1.9) - تجاهل التباعد مع نفس النمط

### الترقيم
8. **w:numPr** (§17.3.1.19) - ilvl + numId

### التبويب
9. **w:tabs** / **w:tab** (§17.3.1.37/38) - val, pos, leader, clear

### الحدود والتظليل
10. **w:pBdr** (§17.3.1.24) - top, bottom, left, right, between, bar
11. **w:shd** (§17.3.1.31) - val, fill, color, themeFill, themeColor

### النمط
12. **w:pStyle** (§17.3.1.27) - نمط الفقرة
13. **w:rPr** (§17.3.1.29) - تنسيق علامة الفقرة

### تحكم الصفحة
14. **w:keepLines** - إبقاء كل الأسطر في صفحة واحدة
15. **w:keepNext** - إبقاء مع الفقرة التالية
16. **w:pageBreakBefore** - بدء صفحة جديدة
17. **w:widowControl** - Widow/Orphan
18. **w:suppressLineNumbers** / **w:suppressAutoHyphens**

### خصائص متقدمة
19. **w:adjustRightInd**, **w:autoSpaceDE**, **w:autoSpaceDN**
20. **w:snapToGrid**, **w:kinsoku**, **w:overflowPunct**
21. **w:wordWrap**, **w:mirrorIndents**, **w:framePr**
22. **w:outlineLvl** (0-9), **w:cnfStyle**, **w:divId**

## ملفات المشروع المرتبطة
- `lib/wordToHTML/PPr.dart` - الموديل الرئيسي
- `lib/wordToHTML/TabStop.dart` - علامات التبويب
- `lib/wordToHTML/DocumentStyles.dart` - الأنماط

## تسلسل الوراثة (Style Hierarchy)
1. docDefaults/pPrDefault ← الأدنى
2. basedOn chain
3. pStyle المباشر
4. الخصائص المباشرة في w:pPr ← الأعلى

## وحدات القياس
- **twips**: 1/20 نقطة = 1/1440 بوصة
- **half-points**: 1/2 نقطة (أحجام الخط)
- **eighths of a point**: سمك الحدود
- **240ths of a line**: تباعد الأسطر عند auto

## خطوات التحقق
1. المحاذاة مع RTL و LTR
