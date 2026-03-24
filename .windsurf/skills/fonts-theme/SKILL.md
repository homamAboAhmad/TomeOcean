---
name: fonts-theme
description: مهارة التعامل مع الخطوط والثيم (Fonts & Theme) في Word XML
---

# تحذيرات مهمة
- التطبيق دقيق جداً لذا لا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر عرض باقي الكتب
- التطبيق يعمل ومخصص للويندوز حالياً
- التطبيق سيعرض عشرات آلاف الكتب
- يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد
- الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتاباً ويخرب عرض عشرة غيره

# ⚠️ تحذير سلامة التعديل
**قبل أي تعديل على كود الخطوط والثيم، تأكد من:**
1. أن التعديل لا يكسر حل ألوان الثيم (themeColor + tint/shade)
2. أن التعديل لا يؤثر على اختيار الخط حسب Unicode range (ascii/hAnsi/cs/eastAsia)
3. أن التعديل لا يكسر حل خطوط الثيم (asciiTheme → اسم الخط الفعلي)
4. الخطوط والثيم تؤثر على **كل نص في المستند** - أي خطأ يكسر كل شيء
5. اختبر مع كتب تستخدم ثيمات مختلفة وخطوط متنوعة

# 🔗 المهارات المرتبطة (الخطوط والثيم تؤثر على كل شيء!)
- **rpr.md** → rFonts (اختيار الخط)، color (ألوان الثيم)، sz/szCs
- **ppr.md** → shd (ألوان الثيم في التظليل)، pBdr (ألوان الحدود)
- **styles.md** → docDefaults يحدد الخطوط الافتراضية، الأنماط تستخدم خطوط الثيم
- **tables.md** → تظليل وحدود الجدول تستخدم ألوان الثيم
- **runs.md** → كل run يتأثر باختيار الخط
- **headers.md** / **footers.md** / **footnotes-endnotes.md** → كلها تستخدم الخطوط والألوان

# مرجع: ECMA-376 §17.8 (Fonts) + §20.1.6 (Theme)

## الخطوط في Word XML

### ملف word/fontTable.xml
يحتوي تعريفات كل الخطوط المستخدمة في المستند:
```xml
<w:fonts>
  <w:font w:name="Calibri">
    <w:panose1 w:val="020F0502020204030204"/>
    <w:charset w:val="00"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Traditional Arabic">
    <w:charset w:val="B2"/>  <!-- Arabic charset -->
    <w:family w:val="roman"/>
  </w:font>
</w:fonts>
```

### قواعد اختيار الخط حسب Unicode range (§17.3.2.26)
| Unicode Range | الخط المستخدم |
|--------------|---------------|
| U+0000-U+007F | ascii |
| U+0080-U+024F | hAnsi |
| U+0590-U+07BF (عربي/عبري) | cs |
| U+3000-U+D7FF (CJK) | eastAsia |
| غير ذلك | يعتمد على hint |

### الخطوط من الثيم
- `w:asciiTheme="minorHAnsi"` → يُحل إلى اسم الخط من theme1.xml
- `w:cstheme="minorBidi"` → الخط العربي من الثيم
- الخط المحدد بالاسم (w:ascii="Arial") يتجاوز خط الثيم

## الثيم (Theme) في Word XML

### ملف word/theme/theme1.xml
```xml
<a:theme>
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>   <!-- dark1 -->
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>       <!-- light1 -->
      <a:dk2><a:srgbClr val="44546A"/></a:dk2>                       <!-- dark2 -->
      <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>                       <!-- light2 -->
      <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
      <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
      <!-- accent3-6, hlink, folHlink -->
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont>
        <a:latin typeface="Calibri Light"/>
        <a:cs typeface=""/>                    <!-- خط CS للعناوين -->
      </a:majorFont>
      <a:minorFont>
        <a:latin typeface="Calibri"/>
        <a:cs typeface="Arial"/>               <!-- خط CS للنص العادي -->
      </a:minorFont>
    </a:fontScheme>
  </a:themeElements>
</a:theme>
```

### حل خطوط الثيم
| قيمة الثيم | المصدر |
|-----------|--------|
| majorHAnsi / majorAscii | a:majorFont/a:latin |
| minorHAnsi / minorAscii | a:minorFont/a:latin |
| majorBidi | a:majorFont/a:cs |
| minorBidi | a:minorFont/a:cs |
| majorEastAsia | a:majorFont/a:ea |
| minorEastAsia | a:minorFont/a:ea |

### حل ألوان الثيم
| اسم في w:themeColor | المصدر في clrScheme |
|---------------------|---------------------|
| dark1 / text1 | a:dk1 |
| light1 / background1 | a:lt1 |
| dark2 / text2 | a:dk2 |
| light2 / background2 | a:lt2 |
| accent1-accent6 | a:accent1-a:accent6 |
| hyperlink / hlink | a:hlink |
| followedHyperlink / folHlink | a:folHlink |

### تطبيق Tint و Shade
- **Tint** (تفتيح): لون أقرب للأبيض
  - R' = R + (255-R) × (255-tintValue)/255
- **Shade** (تغميق): لون أقرب للأسود
  - R' = R × shadeValue/255

## ملفات المشروع المرتبطة
- `lib/wordToHTML/DocTheme.dart` - تحميل الثيم وألوانه
- `lib/wordToHTML/DocFonts.dart` - جدول الخطوط
- `lib/wordToHTML/RPr.dart` - resolveThemeColor(), _applyTint(), _applyShade()
- `lib/wordToHTML/DocumentDefaults.dart` - الخطوط الافتراضية

## خطوات التحقق
1. خطوط الثيم تُحل إلى الأسماء الصحيحة
2. ألوان الثيم تُحل بشكل صحيح
3. Tint/Shade يُحسب بالمعادلة الصحيحة
4. أسماء الثيم البديلة (background1→light1, text1→dark1)
5. اختيار الخط حسب Unicode range
6. الخط المحدد بالاسم يتجاوز خط الثيم
7. **تأكد أن التعديل لا يؤثر سلباً - الخطوط والألوان تؤثر على كل نص في المستند!**
