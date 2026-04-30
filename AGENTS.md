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
