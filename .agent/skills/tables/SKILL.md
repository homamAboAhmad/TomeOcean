---
name: tables
description: مهارة التعامل مع الجداول (w:tbl) في Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الجداول، تأكد من:**
1. أن التعديل لا يكسر gridSpan (دمج الأعمدة) أو vMerge (الدمج العمودي)
2. أن التعديل لا يؤثر على حل تعارض الحدود (border conflict resolution)
3. أن التعديل لا يكسر bidiVisual (الجداول العربية RTL)
4. أن التعديل لا يؤثر سلباً على الفقرات والـ runs داخل الخلايا
5. أن التعديل لا يكسر التنسيق الشرطي (firstRow, firstCol, banding)
6. أن التعديل لا يؤثر على الترقيم داخل الجداول
7. اختبر مع جداول معقدة (دمج، RTL، أنماط شرطية، متداخلة)

# 🔗 المهارات المرتبطة (الجدول يحتوي محتوى كامل!)
كل خلية في الجدول تحتوي فقرات كاملة، لذا **ستحتاج حتماً**:
- **paragraphs.md** → الفقرات داخل كل خلية - تُستخدم دائماً
- **runs.md** + **rpr.md** + **ppr.md** → محتوى النص وتنسيقه
- **numbering.md** → الترقيم داخل الجداول (قيد: إعادة بدء)
- **images.md** → صور داخل خلايا الجدول
- **fields-hyperlinks.md** → حقول وروابط داخل الخلايا
- **styles.md** → tblStyle + التنسيق الشرطي (tblStylePr)
- **fonts-theme.md** → ألوان الثيم في التظليل والحدود
- **sections.md** → عرض الصفحة يؤثر على عرض الجدول

# مرجع: ECMA-376 §17.4 - Tables

## البنية الأساسية
```xml
<w:tbl>
  <w:tblPr>...</w:tblPr>
  <w:tblGrid><w:gridCol w:w="4680"/>...</w:tblGrid>
  <w:tr>
    <w:trPr>...</w:trPr>
    <w:tc>
      <w:tcPr>...</w:tcPr>
      <w:p>...</w:p>  <!-- فقرة واحدة على الأقل -->
    </w:tc>
  </w:tr>
</w:tbl>
```

## خصائص الجدول (tblPr)
- tblW (auto/dxa/pct), jc, tblInd, bidiVisual
- tblBorders (top/left/bottom/right/insideH/insideV)
- shd, tblCellSpacing, tblCellMar, tblLayout (fixed/autofit)
- tblStyle, tblLook (firstRow/lastRow/firstCol/lastCol/noHBand/noVBand)

## خصائص الصف (trPr)
- trHeight (val + hRule: auto/exact/atLeast)
- cantSplit, tblHeader, jc, hidden, gridAfter/gridBefore

## خصائص الخلية (tcPr)
- tcW, tcBorders, shd, gridSpan
- vMerge (restart/continue), vAlign (top/center/bottom)
- textDirection, noWrap, tcFitText, hideMark, tcMar, cnfStyle

## قواعد حل تعارض الحدود
- tblCellSpacing > 0 → كل خلية تعرض حدودها (لا تعارض)
- tblCellSpacing = 0 → الحد الأعلى أولوية/الأعرض يفوز

## أولوية التظليل
1. tcPr/shd ← الأعلى
2. tblPrEx/shd
3. tblPr/shd ← الأدنى

## bidiVisual - مهم للعربية
- الأعمدة تُعرض من اليمين لليسار

## قيود معروفة
- التظليل الشرطي لـ firstRow/firstCol قد لا يعمل دائماً
- Bold قد لا يعمل في بعض خلايا الجدول بسبب التنسيق الشرطي
- الترقيم قد يُعاد بدؤه داخل الجداول

## ملفات المشروع المرتبطة
- `lib/wordToHTML/ParagraphTable.dart`
- `lib/wordToHTML/TableStyleHelper.dart`

## خطوات التحقق
1. gridSpan و vMerge
2. حدود الخلايا عند التعارض
3. bidiVisual يعكس الأعمدة
4. التنسيق الشرطي
5. عرض الأعمدة
6. التظليل بالأولوية الصحيحة
7. الجداول المتداخلة
8. **تأكد أن التعديل لا يؤثر سلباً على الفقرات/الترقيم/الصور داخل الخلايا**
