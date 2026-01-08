# 📚 معمارية معالجة الكتب - golden_shamela

## نظرة عامة

```mermaid
flowchart TD
    A[ملف .docx] --> B[BookProcessingService]
    B --> C[ExeRunner]
    C --> D[pageRender.py]
    D --> E[ملف معالج مع {{PG:X}}]
    E --> F[Paragraph.fromXml]
    F --> G[WordPage مع pageNum]
    G --> H[العرض في التطبيق]
```

---

## 1️⃣ نقطة الدخول: BookProcessingService

📁 **المسار:** `lib/Services/BookProcessingService.dart`

### مراحل المعالجة (ProcessingState):

| المرحلة | الوصف | النسبة |
|---------|-------|--------|
| `preparing` | تجهيز الملف والتحقق من الصيغة | 0% |
| `rendering` | تشغيل pageRender.py وحقن أرقام الصفحات | 10-20% |
| `fixingImages` | إصلاح الصور المعطوبة | 20-30% |
| `parsing` | تحليل XML وبناء WordDocument | 30-80% |
| `caching` | حفظ الصفحات كـ JSON.gz | 80-90% |
| `indexing` | بناء فهرس البحث FTS5 | 90-100% |
| `completed` | ✅ انتهت المعالجة | 100% |

### الكود الرئيسي:

```dart
// L172: استدعاء pageRender
await ExeRunner().runExe(BOOKS_FOLDER_PATH, sourceFilePath, (output) {
  // معالجة مخرجات Python
});

// L219: تحليل المستند
List<WordPage> parsedPages = await AddDocData(...);

// L248: الفهرسة
await indexer.indexBookFromPages(finalBookPath, pages, ...);
```

---

## 2️⃣ ExeRunner - تشغيل pageRender

📁 **المسار:** `lib/Helpers/ExeRunner.dart`

### إعدادات التطوير/الإنتاج:

```dart
// L11: التحكم في وضع التشغيل
static const bool USE_PYTHON = true;  // ← للتطوير

// L12-13: مسار سكربت Python
static const String PYTHON_SCRIPT =
    r'd:\ImportantProjects\golden_shamela\scripts\pageRender.py';
```

### آلية التشغيل:

```dart
if (USE_PYTHON) {
  // وضع التطوير: Python مباشرة
  process = await Process.start('python', [
    PYTHON_SCRIPT,   // scripts/pageRender.py
    outputFolder,    // BOOKS_FOLDER_PATH
    inputFile,       // المسار الكامل للملف
  ], runInShell: true);
} else {
  // وضع الإنتاج: exe مُجمّع
  final exePath = await copyExeIfNeeded();
  process = await Process.start(exePath, [...]);
}
```

---

## 3️⃣ pageRender.py - حقن أرقام الصفحات

📁 **المسار:** `scripts/pageRender.py`

### آلية العمل:

```
1. فتح المستند في Word (COM)
2. تشغيل VBA Macro للحصول على أرقام الصفحات
3. فك ضغط .docx وقراءة document.xml
4. حقن {{PG:X}} كـ hidden run في كل فقرة
5. إعادة ضغط الملف
```

### VBA Macro (L33-51):

```vba
Public Function GetAllPageNumbers() As String
    For Each para In ActiveDocument.Content.Paragraphs
        Set rng = para.Range.Duplicate
        rng.Collapse wdCollapseStart
        result = result & rng.Information(wdActiveEndPageNumber) & ","
    Next
    GetAllPageNumbers = result
End Function
```

### حقن الـ Marker (L398):

```python
hidden_run = create_hidden_run_element(f"{{{{PG:{page_num}}}}}")
# ينتج: <w:r><w:rPr><w:vanish/></w:rPr><w:t>{{PG:5}}</w:t></w:r>
```

---

## 4️⃣ Paragraph.dart - قراءة أرقام الصفحات

📁 **المسار:** `lib/wordToHTML/Paragraph.dart`

### استخراج الـ Marker (L213-227):

```dart
// البحث عن {{PG:X}} في نص الـ run
if (runt0.text != null && runt0.text!.contains("{{PG:")) {
  final RegExp pgRegex = RegExp(r"\{\{PG:(\d+)\}\}");
  final match = pgRegex.firstMatch(runt0.text!);
  if (match != null) {
    String? pageStr = match.group(1);
    if (pageStr != null) {
      pageNum = pageStr;  // تعيين رقم الصفحة
      runt0.text = runt0.text!.replaceAll(match.group(0)!, "");  // إزالة من العرض
    }
  }
}
```

### الحماية من الإزالة (L1278-1289):

```dart
getPageNum() {
  // لا تُعدّل pageNum إذا تم تعيينها من {{PG:X}}
  if (pageNum.isNotEmpty) return;
  // ... fallback logic
}
```

---

## 5️⃣ WordUtils.dart - تقسيم الجداول

📁 **المسار:** `lib/Utils/WordUtils.dart`

### قراءة رقم الصفحة من صف الجدول (L373-383):

```dart
int? _getRowPageNum(XmlElement row) {
  var firstCellText = allCells.first.text;
  var match = RegExp(r"\{\{PG:(\d+)\}\}").firstMatch(firstCellText);
  if (match != null) {
    return int.parse(match.group(1)!);
  }
  return null;
}
```

---

## 6️⃣ runT.dart - إخفاء الـ Markers

📁 **المسار:** `lib/wordToHTML/runT.dart`

### تخطي النص المخفي (L142-146):

```dart
InlineSpan toWidget() {
  // تخطي النص المخفي (مثل {{PG:X}})
  if (rpr?.vanish == true) {
    return TextSpan(text: "");
  }
  // ...
}
```

---

## 🔄 تدفق البيانات الكامل

```
┌────────────────────────────────────────────────────────────────┐
│                         pageRender.py                          │
│  VBA: Para[0]=1, Para[1]=1, Para[2]=2, ...                    │
│  XML: حقن <w:r><w:vanish/><w:t>{{PG:1}}</w:t></w:r>           │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                      ملف .docx المعالج                         │
│  <w:p>                                                         │
│    <w:pPr>...</w:pPr>                                         │
│    <w:r><w:rPr><w:vanish/></w:rPr><w:t>{{PG:1}}</w:t></w:r>  │← Hidden
│    <w:r><w:t>النص الفعلي</w:t></w:r>                          │
│  </w:p>                                                        │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                     Paragraph.fromXml()                        │
│  1. يقرأ run الأول ويجد {{PG:1}}                              │
│  2. يستخرج الرقم: pageNum = "1"                               │
│  3. يحذف الـ marker من النص                                   │
│  4. vanish=true يمنع العرض                                    │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                        WordPage                                │
│  ps: [Paragraph(pageNum="1"), Paragraph(pageNum="1"), ...]    │
└────────────────────────────────────────────────────────────────┘
```

---

## 📋 ملخص الملفات

| الملف | الوظيفة |
|-------|---------|
| `BookProcessingService.dart` | تنسيق كامل المعالجة |
| `ExeRunner.dart` | تشغيل Python/EXE |
| `pageRender.py` | حقن `{{PG:X}}` |
| `Paragraph.dart` | قراءة `{{PG:X}}` |
| `WordUtils.dart` | تقسيم الجداول |
| `runT.dart` | إخفاء المخفي |
| `RPr.dart` | كشف `<w:vanish>` |
