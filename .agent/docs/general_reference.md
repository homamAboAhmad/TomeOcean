# Word Open XML (DOCX) References / مراجع وورد أوبن إكس إم إل

This document lists authoritative and practical references for Word Open XML.
هذا المستند يسرد المراجع الرسمية والعملية لتنسيق Word Open XML.

---

## 1. Official Standards / المعايير الرسمية

The core "source of truth". Essential for definitions, but difficult to learn from directly.
المصدر الأساسي "للحقيقة". ضروري للتعاريف الدقيقة، ولكنه صعب للتعلم منه مباشرة.

### **ECMA-376 (Office Open XML File Formats)**
*   **Description:** The original standard. Part 1 (Fundamentals) is the most critical.
*   **الوصف:** المعيار الأصلي. الجزء الأول (الأساسيات) هو الأكثر أهمية.
*   **Status in your project / حالته في مشروعك:**
    *   You have "Ecma Office Open XML Part 1" in `WordXmlDoumentation`. This is the **correct and best** official reference for markup.
    *   لديك ملف "Ecma Office Open XML Part 1" في مجلد `WordXmlDoumentation`. هذا هو المرجع الرسمي **الصحيح والأفضل** لتكوين المستند.
*   **Link / رابط:** [Ecma International - Standard ECMA-376](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/)

### **ISO/IEC 29500**
*   **Description:** The international standardization (very similar to ECMA-376). Microsoft Office 2013+ follows "ISO/IEC 29500 Strict".
*   **الوصف:** المعيار الدولي (مشابه جداً لـ ECMA-376). مايكروسوفت أوفيس 2013 وما بعده يتبع "ISO/IEC 29500 Strict".
*   **Link / رابط:** [ISO Publicly Available Standards](https://standards.iso.org/ittf/PubliclyAvailableStandards/index.html)

---

## 2. Practical Developer Guides (Better for Learning) / أدلة التطوير العملية (أفضل للتعلم)

These resources are often **better than the standard** for understanding *how* to implement features and avoiding bugs.
هذه الموارد غالباً ما تكون **أفضل من المعيار الرسمي** لفهم *كيفية* تنفيذ الميزات وتجنب الأخطاء.

### **Eric White's Blog (The "Bible" of Open XML)**
*   **Why it's important:** Eric White is a legendary figure in this space. His blog explains *logic* and *algorithms* (e.g., how to accept changes, how to interpret styles) which the standard doesn't explain.
*   **لماذا هو مهم:** إريك وايت شخصية أسطورية في هذا المجال. مدونته تشرح *المنطق* و *الخوارزميات* (مثل كيفية قبول التغييرات، كيفية تفسير الأنماط) التي لا يشرحها المعيار الرسمي.
*   **Archives / الأرشيف:** [Eric White's Open XML Blog](http://ericwhite.com/blog/category/open-xml/)

### **Microsoft Open XML SDK Documentation**
*   **Why it's important:** It maps the XML elements to programming classes. It often has clearer examples than the raw standard.
*   **لماذا هو مهم:** يربط عناصر XML بفئات برمجية. غالباً ما يحتوي على أمثلة أوضح من المعيار الخام.
*   **Link / رابط:** [Open XML SDK Documentation](https://learn.microsoft.com/en-us/office/open-xml/open-xml-sdk)

### **OfficeOpenXML.com (Unofficial)**
*   **Why it's important:** A user-friendly, browsable reference. Great for quickly checking "what attributes does `<w:pPr>` have?".
*   **لماذا هو مهم:** مرجع سهل التصفح وسهل الاستخدام. ممتاز للتحقق السريع "ما هي خصائص `<w:pPr>`؟".
*   **Link / رابط:** [http://officeopenxml.com/](http://officeopenxml.com/)

---

## 3. Common Pitfalls & Warnings / الأخطاء الشائعة والتحذيرات

You asked for warnings that might be missed in the standard. Here are the most critical ones for a renderer:
سألت عن التحذيرات التي قد تفوتك في المعيار. إليك أهمها بالنسبة لمشروع عرض (Renderer):

### **A. Memory vs. Speed (DOM vs. SAX) / الذاكرة مقابل السرعة**
*   **Warning:** Loading a whole document into memory (DOM) crashes with large documents.
*   **التحذير:** تحميل مستند كامل في الذاكرة (DOM) يؤدي إلى توقف التطبيق مع المستندات الكبيرة.
*   **Advice:** Use streaming approach (SAX) for reading text if possible, or careful memory management.
*   **النصيحة:** استخدم أسلوب التدفق (SAX) لقراءة النص إن أمكن، أو إدارة دقيقة للذاكرة.

### **B. Field Codes are Complex / رموز الحقول معقدة**
*   **Warning:** Page numbers and links are often NOT simple text. They are calculated fields (`PAGE`, `HYPERLINK`).
*   **التحذير:** أرقام الصفحات والروابط غالباً ليست نصوصاً بسيطة. هي حقول محسوبة (`PAGE`، `HYPERLINK`).
*   **Pitfall:** You must parse `w:instrText` to support these features.
*   **المأزق:** يجب عليك تحليل `w:instrText` لدعم هذه الميزات.

### **C. Rendering Fidelity is Impossible / تطابق العرض مستحيل**
*   **Warning:** Even Google Docs and Apple Pages cannot render DOCX 100% like Word.
*   **التحذير:** حتى Google Docs و Apple Pages لا يمكنهما عرض DOCX بنسبة 100% مثل Word.
*   **Advice:** Aim for "good enough" for reading, not pixel-perfect layout.
*   **النصيحة:** استهدف "جودة مقبولة" للقراءة، وليس تخطيطاً دقيقاً بالبكسل.
