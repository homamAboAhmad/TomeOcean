# قواعد مشروع Golden Shamela

## ⚠️ تحذيرات هامة جداً (اقرأ أولاً!)

1. **التطبيق دقيق جداً** - لا تغير الأشياء اعتباطياً لأنه قد يتضرر عرض باقي الكتب
2. **الحلول الترقيعية ممنوعة** - الحل الترقيعي يصلح كتاباً ويخرب عشرة غيره
3. **العرض يجب أن يطابق Word** - افهم كود XML وحوّله بدقة
4. **سيعرض عشرات آلاف الكتب** - الأداء والدقة أولوية قصوى
5. **التطبيق للويندوز حالياً**

### قيود معروفة | Known Limitations

#### 1. ترقيم الجداول عبر الصفحات | Table Numbering Across Pages
- الترقيم التلقائي في الجداول يُعاد تعيينه لكل صفحة بدلاً من الاستمرار
- مثال: الصفحة 1 تعرض 1-5، الصفحة 2 تعرض 1-5 بدلاً من 6-10
- راجع: `.agent/table_styling_fix_session.md`

#### 2. تظليل الأنماط الشرطية للجداول | Table Style Conditional Shading
- تظليل الصف الأول (firstRow) والعمود الأول (firstCol) من أنماط الجدول قد لا يظهر بشكل كامل
- يتطلب تتبع موقع الخلية بالنسبة للجدول

#### 3. النص العريض في بعض الجداول | Bold Text in Some Tables
- النص العريض قد لا يظهر بشكل صحيح في بعض خلايا الجداول
- يحتاج تحقيق

---

## 📚 الوثائق المرجعية (في `.agent/`)

| الملف | المحتوى |
|-------|---------|
| `project_knowledge.md` | **مرجع رئيسي** - البنية، Headers/Footers، ترقيم الصفحات، Z-Order |
| `warnings.md` | التحذيرات والقيود المعروفة |
| `workflows/project_workflows.md` | سير العمل والإجراءات |
| `line_spacing_fix_and_learnings.md` | حلول تباعد الأسطر |
| `table_pagination_fix_session.md` | حلول تجزئة الجداول |
| `table_styling_fix_session.md` | حلول تنسيق الجداول |
| `footer_page_number_fix_session.md` | حلول ترقيم الصفحات |
| `matrix4_and_padding_fix.md` | حلول أخطاء Matrix4 والـ padding |

**Word XML Documentation:**
- `WordXmlDoumentation/key_sections.txt`
- `WordXmlDoumentation/extracted_reference.txt`

**⚡ مهم:** استشر هذه الوثائق دائماً قبل تنفيذ ميزات Word-related!

---

## 🎨 الأسلوب والتصميم

### واجهة المستخدم
- **اتجاه التطبيق**: RTL (من اليمين لليسار)
- **اللغة الأساسية**: العربية
- **الخط الرئيسي**: `jreg`
- **التصميم**: احترافي، سهل الاستخدام، يناسب باقي شاشات التطبيق

### دوال التنسيق
```dart
normalStyle()    // للنصوص العادية
bigStyle()       // للعناوين الكبيرة
defaultAppBar()  // شريط التطبيق الافتراضي
normalBtn()      // الأزرار العادية
```

### الألوان
- استخدم الألوان من `lib/Styles/MyColors.dart`
- راجع `lib/Styles/AppResourses.dart` و `lib/Styles/TextSyles.dart`

---

## 💻 أسلوب الكود

- ✅ **كود نظيف ومنظم**
- ✅ **Helper Widgets** - استخدم pattern مثل `_buildStatItem` لتقليل التكرار
- ✅ **التعليقات بالعربية** عند الحاجة
- ❌ **لا placeholders** - أنشئ محتوى حقيقي
- ❌ **لا debug prints** - احذفها قبل الانتهاء

---

## ⚠️ ملاحظات مهمة

1. **التحديد النصي**: يستخدم التطبيق `SelectableText.rich` مع `CustomTextSelectionControls` - التحديد محدود بالفقرة الواحدة
2. **الخطوط القديمة**: هناك معالجة خاصة للخطوط العربية القديمة عبر GDI
3. **الـ Caching**: التطبيق يستخدم caching للصفحات المحللة

---

## 📋 قائمة مراجعة قبل الانتهاء

- [ ] إزالة جميع `debugPrint` و `print` statements
- [ ] التحقق من عدم وجود أخطاء compilation
- [ ] اختبار RTL layout
- [ ] اختبار على محتوى عربي حقيقي
