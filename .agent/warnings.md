ملاحظات وتحذيرات:
التطبيق دقيق جداً لذا تغير فيه الأشياء اعتباطياً لأنه بذلك قد يتضرر العرض باقي الكتب
التطبيق يعمل ومخصص للويندوز حاليا
التطبيق سيعرض عشرات آلاف الكتب
يجب أن تكون طريقة العرض مطابقة لبرنامج الوورد يعني يفهم كود الxml الخاص بالملف ويحول ليعرض في التطبيق كما تعرضه الوورد
الحلول الترقيعية لا تنفع، لأن الحل الترقيعي يصلح كتابا ويخرب عرض عشرة غيره

---

## Known Limitations | قيود معروفة

### 1. Table Numbering Across Pages | ترقيم الجداول عبر الصفحات
- الترقيم التلقائي في الجداول يُعاد تعيينه لكل صفحة بدلاً من الاستمرار
- مثال: الصفحة 1 تعرض 1-5، الصفحة 2 تعرض 1-5 بدلاً من 6-10
- راجع: `.agent/table_styling_fix_session.md`

### 2. Table Style Conditional Shading | تظليل الأنماط الشرطية للجداول
- تظليل الصف الأول (firstRow) والعمود الأول (firstCol) من أنماط الجدول قد لا يظهر بشكل كامل
- يتطلب تتبع موقع الخلية بالنسبة للجدول

### 3. Bold Text in Some Tables | النص العريض في بعض الجداول
- النص العريض قد لا يظهر بشكل صحيح في بعض خلايا الجداول
- يحتاج تحقيق



The app is very precise - don't change things arbitrarily
The app is for Windows
Will display tens of thousands of books
Display should match Word exactly - understand the XML and convert it properly
No patchy solutions - fixing one book shouldn't break ten others