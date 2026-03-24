# التوثيق الشامل لنظام تموضع الصور في Golden Shamela

## تاريخ التحديث: فبراير 2026

---

# الجزء الأول: الخلفية النظرية — كيف يعمل تموضع الصور في Word (OOXML)

## 1.1 أنواع الصور في Word XML

في ملف `document.xml` الخاص بـ Word، توجد الصور داخل عنصر `w:drawing`. هناك نوعان رئيسيان:

### أ. الصور المضمنة (Inline Images) — `wp:inline`
- تتدفق مع النص كأنها حرف كبير.
- لا تملك خصائص تموضع مطلق (`posX`, `posY`).
- خاصية `wrapMode` تكون `null` في التطبيق.
- **مثال:** أيقونة صغيرة داخل سطر نصي.

### ب. الصور العائمة (Floating/Anchored Images) — `wp:anchor`
- تملك تموضعاً مطلقاً أو نسبياً.
- تملك `wrapMode` (مثل `None`, `Square`, `Tight`, `TopAndBottom`).
- تملك خصائص `positionH` و `positionV` تحدد مكانها.

## 1.2 خصائص التموضع الأفقي (`wp:positionH`)

### السمة `relativeFrom` — المرجعية الأفقية:
| القيمة | المعنى |
|--------|--------|
| `page` | الإزاحة من حافة الصفحة اليسرى |
| `margin` | الإزاحة من حافة الهامش الأيسر (= بداية منطقة المحتوى) |
| `column` | الإزاحة من حافة العمود (في مستند عمود واحد = نفس `margin`) |
| `character` | الإزاحة من موقع الحرف الذي ترتبط به الصورة |

### القيمة الداخلية:
- إما `wp:posOffset` — رقم بوحدة EMU (English Metric Units)، يتم تحويله إلى بكسل.
- أو `wp:align` — نص مثل `"center"`, `"right"`, `"left"`.

**مهم جداً:** `posOffset` هو إزاحة من الحافة اليسرى للمرجعية دائماً (حتى في المستندات RTL)، إلا في حالات خاصة مع RTL حيث يكون للقيمة السالبة معنى خاص.

## 1.3 خصائص التموضع الرأسي (`wp:positionV`)

### السمة `relativeFrom` — المرجعية الرأسية:
| القيمة | المعنى |
|--------|--------|
| `page` | الإزاحة من أعلى الصفحة |
| `margin` | الإزاحة من أعلى منطقة الهامش |
| `paragraph` | الإزاحة من أعلى الفقرة التي ترتبط بها الصورة |
| `line` | الإزاحة من أعلى السطر |
| `topMargin` | الإزاحة من أعلى الهامش العلوي |

### القيمة الداخلية:
- إما `wp:posOffset` — رقم EMU.
- أو `wp:align` — نص مثل `"top"`, `"center"`, `"bottom"`.

## 1.4 خصائص إضافية مهمة

| الخاصية | المكان في XML | المعنى |
|---------|---------------|--------|
| `wp:extent` | `cx`, `cy` | أبعاد الصورة بوحدة EMU |
| `behindDoc` | سمة على `wp:anchor` | `true` = خلف النص (خلفية)، `false` = أمام النص |
| `wrapNone` | عنصر فرعي | لا التفاف — الصورة تطفو فوق/تحت النص بدون تأثير |
| `wrapSquare` | عنصر فرعي | النص يلتف حول مستطيل الصورة |
| `wrapTight` | عنصر فرعي | النص يلتف بشكل محكم حول حدود الصورة |
| `relativeHeight` | سمة على `wp:anchor` | ترتيب الطبقات (Z-Index) — الأعلى يظهر فوق |

## 1.5 وحدات القياس

| الوحدة | الاستخدام | التحويل |
|--------|----------|---------|
| EMU | أبعاد الصور (`wp:extent`) والإزاحات (`wp:posOffset`) | `1 بكسل = 9525 EMU` |
| Twips | أبعاد الصفحة والهوامش (`w:pgSz`, `w:pgMar`) | `1 بكسل ≈ 15 Twip` (تقريباً) |

### دوال التحويل في التطبيق:
- `emuToPx()` — تحويل EMU إلى بكسل.
- `twpsToPx()` — تحويل Twips إلى بكسل.

---

# الجزء الثاني: كيف يعمل نظام التموضع في التطبيق

## 2.1 مخطط تدفق البيانات (Pipeline)

```
XML Document
    │
    ▼
[ImageParser.dart] ──── يستخرج البيانات من XML ويملأ كائن ImageData
    │
    ▼
[ImageData] ──── كائن يحمل كل خصائص الصورة (posX, posY, relativeFromH, etc.)
    │
    ▼
[Paragraph.getPRunsByType()] ──── يصنف الصورة: هل تُعرض في الفقرة أم في الصفحة؟
    │
    ├── imageRunTs ──── صور تُعرض داخل الفقرة (paragraph-level)
    │       │
    │       ▼
    │   [Paragraph._getPositionedImages()] ──── يحسب left/top ويُنشئ Positioned widget
    │
    └── (يُتجاهل هنا) ──── صور تُعرض على مستوى الصفحة (page-level)
            │
            ▼
        [WordPage.getParagraphImages()] ──── يجمع الصور للصفحة
            │
            ▼
        [ImageToWidget.getImageWidget()] ──── يحسب posX/posY ويُنشئ Align+Transform widget
```

## 2.2 مصفوفة القرار: أين تُعرض كل صورة؟

هذا هو "عقل النظام" — أي خطأ هنا يسبب تكراراً أو اختفاءً أو تموضعاً خاطئاً.

### الملف المسؤول: `Paragraph.dart` — دالة `getPRunsByType()`
### الملف المكمل: `WordPage.dart` — دالة `getParagraphImages()`

| الحالة | wrapMode | relativeFromV | الحجم | أين تُعرض؟ | السبب |
|--------|----------|---------------|-------|-----------|-------|
| صورة مضمنة | `null` | — | أي حجم | `textRunTs` (داخل النص) | ليست عائمة أصلاً |
| عائمة، مرجعية الصفحة | `!= null` | `page`/`margin` | أي حجم | **الصفحة** (page-level) | لا علاقة لها بالفقرة |
| عائمة، مرجعية الفقرة، صغيرة | `!= null` | `paragraph`/`line` | أصغر من منطقة المحتوى | **الفقرة** (paragraph-level) | تتموضع نسبياً للفقرة |
| عائمة، مرجعية الفقرة، كبيرة | `!= null` | `paragraph`/`line` | أكبر من منطقة المحتوى | **الصفحة** (page-level) | تحتاج تجاوز الهوامش (مثل صور الغلاف) |
| مجموعة (Group) | `!= null` | أي قيمة | أي حجم | **الفقرة** (paragraph-level) | تُعامل كعنصر محلي |

### الكود الفعلي في `getPRunsByType()`:
```dart
// حساب منطقة المحتوى
var sp = parent.parent.getPageSectPr();
double contentW = (sp.width ?? 595) - sp.leftMargin - sp.rightMargin;
double contentH = (sp.height ?? 842) - sp.topMargin - sp.bottomMargin;
bool exceedsContent = runt.image!.width > contentW || runt.image!.height > contentH;

// القرار:
if ((runt.isRelativeFromVParagraph() && !exceedsContent) ||
    (runt.image != null && runt.image!.isGroup)) {
  imageRunTs.add(runt);  // → الفقرة
}
// وإلا → يُتجاهل هنا ويُلتقط بواسطة WordPage.getParagraphImages()
```

### الكود المقابل في `getParagraphImages()`:
```dart
bool isParaRelative = r.isRelativeFromVParagraph();
bool exceedsContentArea = r.image != null &&
    (r.image!.width > contentW || r.image!.height > contentH);

if (r.image != null &&
    r.image!.wrapMode != null &&
    (!isParaRelative || exceedsContentArea)) {
  list.add(r.image!);  // → الصفحة
}
```

### القاعدة الذهبية:
**كل صورة يجب أن تنتمي لمكان واحد فقط.** الشرطان في `getPRunsByType` و `getParagraphImages` يجب أن يكونا متكاملين (complementary) — ما يُقبل في أحدهما يُرفض في الآخر.

## 2.3 البنية الهرمية للعرض (Widget Tree)

### على مستوى الصفحة (`WordPageScreen.dart`):
```
Container (عرض الصفحة × ارتفاعها)
  └── Stack
        ├── [1] Header — Positioned(top:0)
        ├── [2] Background Images — Positioned(top:0, left:0, w:pageW, h:pageH)
        │         └── Stack of Align+Transform.translate+OverflowBox
        ├── [3] Content — Padding(margins)
        │         └── Column
        │               └── Paragraph.toWidget() × N
        ├── [4] Footer — Positioned(bottom:0)
        └── [5] Foreground Images — Positioned(top:0, left:0, w:pageW, h:pageH)
                  └── Stack of Align+Transform.translate+OverflowBox
```

### على مستوى الفقرة (`Paragraph.toWidget()`):
```
Padding (paragraph padding من w:ind)
  └── Container (decoration: borders, shading)
        └── Stack (fit: loose, clip: none, textDirection: LTR)
              ├── [1] behindImages — Positioned(left, top) مباشرة
              ├── [2] Text Content — Directionality(RTL) → SelectableText/RichText
              └── [3] frontImages — Positioned(left, top) مباشرة
```

---

# الجزء الثالث: المشاكل التي واجهتنا وكيف حُلّت

## 3.1 المشكلة الأولى: صور الغلاف محصورة داخل الهوامش

### الأعراض:
صور الغلاف (التي يجب أن تملأ الصفحة كاملة) كانت تُعرض داخل منطقة الهوامش فقط، ولا تتجاوزها.

### السبب الجذري:
صور الغلاف في الـ XML لها `relativeFromV="paragraph"` و `wrapNone`. الكود القديم كان يعتبر كل صورة `paragraph-relative` كصورة محلية تُعرض داخل الفقرة. لكن الفقرة محصورة داخل `Padding(margins)`، فالصورة لا تستطيع تجاوز الهوامش.

### الحل:
أضفنا **فحص الحجم** (size check):
- إذا كانت الصورة `paragraph-relative` لكن أبعادها **أكبر من منطقة المحتوى** (عرض الصفحة - الهوامش)، فهي صورة غلاف يجب أن تُعرض على مستوى الصفحة.
- إذا كانت أصغر، تبقى في الفقرة.

### لماذا هذا الحل صحيح:
- صورة غلاف عرضها 793 بكسل ومنطقة المحتوى 619 بكسل → تتجاوز → تذهب للصفحة.
- صورة QR عرضها 179 بكسل ومنطقة المحتوى 619 بكسل → لا تتجاوز → تبقى في الفقرة.

---

## 3.2 المشكلة الثانية: صور behindDoc مع relativeFromV="paragraph"

### الأعراض:
بعض الصور الخلفية (behindDoc=true) كانت لا تُعرض بشكل صحيح لأنها كانت تُحسب كصور فقرة رغم أنها تحتاج أن تكون على مستوى الصفحة.

### الحل:
أُدمج هذا مع فحص الحجم. الصور الكبيرة (التي تتجاوز المحتوى) تذهب للصفحة بغض النظر عن `behindDoc`.

---

## 3.3 المشكلة الثالثة (الأخطر): صور QR في موضع خاطئ تماماً

### الأعراض:
صورتا QR code كانتا تظهران في الزاوية العليا اليسرى للفقرة بدلاً من مواضعهما الصحيحة (`left=128.6, top=142.7` و `left=309.1, top=42.7`).

### عملية التشخيص:
1. أضفنا `debug prints` في `_getPositionedImages()` لطباعة القيم المحسوبة.
2. اكتشفنا أن القيم المحسوبة **صحيحة تماماً** (`left=128.6`, `top=142.7`).
3. لكن الصور كانت تظهر في (0,0) رغم ذلك!
4. لاحظنا استثناء Flutter: `Incorrect use of ParentDataWidget`.

### السبب الجذري (Root Cause):
في دالة `toWidget()` في `Paragraph.dart`، كان الكود يلف كل صورة بـ `IgnorePointer`:

```dart
// ❌ الكود الخاطئ:
...behindImages.map((img) => IgnorePointer(child: img)),
...frontImages.map((img) => IgnorePointer(child: img)),
```

حيث `img` هو `Positioned(left: 128.6, top: 142.7, child: ...)`.

هذا يُنشئ الهيكل التالي:
```
Stack
  └── IgnorePointer        ← هذا ما يراه الـ Stack (ابن مباشر)
        └── Positioned      ← هذا ليس ابناً مباشراً للـ Stack!
              └── Image
```

### لماذا هذا خطأ؟

**قاعدة Flutter الصارمة:** `Positioned` يجب أن يكون **ابناً مباشراً** (direct child) لـ `Stack`.

عندما يكون `Positioned` مغلفاً بـ `IgnorePointer`:
1. الـ `Stack` يرى `IgnorePointer` كابنه المباشر.
2. الـ `Stack` يعطي `IgnorePointer` بيانات تموضع افتراضية (0,0).
3. `Positioned` يحاول تطبيق بيانات التموضع (`left`, `top`) على ابنه، لكن أبوه ليس `Stack`.
4. البيانات تُطبق على render object خاطئ ولا يقرأها أحد.
5. النتيجة: الصورة تظهر في (0,0) بدلاً من (128.6, 142.7).

### التفصيل التقني (لفهم أعمق):

`Positioned` في Flutter هو `ParentDataWidget<StackParentData>`. وظيفته الوحيدة هي تعديل `parentData` الخاص بالـ render object لابنه. الـ `Stack` يقرأ هذا الـ `parentData` أثناء الـ layout ليعرف أين يضع كل ابن.

عندما يكون `Positioned` داخل `IgnorePointer`:
- `IgnorePointer` ينشئ `RenderIgnorePointer` الذي يكون ابناً مباشراً لـ `RenderStack`.
- `Positioned` يعدل `parentData` لـ render object ابنه (وهو أبعد من `RenderStack`).
- `RenderStack` لا يرى هذا التعديل لأنه يقرأ `parentData` من أبنائه المباشرين فقط.
- `RenderIgnorePointer` يحصل على `StackParentData` افتراضي → موقع (0,0).

### الحل:

**إزالة الغلاف الخارجي `IgnorePointer`** من `toWidget()`:

```dart
// ✅ الكود الصحيح:
...behindImages,    // Positioned هو ابن مباشر للـ Stack
...frontImages,     // IgnorePointer موجود أصلاً داخل كل Positioned
```

الهيكل الصحيح:
```
Stack
  └── Positioned(left: 128.6, top: 142.7)    ← ابن مباشر للـ Stack ✅
        └── IgnorePointer                      ← يمنع الصورة من التقاط اللمسات
              └── GestureDetector
                    └── Image
```

### لماذا كان `IgnorePointer` الخارجي موجوداً أصلاً؟

لمنع الصور من التقاط أحداث اللمس (pointer events) التي قد تمنع تحديد النص أو التمرير.
لكن هذا الـ `IgnorePointer` كان **مكرراً** — يوجد بالفعل `IgnorePointer` داخل كل `Positioned` (في دالة `_getPositionedImages`).

### تغيير إضافي:

غيرنا `IgnorePointer(ignoring: isHeaderParagraph)` الداخلي إلى `IgnorePointer()` (دائماً يتجاهل)، لأن:
1. الـ `IgnorePointer` الخارجي كان دائماً `ignoring: true` (القيمة الافتراضية).
2. بإزالته، يجب أن يأخذ الداخلي نفس السلوك.
3. هذا يمنع الصور من اعتراض أحداث اللمس التي يجب أن تصل للنص تحتها.

---

# الجزء الرابع: كيف يحسب التطبيق موضع الصورة — التفاصيل الدقيقة

## 4.1 على مستوى الصفحة (`ImageToWidget.dart`)

### الموضع الأفقي:
```dart
// إذا كان هناك محاذاة (align) بدلاً من إزاحة رقمية:
if (usesHAlign && alignH == "center") {
    posX = leftMargin + (marginAreaWidth - imageWidth) / 2;  // للمرجعية margin/column
    posX = (pageWidth - imageWidth) / 2;                      // للمرجعية page
}

// إذا كان هناك إزاحة رقمية (posOffset):
// LTR:
posX = image.posX + leftMargin;   // للمرجعية margin/column
posX = image.posX;                // للمرجعية page

// RTL مع قيمة سالبة:
alignment = Alignment.topRight;
posX = -(rightMargin + image.posX);  // المرجعية من اليمين
```

### الموضع الرأسي:
```dart
if (relativeFromV == "page" || relativeFromV == "topMargin") {
    posY = image.posY;                  // من أعلى الصفحة مباشرة
} else if (relativeFromV == "paragraph") {
    posY = image.posY + topMargin;      // الفقرة تقريباً عند topMargin
} else {
    posY = image.posY + topMargin;      // margin وغيرها
}
```

### آلية العرض:
```dart
Align(alignment: topLeft/topRight)
  └── Transform.translate(offset: Offset(posX, posY))
        └── OverflowBox(maxWidth: infinity, maxHeight: infinity)
              └── Image
```

**`OverflowBox`** ضروري للسماح للصور الكبيرة (مثل الأغلفة) بتجاوز حدود الحاوية.

## 4.2 على مستوى الفقرة (`Paragraph._getPositionedImages()`)

### نقطة الأصل:
نقطة (0,0) في الـ Stack الخاص بالفقرة = **الزاوية العليا اليسرى لمنطقة المحتوى** (بعد الهوامش).

### الموضع الأفقي:
```dart
if (alignH == "center") {
    left = (marginAreaWidth - imageWidth) / 2;
} else if (alignH == "right") {
    left = marginAreaWidth - imageWidth;
} else if (relativeFromH == "page") {
    left = posX - leftMargin;   // تحويل من إحداثيات الصفحة إلى إحداثيات الفقرة
} else {
    left = posX;                // column/margin: نفس نقطة أصل الفقرة
}
```

### الموضع الرأسي:
```dart
top = image.posY;  // relativeFromV="paragraph" → posY نسبي للفقرة مباشرة
```

### آلية العرض:
```dart
Positioned(left: left, top: top)
  └── IgnorePointer
        └── Image/TextBox/Group
```

**مهم:** `Positioned` يجب أن يكون ابناً مباشراً للـ `Stack` في `toWidget()`. هذا هو الدرس الأهم من جلسة الإصلاح هذه.

---

# الجزء الخامس: تحذيرات حرجة وفهوم خاطئة شائعة

## 5.1 تحذيرات

### ⚠️ تحذير 1: `Positioned` يجب أن يكون ابناً مباشراً لـ `Stack`
**لا تغلف `Positioned` بأي widget آخر** (مثل `IgnorePointer`, `Container`, `Padding`, `Opacity`).
إذا كنت تريد إضافة سلوك، ضعه **داخل** الـ `Positioned`:
```dart
// ✅ صحيح:
Positioned(left: 10, top: 20,
  child: IgnorePointer(child: Image()))

// ❌ خطأ:
IgnorePointer(child: Positioned(left: 10, top: 20,
  child: Image()))
```

### ⚠️ تحذير 2: الصورة يجب أن تنتمي لمكان واحد فقط
إذا أُضيفت صورة لكل من `imageRunTs` (الفقرة) و `getParagraphImages` (الصفحة)، ستظهر مرتين.
إذا لم تُضف لأي منهما، ستختفي.
**الشرطان يجب أن يكونا متكاملين (complementary).**

### ⚠️ تحذير 3: لا تعدل بدون مرجع
أي تعديل في حسابات التموضع يجب أن يستند إلى مواصفات OOXML المرجعية في:
`d:\ImportantProjects\golden_shamela\WordXmlDoumentation`
الحلول الترقيعية تصلح كتاباً وتخرب عشرة.

### ⚠️ تحذير 4: فحص الحجم ضروري للتمييز بين الأغلفة والصور الصغيرة
صور الغلاف وصور QR كلاهما قد يملكان `relativeFromV="paragraph"` و `wrapNone`.
الفرق الوحيد هو الحجم. بدون فحص الحجم، ستُعامل بنفس الطريقة وسيحدث خلل.

### ⚠️ تحذير 5: `getSectionMargins()` تضيف `framePadding`
في `WordPageScreen.dart`، دالة `getSectionMargins()` تضيف 60 بكسل إضافية للهامش العلوي إذا وجدت صورة كبيرة `behindDoc` في أول 3 فقرات.
هذا **يزيح منطقة المحتوى كلها للأسفل**، مما قد يسبب عدم تطابق بين تموضع الصور على مستوى الصفحة (التي لا تتأثر بهذا الإزاحة) والصور على مستوى الفقرة (التي تتأثر).
**هذا حل ترقيعي** ويجب مراجعته مستقبلاً.

## 5.2 فهوم خاطئة شائعة

### ❌ فهم خاطئ 1: "كل صورة wrapNone يجب أن تُعرض على مستوى الصفحة"
**الصواب:** فقط صور `wrapNone` التي تتجاوز منطقة المحتوى (أغلفة) تذهب للصفحة. صور `wrapNone` الصغيرة (مثل QR codes) تبقى في الفقرة.

### ❌ فهم خاطئ 2: "relativeFromV=paragraph يعني دائماً أن الصورة محلية"
**الصواب:** حتى لو كانت `relativeFromV="paragraph"`، إذا كانت الصورة كبيرة جداً (غلاف)، يجب أن تُعرض على مستوى الصفحة لأنها تحتاج تجاوز الهوامش.

### ❌ فهم خاطئ 3: "IgnorePointer لا يؤثر على التموضع"
**الصواب:** `IgnorePointer` **يكسر** التموضع إذا غلف `Positioned`، لأنه يمنع `Stack` من قراءة بيانات التموضع. هذا ليس فقط مشكلة pointer events — بل مشكلة layout كاملة.

### ❌ فهم خاطئ 4: "column = page في التموضع"
**الصواب:** `column` = بداية منطقة المحتوى (بعد الهامش الأيسر). `page` = بداية الصفحة (الحافة اليسرى المطلقة). الفرق هو `leftMargin`.

### ❌ فهم خاطئ 5: "RTL يعكس اتجاه posOffset"
**الصواب:** `posOffset` في OOXML هو دائماً من اليسار. لكن في بعض حالات RTL مع قيم سالبة، يتم استخدام نقطة مرجعية يمنى. التطبيق يتعامل مع هذا عبر فحص إشارة القيمة (موجبة/سالبة) وليس عكس الاتجاه.

---

# الجزء السادس: الملفات المعنية والدوال الرئيسية

## 6.1 خريطة الملفات

| الملف | الدور الرئيسي |
|-------|-------------|
| `lib/Utils/ImageParser.dart` | استخراج بيانات الصورة من XML → `ImageData` |
| `lib/Utils/ImageParser.dart` → `ImageData` class | نموذج البيانات لكل صورة |
| `lib/wordToHTML/Paragraph.dart` → `getPRunsByType()` | تصنيف الصور: فقرة أم صفحة |
| `lib/wordToHTML/Paragraph.dart` → `_getPositionedImages()` | حساب `left`/`top` للصور المحلية |
| `lib/wordToHTML/Paragraph.dart` → `toWidget()` | بناء شجرة الـ widgets للفقرة بما فيها الصور |
| `lib/Models/WordPage.dart` → `getParagraphImages()` | جمع الصور لمستوى الصفحة |
| `lib/WordToWidget/ImageToWidget.dart` → `getImageWidget()` | حساب `posX`/`posY` المطلقة للصور على مستوى الصفحة |
| `lib/UI/WordPageScreen.dart` → `getSectionMargins()` | حساب هوامش الصفحة الفعلية (بما فيها framePadding) |
| `lib/wordToHTML/SectPr.dart` | خصائص القسم: أبعاد الصفحة، الهوامش |
| `lib/wordToHTML/PPr.dart` | خصائص الفقرة: padding, indent, spacing |

## 6.2 الدوال الحرجة ودورها

### `ImageParser.setOffsets()`
```
يستخرج posX, posY من wp:posOffset (EMU → Px)
يستخرج alignH, alingV من wp:align
```

### `ImageParser.checkFromPage()` و `checkRelativeFromV()`
```
يستخرج relativeFromH و relativeFromV من سمة relativeFrom
```

### `runT.isRelativeFromVParagraph()`
```
يرجع true إذا كان relativeFromV == "paragraph" أو "line"
هذا هو الفاصل الرئيسي في قرار "فقرة أم صفحة"
```

---

# الجزء السابع: خلاصة التعديلات (Change Log)

## التعديل 1: فحص الحجم في `getPRunsByType()` و `getParagraphImages()`
- **الملفات:** `Paragraph.dart`, `WordPage.dart`
- **الهدف:** التمييز بين صور الغلاف (كبيرة → صفحة) وصور QR (صغيرة → فقرة)
- **المعيار:** هل `image.width > contentW` أو `image.height > contentH`؟

## التعديل 2: إصلاح `IgnorePointer` يكسر `Positioned` في `toWidget()`
- **الملف:** `Paragraph.dart`
- **المشكلة:** `IgnorePointer(child: Positioned(...))` يمنع `Stack` من قراءة بيانات التموضع
- **الحل:** إزالة `IgnorePointer` الخارجي، الاعتماد على `IgnorePointer` الداخلي الموجود أصلاً
- **التأثير:** إصلاح تموضع **كل** الصور المحلية في الفقرات (QR codes, text boxes, groups, etc.)

## التعديل 3: `IgnorePointer` الداخلي يتجاهل دائماً
- **الملف:** `Paragraph.dart` → `_getPositionedImages()`
- **التغيير:** من `IgnorePointer(ignoring: isHeaderParagraph)` إلى `IgnorePointer()`
- **السبب:** الـ `IgnorePointer` الخارجي المُزال كان دائماً `ignoring: true`، فيجب أن يرث الداخلي نفس السلوك

---

# الجزء الثامن: كيفية التحقق والاختبار

## 8.1 اختبار الأغلفة (صور كبيرة):
1. افتح كتاباً يحتوي على صفحة غلاف.
2. تأكد أن صورة الغلاف تملأ الصفحة كاملة وتتجاوز الهوامش.
3. تأكد أنها تظهر خلف النص (إذا كانت `behindDoc=true`).

## 8.2 اختبار صور QR وصور صغيرة:
1. افتح كتاباً يحتوي على صور QR أو أيقونات صغيرة.
2. تأكد أن كل صورة في موضعها الصحيح (ليست في الزاوية العليا اليسرى!).
3. قارن مع عرض Word لنفس الصفحة.

## 8.3 اختبار الإطارات الزخرفية:
1. افتح كتاباً يحتوي على إطار زخرفي (صورة كبيرة behindDoc خلف النص).
2. تأكد أن الإطار يظهر في مكانه الصحيح.
3. تأكد أن النص لا يتداخل بشكل سيء مع الإطار.

## 8.4 فحص عدم وجود تكرار:
1. تأكد أنه لا توجد صورة تظهر مرتين (مرة في الفقرة ومرة في الصفحة).
2. ابحث عن صور في (0,0) — هذا مؤشر على خلل في التموضع.

## 8.5 فحص عدم وجود استثناءات:
1. تأكد من عدم وجود `Incorrect use of ParentDataWidget` في الـ console.
2. هذا الاستثناء يعني أن `Positioned` ليس ابناً مباشراً لـ `Stack`.

---

# الجزء التاسع: ملاحظات للذكاء الاصطناعي القادم

1. **اقرأ هذا الملف كاملاً قبل أي تعديل على نظام الصور.**
2. **اقرأ `warnings.md` قبل أي تعديل.**
3. **لا تغلف `Positioned` بأي widget — أبداً.**
4. **تأكد أن شروط `getPRunsByType` و `getParagraphImages` متكاملة.**
5. **فحص الحجم ضروري — لا تزله.**
6. **الوحدات:** EMU للصور، Twips للصفحة. لا تخلط بينهما.
7. **للتشخيص:** أضف `print` statements في `_getPositionedImages` لطباعة `left`, `top`, `posX`, `posY`, `relativeFromH`, `relativeFromV`. إذا كانت القيم صحيحة لكن الصورة في (0,0)، المشكلة في شجرة الـ widgets وليس في الحسابات.
8. **ارجع دائماً للمرجع:** `d:\ImportantProjects\golden_shamela\WordXmlDoumentation`
