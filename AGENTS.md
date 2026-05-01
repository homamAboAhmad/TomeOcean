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
