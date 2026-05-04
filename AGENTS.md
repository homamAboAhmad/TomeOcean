# Golden Shamela Agent Guide

هذا المشروع Flutter/Windows يعرض كتب Word/XML داخل واجهة قراءة عربية، والهدف ليس "عرضًا قريبًا من Word"، بل مطابقة Word قدر الإمكان. أي حل بصري ترقيعي غير مقبول إذا لم يكن مبنيًا على فهم XML نفسه، لأن التطبيق سيعرض عشرات آلاف الكتب، وما يصلح لكتاب قد يكسر غيره.

## قبل أي تعديل

اقرأ أولًا:
- `.agent/workflows/the-library-project-warnings.md`

استعن بالمراجع المحلية:
- `WordXmlDoumentation/key_sections.txt`
- `WordXmlDoumentation/extracted_reference.txt`

## قواعد تنفيذ حاسمة

- لا تستخدم `dart analyze`
- لا تستخدم `dart format`
- استخدم `apply_patch` فقط للتعديلات اليدوية
- أي تعديل يجب أن يكون محافظًا جدًا ومبنيًا على XML الفعلي ومرجع OOXML، لا على التخمين البصري
- إذا احتجت الاستعانة بالإنترنت، فليكن البحث موجّهًا إلى Microsoft Learn أو OOXML / ECMA-376 أو مصادر أولية فقط

## الملفات الأساسية في مسار التحويل

- `lib/wordToHTML/Paragraph.dart`
- `lib/wordToHTML/PPr.dart`
- `lib/wordToHTML/runT.dart`
- `lib/wordToHTML/RPr.dart`
- `lib/wordToHTML/SectPr.dart`
- `lib/wordToHTML/ParagraphTable.dart`
- `lib/wordToHTML/abstractNum.dart`
- `lib/Models/WordPage.dart`

## مناطق حساسة يجب عدم كسرها

### 1) الترقيم الآلي
- صار أقرب لطريقة Word
- تم تصحيح التعامل مع `hanging indent`
- تم تحسين تمثيل `marker` و `suff/tab`

### 2) المسافة بين الفقرات
- تُحسب بين فقرتين كـ `max(before, after)` بدل جمع القيمتين

### 3) فوترات `framePr`
- هناك مسار خاص يعالج الفقرات المتجاورة ذات `framePr` المتطابق كإطار واحد
- الملف الأهم هنا: `lib/wordToHTML/FooterFrameLayout.dart`
- لا تفترض أن كل footer frame حالة واحدة
- يجب فهم `framePr` ومرجع Word XML جيدًا قبل تعديل هذا المسار

### 4) ارتفاع السطر
- هذه الجزئية حساسة جدًا
- المستخدم جرّبها على عدة كتب وقال إنها ممتازة حتى الآن
- لا تعبث بها إلا إذا كانت المهمة مرتبطة بها مباشرة
- الملفات المرتبطة:
  - `lib/wordToHTML/ParagraphStrutResolver.dart`
  - `lib/wordToHTML/PPr.dart`
  - `lib/wordToHTML/PPr.g.dart`
  - `lib/wordToHTML/Paragraph.dart`
- في حالات `default/auto` تتم محاولة استخدام `LineMetrics` الفعلية للخط
- يوجد fallback محافظ للمعامل العام السابق

### 5) الأقواس والـ BiDi
- المشكلة السابقة لم تكن فقط "شكل القوس"، بل الفرق بين:
  - run ذو اتجاه صريح في XML (`w:rtl` أو `w:ltr`)
  - run محايد فقط ورث الاتجاه من الفقرة
- تم تعديل:
  - `lib/wordToHTML/BidiTextNormalizer.dart`
  - `lib/wordToHTML/runT.dart`
  - `lib/wordToHTML/runT.g.dart`
- التغيير الحالي:
  - لم نعد نقلب كل الأقواس يدويًا
  - صار التطبيع يميّز بين run ذي اتجاه صريح وrun محايد موروث
- هذه المنطقة ما زالت حساسة، فلا تعدّلها إلا إذا كانت المشكلة الجديدة مرتبطة مباشرة بها

### 6) الرموز من `w:sym`
- بعض الرموز مثل `ﷺ` ونحوها لا تأتي كنص داخل `w:t`، بل كعنصر `w:sym`.
- في هذه الحالة لا يجوز تفسير `w:char` مباشرة كحرف Unicode عادي.
- الحالة المؤكدة في المشروع: `w:sym w:font="AGA Arabesque" w:char="0065"` كانت تُعرض خطأ كحرف `e` قبل إصلاحها.
- مسار المعالجة الحالي لهذه الرموز معزول في:
  - `lib/wordToHTML/WordSymbolResolver.dart`
  - `lib/wordToHTML/runT.dart`
- إذا ظهرت مشكلة مشابهة، ابدأ من XML نفسه وتحقق أولًا:
  - هل العنصر `w:sym`؟
  - ما قيمة `w:font`؟
  - ما قيمة `w:char`؟
  - وهل الخط المقابل محمّل في التطبيق باسم العائلة الصحيح؟

### 7) نسخ النص مع حفظ فواصل الفقرات
- Flutter's `SelectableRegion` يدمج كل الفقرات المحددة في نص واحد متصل بدون فواصل `\n`
- الحل: `ClipboardPostProcessor` يعالج الحافظة بعد النسخ ويعيد فواصل الفقرات
- الملفات المرتبطة:
  - `lib/UI/clipboard_post_processor.dart` — مسؤولية واحدة: معالجة الحافظة بعد النسخ
  - `lib/UI/custom_context_menu.dart` — يفوّض النسخ لـ `ClipboardPostProcessor`
  - `lib/UI/DocViewer.dart` — يعترض Ctrl+C ويفوّض لـ `ClipboardPostProcessor`
- الخوارزمية:
  1. يقرأ نص الحافظة الذي وضعه Flutter
  2. يجلب النص المعروض لكل فقرة مرئية من `WordPage.getVisibleRenderedTexts()`
  3. يُطبّع كلا النصين (يطبّع = يزيل الاختلافات) ثم يبحث عن المطابقة
  4. يُقسّم نص الحافظة الأصلي عند حدود الفقرات مع إدراج `\n`
- التطبيع (`_normalizeForMatch`) يعالج الاختلافات بين نص الحافظة ونصنا المعروض:
  - Private Use Area (U+E000–F8FF): رموز `w:sym` تظهر في نصنا لكن Flutter يستبدلها بـ WidgetSpan
  - `\t` (U+0009): لاحقة الترقيم (numbering suffix)
  - `\uFFFC`: عنصر استبدال WidgetSpan
  - `\u00A0` → مسافة عادية: مسافة غير منقسمة
- `Paragraph.renderedPlainText` يستخرج النص من شجرة الـ InlineSpan المعروضة فعليًا
  - يُخزّن مؤقتًا في `_cachedRenderedPlainText` وقت بناء الـ widget في `toWidget()`
  - هذا يضمن مطابقة النص المعروض فعليًا وليس ناتج إعادة استدعاء `getPSpans()`
- لا تعدّل هذا المسار إلا إذا كانت المشكلة مرتبطة مباشرة بالنسخ

### 8) تحديد النص عبر الفقرات المرقّمة
- **المشكلة**: `SelectableRegion` يتوقف عند الفقرات المرقّمة آليًا ولا يمكن تحديد الصفحة كاملة
- **السبب**: `WidgetSpan` بعناصر غير قابلة للتحديد (`SizedBox`، `Row`) يقطع تدفق التحديد — Flutter لا يستطيع مد التحديد عبرها
- **الحل**: استبدال كل `WidgetSpan` ذي عنصر غير قابل للتحديد بـ `TextSpan` مع `letterSpacing` لتحقيق نفس العرض البصري مع إمكانية التحديد
- **الملفات المعدّلة**:
  - `lib/wordToHTML/PPr.dart` — فاصل الترقيم (tab suffix): `WidgetSpan(child: SizedBox(width: spacerWidth))` → `TextSpan(text: ' ', style: effectiveMarkerStyle.copyWith(letterSpacing: extraSpacing))`
  - `lib/wordToHTML/Paragraph.dart` — مسافة أول سطر (firstLineIndent): `WidgetSpan(child: SizedBox(width: indentPx))` → `_firstLineIndentSpan()` باستخدام `TextSpan` مع `letterSpacing`
  - `lib/wordToHTML/runT.dart` — علامات التبويب (tabs): `getTabWidget()` → `getTabSpan()` يُرجع `InlineSpan?` بدل `Widget?`، والفرع في `toWidget()` صار `TextSpan(children: [..., tabSpan])` بدل `WidgetSpan(Row(...))`
- **القياس**: يستخدم `TextPainter` مع `TextStyle` الفعلي (خط الفقرة) لقياس عرض المسافة وحساب `letterSpacing` المطلوب بدقة
- **آثار جانبية**:
  - مسافة إضافية في الحافظة عند النسخ (أقرب لسلوك Word الفعلي)
  - عرض بصري تقريبي (فرق ≤1px ممكن بسبب sub-pixel rounding)
  - أثر إيجابي على RTL: تقليل عدد `WidgetSpan` يقلل احتمال مشاكل `fixRtlWidgetSpan`
- لا تعدّل هذا المسار إلا إذا كانت المشكلة مرتبطة مباشرة بالتحديد أو بالمسافات الفاصلة

### 9) النسخ مع التنسيق (Rich Clipboard)
- **الميزة**: عند نسخ نص من التطبيق، يوضع على الحافظة نص عادي + HTML مع تنسيقات CSS داخلية، بحيث عند اللصق في Word أو محررات أخرى يُحافظ على التنسيق (bold, italic, color, font, underline, size, background)
- **التنفيذ**:
  - حزمة `super_clipboard` تضع `Formats.htmlText` + `Formats.plainText` على حافظة ويندوز في عملية واحدة
  - `RichClipboardBuilder` يحوّل شجرة `InlineSpan` (من `getPSpans()`) إلى HTML مع CSS داخلي
  - `ClipboardPostProcessor.postProcessClipboardRich()` يحدد الفقرات المحددة ويولّد HTML + نص عادي
- **الملفات المعدّلة/المضافة**:
  - `lib/wordToHTML/RichClipboardBuilder.dart` — جديد: تحويل InlineSpan → HTML
  - `lib/UI/clipboard_post_processor.dart` — إضافة `postProcessClipboardRich()`
  - `lib/UI/custom_context_menu.dart` — `_handleCopy` يستخدم النسخ الغني
  - `lib/UI/DocViewer.dart` — Ctrl+C يستخدم النسخ الغني
  - `lib/Models/WordPage.dart` — إضافة `getVisibleParagraphs()` لإرجاع كائنات Paragraph
  - `pubspec.yaml` — إضافة `super_clipboard: ^0.9.1`
- **التنسيقات المدعومة**: bold, italic, underline, line-through, color, font-family, font-size, letter-spacing, background-color, text-align, direction (RTL)
- **خارج النطاق**: صور، جداول، أرقام حواشي مرتبطة
- **Fallback**: إذا فشل `super_clipboard`، يُستخدم النص العادي فقط
- **"نسخ مع المرجع"**: يبقى نصًا عاديًا (التنسيق غير مناسب للمرجع)
- لا تعدّل هذا المسار إلا إذا كانت المشكلة مرتبطة مباشرة بالنسخ مع التنسيق

### 10) `header/footer` literal dot leaders
- **المشكلة**: ليست كل الحالات في الهيدر/الفوتر تستخدم `w:tab` مع `leader` حقيقي كما في OOXML المثالي. بعض الملفات تأتي فيها النقاط كنص فعلي داخل `w:t`/runs، ومعها نص قبل النقاط أو بعدها، فيبدو السطر في Word كأنه `space-between` بينما هو في XML مجرد runs عادية تحوي نقاطًا.
- **التمييز المهم**:
  - إذا كانت الفقرة تستخدم `w:tab` فعليًا، فهذه يجب أن تبقى على مسار tabs الطبيعي، ولا يجوز تحويلها إلى fallback خاص بالنقاط.
  - إذا كانت الفقرة في `header/footer` وتحتوي نقاطًا حرفية طويلة داخل runs، فهناك الآن fallback محافظ مخصص لهذه الحالة فقط.
- **الملف المسؤول**:
  - `lib/wordToHTML/HeaderFooterDotLeader.dart` — مسؤولية واحدة: اكتشاف وبناء حالة `literal dot leader` في الهيدر/الفوتر
  - `lib/wordToHTML/Paragraph.dart` — يستدعي الـ resolver فقط، ويحافظ على padding/decoration ومسار الالتفاف العام
- **شروط التفعيل الحالية**:
  - الفقرة يجب أن تكون داخل `header/footer`
  - لا تعمل إذا وُجد `framePr`
  - لا تعمل إذا وُجد `w:br` صريح
  - لا تعمل إذا كانت الفقرة تستخدم `w:tab`
- **منطق العرض الحالي**:
  - لا نعتمد على `Row/Flexible` وحده ليملأ الفراغ، لأن هذا أدى إلى نتائج مضللة في بعض المحاولات
  - يتم قياس عرض النص في الطرفين أولًا
  - ثم تُرسم النقاط فقط داخل الفجوة المتبقية بين الطرفين
  - هذا أقرب لفكرة Word في هذه الحالة من مجرد تكرار نقاط كنص عادي
- **قاعدة الجهتين مهمة جدًا**:
  - في fallback الحالي، `run` الذي يأتي **قبل** النقاط يُعامل كطرف يمين
  - و`run` الذي يأتي **بعد** النقاط يُعامل كطرف يسار
  - هذا مهم خصوصًا في RTL، لأن بعض الفوترات كانت في XML على شكل: `dots` ثم `text`، واعتبار النص دائمًا في اليمين كان يقلب النتيجة مقارنةً بـ Word
- **إصلاح إضافي مرتبط بالهيدر/الفوتر**:
  - في `Paragraph.dart` يوجد منطق محافظ يمنع التفاف فقرات الهيدر/الفوتر العادية إلى سطر ثانٍ إذا لم يكن هناك `w:br` صريح ولم تكن الحالة `framePr`
  - لا توسّع هذا المنع بشكل أعمى، لأن بعض الهيدرز/الفوترات قد تكون متعددة الأسطر فعلًا
- **محاولات فاشلة تم التراجع عنها ويجب عدم إعادتها إلا بدليل XML واضح**:
  - توسيع عرض الهيدر/الفوتر من طبقة الشاشة مثل `WordPageScreen.dart`
  - فرض `stretch` عام في `SectPr.dart`
  - اعتبار المشكلة مجرد عدد نقاط أو `letterSpacing`
  - رسم النقاط أو توزيعها دون التأكد أولًا أن الفقرة صُنّفت أصلًا كحالة `literal dot leader`
- ابدأ دائمًا من XML الفعلي: هل الحالة `tab leader` حقيقي، أم `literal dots`, أم `PAGE field`, أم `framePr`, ثم اختر المسار المناسب بأقل نطاق ممكن

### 11) `VML textbox` overflow داخل الهيدر/الفوتر
- **الحالة المؤكدة**: بعض الهيدرز تأتي كأشكال VML مثل `v:roundrect` بارتفاع ثابت، وداخلها `v:textbox > w:txbxContent`.
- **الجذر الحقيقي للمشكلة**:
  - الخطأ الظاهر كان `RenderFlex overflowed by 2.5 pixels on the bottom`
  - سجل Flutter بيّن أن `Column ← RichTextBoxWidget` كان يستلم ارتفاعًا داخليًا أصغر من المتوقع
  - السبب لم يكن line-height العام، بل أن `BoxDecoration.border` في `VmlRendererWidget` كان يستهلك من مساحة الطفل، فتصغر مساحة `txbxContent`
- **الحل الصحيح الحالي**:
  - في `lib/WordToWidget/VmlRendererWidget.dart`
  - فصل تعبئة الشكل عن حدوده
  - الخلفية تبقى في `decoration`
  - والحد يرسم في `foregroundDecoration`
  - مع الإبقاء على `clipBehavior` للشكل عندما توجد تعبئة أو حدود، حتى لا نفقد قصّ `roundrect`
  - النتيجة: يبقى الحد مرسومًا بصريًا، لكن لا يعود يقلّص مساحة النص الداخلية
- **لماذا هذا محافظ**:
  - التعديل محصور في أشكال VML التي تُرسم عبر `Container`
  - لا يغيّر `ParagraphStrutResolver`
  - لا يغيّر line-height العام للفقرات
  - لا يغيّر `RichTextBoxWidget` نفسه
  - لا يمس `VmlDiamondShapeWidget` ولا مسار `line` المرسوم بـ `CustomPaint`
- **محاولة فاشلة تم التراجع عنها**:
  - تعطيل أو تغيير strut/line-height خصيصًا لفقرات `txbxContent`
  - هذه لم تكن الجذر الحقيقي هنا، ولا ينبغي إعادتها إلا إذا أثبت XML وحسابات المساحة أن المشكلة فعلًا من النص لا من صندوق الشكل
- عند ظهور overflow صغير وثابت داخل `VML textbox`، افحص أولًا: هل مساحة الطفل انكمشت بسبب `border/padding` أو `inset` قبل العبث بمقاييس النص

### 12) خطوط VML المتقطعة (`dashstyle`) ونوع نهاية الخط (`endcap`)
- **المشكلة**: خطوط VML في الهيدر/الفوتر كانت تظهر كخط متصل صلب بدلًا من خط منقط كما في Word
- **الجذور الحقيقية**:
  1. `VmlShapeTypeResolver` لم يكن يتعرف على `o:spt="32"` (خط مستقيم) و`o:spt="20"` (وصلة مستقيمة)، فكان يسقط إلى `'shape'` ويدخل فرع `default` الذي يرسم Container عادي بدون CustomPaint
  2. `dashstyle` من `<v:stroke dashstyle="1 1">` لم يكن يُقرأ أصلًا من XML
  3. `StrokeCap.round` كان ثابتًا دائمًا، بينما الافتراضي في VML هو `flat` (= `StrokeCap.butt`)، والغطاء الدائري يمد كل قطعة بـ `strokeWidth/2` من كل جهة فيصغر الفراغ البصري
- **الملفات المسؤولة** (كل ذو مسؤولية واحدة):
  - `lib/Utils/VmlShapeTypeResolver.dart` — تحليل نوع شكل VML من `o:spt` أو اسم العنصر؛ يدعم الآن `spt=20,32` → `'line'`
  - `lib/Models/VmlShapeData.dart` — تخزين `strokeDashStyle` و`strokeEndCap` مع serialization
  - `lib/Utils/ImageParser.dart` — قراءة `dashstyle` و`endcap` من `<v:stroke>` الفرعي
  - `lib/WordToWidget/VmlDashPatternResolver.dart` — تحويل `dashstyle` الخام إلى أرقام `[dash, gap, …]` مع تعويض امتداد الغطاء (`_compensateForCap`)
  - `lib/WordToWidget/VmlStrokeCapResolver` (داخل `VmlDashPatternResolver.dart`) — تحويل `endcap` VML → `StrokeCap` Flutter (الافتراضي `butt`)
  - `lib/WordToWidget/VmlLinePainter.dart` — `CustomPainter` لرسم خطوط VML (متصل أو متقطع)
  - `lib/WordToWidget/VmlTextBoxInsetResolver.dart` — تحويل `inset` الخام إلى `EdgeInsets` (كان مُكدّسًا داخل `VmlRendererWidget`)
  - `lib/WordToWidget/VmlRendererWidget.dart` — تجميع الشكل فقط، يفوّض الرسم والتحليل للملفات أعلاه
- **الأنماط المدعومة**:
  - رقمية مثل `"1 1"` أو `"4 2 1 2"` (الوحدة = `strokeWidth`)
  - مسماة: `dash`/`shortdash`, `dot`/`shortdot`, `dashdot`
- **تعويض الغطاء**: عندما `endcap=round` أو `square`، يُقصّر طول القطعة ويُوسّع الفراغ ليعوّض امتداد الغطاء خارج حدود القطعة
- لا تعدّل هذا المسار إلا إذا كانت المشكلة مرتبطة مباشرة برسم خطوط VML

### 13) زخارف `header` الـ VML يجب ألا تعيد تعريف بداية متن الصفحة
- **المشكلة**: بعض الصفحات ذات الهيدر الزخرفي كانت تظهر فيها بداية المتن منخفضة أكثر من Word، فيبدو وكأن الهيدر "ارتفع" أو أخذ مساحة إضافية
- **الجذر الحقيقي**:
  - كان `WordPageScreen.getSectionMargins()` يستخدم `max(headerHeight, topMargin)` ثم يضيف أحيانًا `framePadding`
  - هذا يجعل زخارف الهيدر المبنية من `w:pict`/`VML` تؤثر في `top` الخاص بالمتن
  - بينما في Word بداية متن الصفحة يحددها `w:pgMar/@w:top`، أما الهيدر فهو story مستقل ولا يجوز أن يرفع متن الصفحة لمجرد أن زخارفه أطول أو ذات إزاحات سالبة
- **الحل الصحيح الحالي**:
  - في `lib/UI/WordPageScreen.dart`
  - إذا كان الهيدر من النوع الزخرفي المعتمد على `VML` (`hasVmlFrameInHeader(...) == true`) فالهامش العلوي الفعال للمتن يبقى `topMargin` فقط
  - ولا يطبّق في هذه الحالة لا `headerHeight` ولا heuristic `framePadding` الخاص بالصور الخلفية الكبيرة
- **لماذا هذا محافظ**:
  - التعديل لا يغيّر رسم الهيدر نفسه
  - لا يغيّر مواضع عناصر `VML`
  - لا يعبث بحسابات الصفحات العادية
  - يقتصر فقط على منع خلط story الهيدر بمساحة متن الصفحة
- **قاعدة مهمة**:
  - لا تستخدم قياس ارتفاع الهيدر لتحديد بداية المتن في الصفحات ذات الهيدر الزخرفي
  - ابدأ أولًا من XML: هل الحالة `header` زخرفي مستقل، أم صورة/عنصر داخل متن الصفحة نفسه؟
- **محاولة مضللة يجب الحذر منها**:
  - إذا ظهر فرق عمودي قرب أعلى الصفحة، فلا تفترض مباشرة أن `headerMargin` أو `getHeaderHeight()` يجب زيادتهما
  - قد يكون العكس هو الصحيح: نحن نضيف تأثير الهيدر إلى المتن بينما Word لا يفعل ذلك في هذه الحالة

## كيف يعمل التطبيق باختصار

1. يقرأ XML الخاص بالمستند
2. يُقسَّم إلى صفحات وفقرات وruns
3. كل `Paragraph` تحلل:
   - `pPr`
   - `rPr`
   - runs
   - numbering
   - footnotes
   - hyperlinks
   - images
4. ثم يتحول ذلك إلى `InlineSpan`/`Widget` داخل Flutter
5. كثير من المشاكل تظهر بسبب الفروقات بين منطق WordprocessingML وطريقة Flutter في layout/BiDi/strut/widgets

## منهجية العمل

- لا تبدأ بالـ CSS أو بالمظهر أو بتقليل/زيادة بكسلات
- ابدأ من XML الفعلي للمشكلة
- افحص هل السلوك قادم من:
  - `paragraph properties`
  - `run properties`
  - `style inheritance`
  - `section settings`
  - `field code`
  - `numbering`
  - `footnotes`
  - `frame/layout behavior`
- عدّل بأقل نطاق ممكن
- إذا كان هناك منطق جديد كبير، انقله إلى ملف مستقل بدل تكديسه داخل `Paragraph.dart`
- لا تكثر من التعديلات الواسعة في الملفات المركزية إلا عند الضرورة
- اجعل أي تجربة جديدة قابلة للتراجع بسهولة
- ابدأ دائمًا بمراجعة الملفات ذات الصلة بالمشكلة الجديدة فقط، مع إبقاء ما سبق إصلاحه مستقرًا

## ملاحظة مهمة من إصلاح سابق

- إذا ظهرت مشكلة في `header/footer` أو `sectPr` وكان Word يعرض العنصر بينما التطبيق لا يعرضه، فلا تفترض مباشرة أن الخلل في `SectPr.dart` أو في منطق العرض.
- تحقق أولًا من اتساق ملفات OOXML بعد مرحلة المعالجة، خصوصًا التوافق بين:
  - `word/document.xml`
  - `word/_rels/document.xml.rels`
- السبب الذي انكشف سابقًا كان أن `document.xml` صار يحمل `rId` جديدة داخل `headerReference/footerReference` بينما بقي `document.xml.rels` بالقيم القديمة، فصار التطبيق يقرأ `sectPr` صحيحًا لكن يحلّ المراجع إلى targets خاطئة.
- هذا النوع من الأعطال قد يبدو ظاهريًا كأنه:
  - `No footer found`
  - أو `No header found`
  - أو paths غير منطقية مثل ربط footer بـ `header.xml` أو ربط header بصورة
- قبل تعديل منطق الأقسام أو `pageInSection` أو even/odd selection، افحص هل المشكلة أصلها عدم تزامن بين XML الأساسي وملف العلاقات.
- في مثل هذه الحالات، أصلح مرحلة المعالجة أولًا، لا طبقة العرض.

## ملفات XML تجريبية مفيدة

- `D:\ImportantProjects\golden_shamela\test_page_xml.xml`
- `D:\ImportantProjects\golden_shamela\test_header_xml.xml`
- `D:\ImportantProjects\golden_shamela\test_footer_xml.xml`
