# إصلاح وتوثيق أسماء الخطوط في نظام ويندوز
# Windows Font Name Normalization & Weight Fix

---

## 🚩 المشكلة | The Problem

**العربية:**
عند تشغيل التطبيق على نظام Windows، فشل Flutter في التعرف على بعض الخطوط المثبتة في النظام (مثل `Al-Jazeera-Arabic-Bold`).
السبب هو اختلاف المعايير بين ملفات Word ونظام Flutter على Windows:
1.  **Word:** يستخدم غالباً "الاسم الكامل" للملف (PostScript Name) الذي يدمج الاسم مع النمط (مثلاً: `Al-Jazeera-Arabic-Bold`).
2.  **Flutter (Windows):** يتوقع "اسم العائلة" (Family Name) فقط (مثلاً: `Al-Jazeera-Arabic`)، وينتظر تحديد الوزن (Bold) كخاصية منفصلة `fontWeight`.

عندما يرسل Word الاسم الكامل `Al-Jazeera-Arabic-Bold` كاسم للعائلة، يفشل Flutter في إيجاد عائلة بهذا الاسم.

**English:**
Flutter on Windows failed to recognize certain system fonts (e.g., `Al-Jazeera-Arabic-Bold`).
The issue stems from a mismatch in naming standards:
1.  **Word:** Uses the "PostScript Name" which combines family and style (e.g., `Al-Jazeera-Arabic-Bold`).
2.  **Flutter (Windows):** Expects the "Typographic Family Name" (e.g., `Al-Jazeera-Arabic`) and separate `fontWeight` property.

Passing the full PostScript name as the font family caused the lookup to fail.

---

## 🛠️ الحل: استراتيجية الفصل | The Solution: Split Strategy

قمنا بفصل "اسم العائلة" عن "وزن الخط" برمجياً باستخدام دالتين جديدتين في `lib/Models/WordDocument.dart`.

### 1. `normalizeFontFamily(String font)`
تقوم هذه الدالة "بتنظيف" اسم الخط لاستخراج **اسم العائلة** الصافي المطلوب في ويندوز.
*   **الإجراء:** تحذف اللواحق الخاصة بالنمط من نهاية الاسم (مثل `Bold`, `Italic`, `Light`, `Medium`, etc.).
*   **ملاحظة هامة:** الدالة **تحافظ على الواصلات (Hyphens)** في بداية الاسم، لأن بعض الخطوط (مثل `Al-Jazeera-Arabic`) تستخدم الواصلات كجزء أصلي من اسم العائلة.
*   **مثال:**
    *   `Al-Jazeera-Arabic-Bold` -> `Al-Jazeera-Arabic`
    *   `Traditional Arabic Bold` -> `Traditional Arabic`

### 2. `getImplicitFontWeight(String fontName)`
تقوم هذه الدالة باستنتاج **وزن الخط** من الاسم الأصلي قبل التنظيف، لتعويض غياب وسم `<w:b/>` في ملف الـ XML أحياناً.
*   **الإجراء:** تفحص الاسم بحثاً عن كلمات دلالية وتعود بالوزن المناسب:
    *   `Black` / `ExtraBold` -> `FontWeight.w900`
    *   `Bold` -> `FontWeight.bold` (w700)
    *   `SemiBold` -> `FontWeight.w600`
    *   `Medium` -> `FontWeight.w500`
    *   `Light` -> `FontWeight.w300`

---

## 💻 التطبيق في الكود | Code Implementation

**الملف:** `lib/wordToHTML/RPr.dart`
**الدالة:** `getTextStyle()`

```dart
// 1. Detect Implicit Weight (استنتاج الوزن)
FontWeight? implicitWeight = font != null ? getImplicitFontWeight(font!) : null;

// 2. Normalize Family Name (تنظيف اسم الخط)
String? effectiveFontFamily = font != null ? normalizeFontFamily(font!) : null;

return TextStyle(
  fontFamily: effectiveFontFamily, // استخدام الاسم المنظف
  fontWeight: b == true ? FontWeight.bold : implicitWeight, // أولوية للـ XML ثم للاستنتاج
  // ...
);
```

---

## ✅ النتائج | Results

*   يتعرف التطبيق الآن بنجاح على خطوط مثل `Al-Jazeera-Arabic-Bold` كخط `Al-Jazeera-Arabic` بوزن `Bold`.
*   يتم دعم الأوزان المختلفة (Light, Medium) بشكل صحيح دون أن تفقد وزنها عند تنظيف الاسم.
*   الحل عام وشامل ولا يعتمد على "ترقيع" (Mapping) لخطوط محددة.

---

*Verified on: 2026-01-24*
