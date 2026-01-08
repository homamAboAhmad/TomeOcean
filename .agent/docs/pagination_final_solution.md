# الحل النهائي لترقيم الصفحات

**آخر تحديث:** 2026-01-08

## الحل المُعتمد: VBA + lxml

### الملف الرئيسي
`scripts/pageRender.py`

### آلية العمل

```
1. Word يفتح المستند ويحسب التخطيط (Repaginate)
2. VBA Macro يجمع رقم الصفحة لكل فقرة
3. lxml يحقن markers {PG:X} في XML
4. الملف يُحفظ بشكل صحيح
```

### لماذا VBA؟

| الطريقة | المشكلة |
|---------|---------|
| عد فواصل XML | بطيء + غير دقيق + الأخطاء تتراكم |
| **VBA** | سريع + كل فقرة مستقلة + دقيق |

### لماذا lxml؟

| المكتبة | المشكلة |
|---------|---------|
| xml.etree.ElementTree | يُغير namespaces → "محتوى غير قابل للقراءة" |
| **lxml** | يحافظ على namespaces |

## المتطلبات

```bash
pip install lxml
```

**في Word:**
- File → Options → Trust Center → Trust Center Settings
- Macro Settings → ✓ Trust access to VBA project

## الاستخدام

```bash
python scripts/pageRender.py "books_folder" "input.docx"
```

**الخرج:**
```
STATUS:صفحات Word الأصلية: 27
STATUS:أقصى صفحة VBA: 27
STATUS:✓ تطابق تام!
SUCCESS
```

## تطبيق Flutter

الـ markers `{PG:X}` يُقرأون في:
- `lib/wordToHTML/runT.dart` أو
- `lib/wordToHTML/Paragraph.dart`

يجب التأكد من:
1. قراءة الـ marker بشكل صحيح
2. تقسيم الصفحات بناءً على تغير رقم الصفحة
