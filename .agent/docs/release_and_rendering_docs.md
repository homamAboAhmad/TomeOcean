# Golden Shamela - Technical Documentation
## Rendering Engine & Release Engineering

**Version**: 1.0
**Last Updated**: 2026-01-29
**Scope**: Vector Graphics, Group Images, Release Deployment, and External Tools.

---

## 1. محرك العرض (Rendering Engine)

تم إجراء تحديثات جوهرية على محرك تحويل ملفات Word (OpenXML) إلى واجهات Flutter لدعم الأشكال المعقدة وحل مشاكل التنسيق في البيئات العربية (RTL).

### 1.1 دعم الأشكال المتجهة (Vector Shapes)

في السابق، كان التطبيق يتجاهل عناصر الرسم المتجه (`wps:wsp` و `a:path`)، مما يؤدي إلى ظهور مساحات فارغة عند وجود رسومات مثل الخطوط الزخرفية أو الأشكال الهندسية.

#### 1.1.1 تحليل المسارات (`VectorPathParser.dart`)
تم إنشاء محلل متخصص (`VectorPathParser`) لتحويل وصف المسار في XML (شبيه بـ SVG Path Data) إلى كائن `Path` في Flutter.

**آلية العمل:**
1.  **استخراج الأبعاد الأصلية (Coordinate System):**
    يحدد OpenXML نظام إحداثيات افتراضي لكل شكل عبر `w` و `h` في عنصر `a:path`.
    ```xml
    <a:path w="21600" h="21600"> ... </a:path>
    ```
    يتم استخدام هذه القيم لحساب معامل التحجيم (`Scale Factor`) لتحويل النقاط إلى بكسلات الشاشة.

2.  **تحليل أوامر الرسم:**
    يتم المرور على العناصر الفرعية لـ `pathLst` وتحويلها:
    *   `a:moveTo`: نقل "القلم" إلى نقطة بداية (`path.moveTo`).
    *   `a:lnTo`: رسم خط مستقيم (`path.lineTo`).
    *   `a:cubicBezTo`: رسم منحنى بيزيه مكعب يتطلب 3 نقاط (نقطتي تحكم ونقطة نهاية) -> (`path.cubicTo`).
    *   `a:quadBezTo`: منحنى تربيعي -> (`path.quadraticBezierTo`).
    *   `a:close`: إغلاق المسار (`path.close`).

**تحدي الوحدات (EMA vs Pixels):**
وحدات OpenXML الداخلية هي EMUs (English Metric Units)، حيث `1 inch = 914400 EMU`.
في `ImageParser.dart`، يتم تحويل هذه الوحدات إلى بكسلات (Pixels) قبل تمريرها للرسم:
```dart
// 9525 EMUs = 1 Pixel (تقريباً)
childImage.width = (int.tryParse(cx) ?? 0) / 9525.0;
```

#### 1.1.2 الرسم (`VectorShapeWidget.dart`)
يتم استخدام `CustomPainter` لرسم المسار المحلل على الـ Canvas.
*   **Fill (التعبئة):** يتم رسمها أولاً باستخدام `PaintingStyle.fill`.
*   **Stroke (الحدود):** ترسم فوق التعبئة باستخدام `PaintingStyle.stroke` مع دعم خصائص `strokeWidth` و `strokeCap`.
*   **Optimization:** يتم استخدام `shouldRepaint` للتأكد من عدم إعادة الرسم إلا عند تغير المسار أو الألوان.

---

### 1.2 معالجة مجموعات الصور (Group Images)

تواجه التطبيقات العربية التي تستخدم `Directionality(textDirection: TextDirection.rtl)` مشكلة جوهرية عند عرض المخططات المعقدة من Word.

#### 1.2.1 المشكلة: تعارض المحاور (Coordinate Failure)
*   **Word (OpenXML):** يستخدم دائماً نظام إحداثيات يبدأ من الزاوية **اليسرى العليا** (LTR)، حيث `x` تزيد باتجاه اليمين.
*   **Flutter (RTL):** عنصر `Stack` في وضع RTL يقوم بعكس المحور الأفقي، بحيث تصبح `left` هي مسافة من اليمين، أو يتم عكس ترتيب العناصر.
*   **النتيجة:** تظهر الصور المجمعة (Groups) مكدسة فوق بعضها أو مبعثرة بشكل معكوس.

#### 1.2.2 الحل: العزل الاتجاهي (`GroupImageWidget.dart`)
تم حل المشكلة عبر عزل مكون عرض المجموعة عن الاتجاه العام للتطبيق.

**التنفيذ التقني:**
```dart
return Container(
  width: groupWidth,
  height: groupHeight,
  // فرض اتجاه LTR داخل الحاوية فقط
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      clipBehavior: Clip.none, 
      children: children // الصور الداخلية
    ),
  ),
);
```
بهذا، عندما يحدد ملف Word أن الصورة "أ" تقع عند `x=100`، سيفهم Flutter ذلك كـ "100 بكسل من اليسار" كما هو مقصود، متجاهلاً كون التطبيق عربيًا بالكامل.

#### 1.2.3 الاستخراج (`ImageParser.dart`)
تم تحديث `ImageData` لدعم بنية شجرية بسيطة:
*   `isGroup`: علم (Flag) يشير إلى أن الكائن حاوية.
*   `groupImages`: قائمة من كائنات `ImageData` الفرعية.
*   يتم استخراج إزاحة المجموعة (`a:off`) وأبعادها (`a:ext`) لمعالجة التموضع النسبي للأبناء.

---

## 2. هندسة الإصدار (Release Engineering)

يتطلب التطبيق أدوات خارجية لمعالجة ملفات Word المعقدة التي لا تستطيع مكتبات Dart معالجتها بكفاءة كاملة (مثل إعادة ترقيم الصفحات Repagnation).

### 2.1 الأدوات الخارجية (Python Tools)

#### 2.1.1 `pageRender.exe`
أداة هجينة لحساب أرقام الصفحات، حيث أن ملفات `docx` لا تخزن أرقام الصفحات بل تحسبها ديناميكياً عند العرض (Flow Document).

**مراحل العمل (`scripts/pageRender.py`):**
1.  **COM Automation:**
    *   تقوم بفتح نسخة خفية من MS Word (`win32com`).
    *   تستدعي دالة `doc.Repaginate()` لإجبار Word على حساب فواصل الصفحات.
    *   تستخدم `Active Tagging`: حقن إشارات مرجعية (Bookmarks) باسم `ShamelaPage_X` في بداية كل صفحة.
2.  **XML Processing:**
    *   بعد إغلاق Word، يتم فك ضغط ملف `.docx` (لأنه ZIP).
    *   قراءة `word/document.xml`.
    *   البحث عن الـ Bookmarks المحقونة.
    *   إدخال عنصر نصي مخفي `{{PG:X}}` (Run with Vanish property) في موقع الـ Bookmark.
    *   إعادة ضغط الملف.

**الفائدة:** يحصل Flutter على ملف `docx` يحتوي على علامات صفحات جاهزة يمكنه قراءتها وعرضها كأرقام صفحات دون الحاجة لمحرك Layout معقد.

#### 2.1.2 `fix_word_images.exe`
أداة لمعالجة روابط الصور المكسورة (Broken Relationships) التي تحدث أحياناً عند تحويل الملفات أو حفظها ببرامج غير متوافقة تماماً. تقوم بفحص `word/_rels/document.xml.rels` وإصلاح المسارات.

---

### 2.2 مشاكل وحلول الإصدار (Release Challenges)

أثناء بناء نسخة Release لنظام Windows، واجهنا وعالجنا المشاكل الحرجة التالية:

#### 2.2.1 مشكلة الترميز (Unicode Encode Error)
**المشكلة:**
عند تشغيل `pageRender.exe` على ملفات بأسماء عربية، ينهار التطبيق فوراً.
السبب: `console` في Windows يستخدم ترميز `cp1252` بشكل افتراضي، مما يفشل عند طباعة مسارات الملفات العربية (`UnicodeEncodeError`).

**الحل الجذري:**
تم فرض استخدام `UTF-8` لمخرجات الـ Stdout/Stderr داخل كود Python مباشرة عبر تغليف الـ Buffer:
```python
import io, sys
if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except Exception as e:
        pass
```
هذا يضمن أن التطبيق يعمل بسلام حتى لو كان اسم الملف يحتوي على رموز أو حروف عربية.

#### 2.2.2 المسارات المفقودة (Path Not Found)
**المشكلة:**
أداة `pageRender` كانت تفشل إذا لم يكن مجلد المخرجات (`temp_test_output` مثلاً) موجوداً مسبقاً.
**الحل:**
إضافة منطق التحقق والإنشاء التلقائي (`os.makedirs(..., exist_ok=True)`) في بداية السكربت.

#### 2.2.3 إدارة الملفات التنفيذية (Executable Management)
في نسخة الـ Release، يتم تجميع ملفات التطبيق في بنية مختلفة عن بيئة التطوير.

**استراتيجية النشر (`Deployment Strategy`):**
1.  **مكان التخزين:** توضع الملفات التنفيذية (`.exe`) داخل مجلد `assets/exe` كأصول ثابتة.
2.  **عند التشغيل (`ExeRunner.dart`):**
    *   يقوم التطبيق بنسخ الـ `.exe` من الأصول إلى مجلد النظام المؤقت (`%TEMP%`).
    *   **تحديث إجباري:** تم تعديل الكود ليقوم **بإعادة النسخ دائماً** (Overwrite) عند كل تشغيل.
    *   *السبب:* إذا قمنا بتحديث التطبيق بنسخة جديدة من `pageRender.exe`، لن يستفيد المستخدم منها إذا كان الكود يستخدم النسخة القديمة الموجودة في `Temp`. التحديث الإجباري يضمن استخدام أحدث نسخة دائماً.

**البحث عن المسار (`BookProcessingService.dart`):**
لضمان المرونة، يبحث التطبيق عن الأدوات في عدة أماكن بالتسلسل:
1.  بجانب الملف التنفيذي الرئيسي (`Configurable`).
2.  داخل مجلد `dist` (بيئة تطوير).
3.  داخل `scripts` (بيئة تطوير).
4.  داخل `data/flutter_assets/assets/exe/` (**المسار المعتمد للـ Release**).

---

### 2.3 دليل البناء (Build Guide)

لإنشاء نسخة جاهزة للنشر، اتبع الخطوات التالية بدقة:

#### الخطوة 1: بناء أدوات Python
تأكد من تثبيت `pyinstaller`:
```bash
pip install pyinstaller lxml psutil pywin32
```
ثم قم ببناء الملفين:
```powershell
python -m PyInstaller scripts\pageRender.spec
python -m PyInstaller scripts\fix_word_images.spec
```
سيتم إنشاء الملفات في مجلد `dist\`.

#### الخطوة 2: تحديث الأصول (Assets)
انسخ الملفات الناتجة من `dist\` إلى مجلد أصول المشروع لتضمينها في البناء القادم:
```powershell
copy /Y dist\pageRender.exe assets\exe\
copy /Y dist\fix_word_images.exe assets\exe\
```

#### الخطوة 3: بناء تطبيق Flutter
قم بتنظيف المشروع وبناء النسخة النهائية:
```powershell
flutter clean
flutter pub get
flutter build windows --release
```

#### الخطوة 4: التجميع النهائي (Post-Build)
بعد انتهاء البناء، اذهب إلى المجلد الناتج:
`build\windows\x64\runner\Release\`
تأكد من وجود الملفات التالية في المسار `data\flutter_assets\assets\exe\`:
*   `pageRender.exe`
*   `fix_word_images.exe`

إذا لم تكن موجودة (لسبب ما في إعدادات pubspec)، يجب نسخها يدوياً لضمان عمل التطبيق.

---

### 3. الخلاصة
تضافرت هذه الجهود لتحويل تطبيق "الشاملة الذهبية" من مجرد عارض نصوص بسيط إلى قارئ مستندات متطور قادر على:
1.  عرض الرسومات الهندسية المعقدة (Vector Shapes).
2.  الحفاظ على تنسيق المخططات الانسيابية ومجموعات الصور رغم بيئة RTL.
3.  التعامل الذكي مع محركات Word الخارجية ومعالجة أخطاء الترميز بشكل صامت لضمان تجربة مستخدم سلسة.
