# إصلاح طول السطر: Flutter vs Word
# Line Length Fix: Flutter vs Word

---

## المشكلة | The Problem

**العربية:**
عند عرض نفس مستند Word في Flutter، كان التطبيق يعرض كلمات أقل في كل سطر مقارنة بـ Microsoft Word، مما أدى إلى التفاف النص مبكراً واستخدام أسطر أكثر.

**English:**
When rendering the same Word document in Flutter, the app displayed fewer words per line than Microsoft Word, causing text to wrap earlier and use more lines.

---

## التشخيص | Diagnosis

### ما تم التحقق منه (وأثبت أنه صحيح) | What Was Verified (and proved correct):
- ✅ أبعاد الصفحة: 793.53 dp (A4 = 595pt × 1.333)
- ✅ عرض منطقة المحتوى: 553.59 dp
- ✅ الهوامش: صحيحة (3.18cm لكل جانب)
- ✅ معادلات التحويل (twips/dp/px)
- ✅ حسابات حجم الخط

### ما ليس سبب المشكلة | What Was NOT the Cause:
- ❌ حسابات الصفحة/الهوامش
- ❌ ارتفاع/تباعد الأسطر (lineHeight, arabicSafetyMargin)
- ❌ معادلات التحويل

---

## السبب الجذري | Root Cause

**Material 3 Default Letter Spacing**

Flutter (Material 3) قد يضيف `letterSpacing` افتراضي غير صفري، مما يزيد المسافة بين الحروف ويقلل عدد الكلمات في السطر.

Flutter (Material 3) may apply non-zero default `letterSpacing`, which increases space between characters and reduces words per line.

---

## الحل النهائي | Final Solution

تم تطبيق حل مركب من 3 خطوات لتحقيق "الوسط الذهبي":

1. **إعادة `letterSpacing: 0`** في `RPr.dart`:
   - هذا الإصلاح الجوهري لعرض السطر الأفقي.
   
2. **استعادة `StrutStyle` الأصلي** في `Paragraph.dart`:
   - استخدام الخط العربي في `StrutStyle` أفسد العرض الأفقي، لذا عدنا لاستخدام `enFont` كأولوية للحفاظ على ضغط السطر أفقياً.

3. **هامش الأمان الرأسي** في `PPr.dart`:
   - تم التراجع عنه إلى `1.30` بناءً على طلب المستخدم.

**ملف:** `lib/wordToHTML/PPr.dart`
```dart
const double arabicSafetyMargin = 1.30; // Reverted to 1.30
```

**ملف:** `lib/wordToHTML/RPr.dart`
```dart
letterSpacing: 0,
```

---

## النتيجة | Result

- **أفقياً:** تطابق شبه تام مع Word (عدد كلمات صحيح).
- **رأسياً:** تباعد مريح بدون تداخل.

---

## مراجع إضافية | Additional References

- [Flutter Issue #143941](https://github.com/flutter/flutter/issues/143941) - letterSpacing affecting Arabic text
- [Flutter Issue #39755](https://github.com/flutter/flutter/issues/39755) - Arabic justification issues
- محرك Word يستخدم Microsoft Layout Engine
- محرك Flutter يستخدم HarfBuzz via Skia

---

## ملاحظات مستقبلية | Future Notes

إذا استمرت الفروقات الطفيفة، يمكن:
1. تضمين نفس ملف الخط المستخدم في Word كـ asset
2. تطبيق معامل تصحيح (0.98-1.02) بناءً على قياسات فعلية
3. استخدام Kashida للضبط العربي بدلاً من التباعد فقط

---

*تاريخ الإصلاح: 2026-01-23*
