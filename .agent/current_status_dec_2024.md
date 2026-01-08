# Golden Shamela - Current Project Status & Working Protocols
# الشاملة الذهبية - حالة المشروع الحالية وبروتوكولات العمل

---

## Date | التاريخ
**December 25, 2024** | **25 ديسمبر 2024**

---

## Project Overview | نظرة عامة على المشروع

### English
**Golden Shamela** is a premium Islamic digital library application built with Flutter Desktop (Windows). It is designed to render `.docx` files with exceptional fidelity to Microsoft Word's original formatting, with particular emphasis on Arabic text, complex Islamic typography, and scholarly apparatus (footnotes, headers, page numbering).

The application has evolved into a sophisticated document management system with:
- **Multi-book tab management** (open, close, reorder books)
- **Advanced FTS5-based search engine** with morphological (root-based) Arabic search
- **Premium UI/UX** with RTL-first design philosophy
- **Accurate Word document rendering** (tables, images, TextBoxes, headers/footers)

### العربية
**الشاملة الذهبية** هو تطبيق مكتبة إسلامية رقمية فاخر مبني بـ Flutter Desktop (ويندوز). مصمم لعرض ملفات `.docx` بدقة استثنائية مطابقة لتنسيق Microsoft Word الأصلي، مع التركيز على النص العربي، والطباعة الإسلامية المعقدة، والجهاز العلمي (الحواشي، الرؤوس، ترقيم الصفحات).

تطور التطبيق ليصبح نظام إدارة مستندات متطور يتضمن:
- **إدارة تبويبات متعددة للكتب** (فتح، إغلاق، إعادة ترتيب الكتب)
- **محرك بحث متقدم يعتمد على FTS5** مع بحث صرفي (جذري) عربي
- **واجهة مستخدم فاخرة** بفلسفة تصميم RTL أولاً
- **عرض دقيق لمستندات Word** (جداول، صور، مربعات نص، رؤوس/تذييلات)

---

## Recent Technical Achievements | الإنجازات التقنية الأخيرة

### 1. Reader UI Polish | تلميع واجهة القارئ
| Feature | Status | Description |
|---------|--------|-------------|
| Top Toolbar RTL | ✅ Complete | Navigation buttons follow Arabic reading order |
| Bottom Toolbar History | ✅ Complete | Previous/Next visited pages with correct arrow logic |
| Book Tabs Rendering | ✅ Complete | Fixed clipping, improved font rendering with Amiri |
| Window Size Optimization | ✅ Complete | Increased initial window from 1280×720 to 1536×864 |

### 2. Multi-field Search Engine | محرك البحث متعدد الحقول
| Feature | Status | Description |
|---------|--------|-------------|
| AND/OR/NOT Groups | ✅ Complete | Advanced boolean search with multiple input groups |
| Morphological Search | ✅ Complete | Root-based Arabic word matching |
| Section Filtering | ✅ Complete | Search in main text, footnotes, headings separately |
| Search Results UI | ✅ Complete | Premium result cards with highlighted snippets |

### 3. Search Highlighting System | نظام تمييز البحث
| Feature | Status | Description |
|---------|--------|-------------|
| Snippet Highlighting | ✅ Complete | Yellow background for matched words in results |
| Page Content Highlighting | ⚠️ Partial | Terms highlighted when navigating from search |
| Smart Snippet Extraction | ✅ Complete | Context-aware cropping around matched terms |
| Exact Match Priority | ✅ Complete | Literal matches prioritized over root matches |

---

## Known Issues & Technical Debt | المشاكل المعروفة والديون التقنية

### 1. Search Snippet Truncation | اقتطاع مقاطع البحث
**Status:** 🔴 In Progress (Deferred)  
**Problem:** When multiple paragraphs match on a single page, `GROUP_CONCAT` in SQLite may truncate long combined content, causing some search terms to be missing from displayed snippets.  
**Attempted Solutions:**
- Increased `group_concat_max_len` PRAGMA
- Implemented Two-Step Query (page identification → content fetch)
- Manual aggregation in Dart

**Current State:** The Two-Step Query approach is implemented in `database_queries.dart` but requires further testing. The user has requested to defer this work.

### 2. Page Highlight Missing Terms | كلمات مفقودة في تمييز الصفحة
**Related to #1:** If the search term was in a paragraph that got truncated in the database response, it won't appear highlighted on the actual page when navigated to.

---

## New Working Protocol | بروتوكول العمل الجديد

### Philosophy Shift | تحول الفلسفة
**From:** Trial and Error (تجربة وخطأ)  
**To:** Verified Delivery (تسليم موثق)

### Multi-Role Execution | التنفيذ بتعدد الأدوار

When tackling complex features, the agent should assume multiple roles:

| Role | Responsibility |
|------|----------------|
| **Knowledge Management Specialist** | Document project evolution and context |
| **Senior Project Architect** | Summarize technical journey and architecture |
| **Systems Librarian** | Organize files within directory structure |
| **QA Engineer** | Internal testing before delivery |

### Mandatory Verification Report | تقرير التحقق الإلزامي

**Before delivering any code change, provide:**

```markdown
## Internal Verification Report

### 1. Changes Made
- [List of files modified]

### 2. Testing Performed
- [ ] Syntax/Compilation check
- [ ] Hot reload/restart successful
- [ ] Feature manually verified
- [ ] Edge cases considered

### 3. Known Limitations
- [Any caveats or remaining issues]

### 4. Rollback Plan
- [How to revert if needed]
```

---

## Key Files Reference | مرجع الملفات الرئيسية

### Search System
| File | Purpose |
|------|---------|
| `lib/Helpers/search_engine/database_queries.dart` | FTS5 queries, pagination, aggregation |
| `lib/UI/Search/helpers/search_highlighting_helper.dart` | Snippet extraction and highlighting |
| `lib/UI/Search/helpers/search_executor.dart` | Search execution orchestration |
| `lib/core/app_state.dart` | Global state including `searchHighlightTerms` |
| `lib/wordToHTML/runT.dart` | Text run rendering with highlight support |

### UI Components
| File | Purpose |
|------|---------|
| `lib/UI/HomePage.dart` | Main application shell |
| `lib/UI/DocViewer/doc_viewer_top_toolbar.dart` | Reader top toolbar |
| `lib/UI/DocViewer/doc_viewer_bottom_toolbar.dart` | Reader bottom toolbar |
| `lib/UI/BookTitleRow.dart` | Book tab component |

### Configuration
| File | Purpose |
|------|---------|
| `windows/runner/main.cpp` | Windows window initial size (1536×864) |
| `lib/core/app_initialization.dart` | App startup, window manager settings |
| `lib/core/window_manager_helper.dart` | Multi-window support helpers |

---

## User Preferences Observed | تفضيلات المستخدم الملاحظة

1. **Clean Code:** Avoid unnecessary comments, debug prints, or redundant logic
2. **RTL-First Design:** All UI must respect Arabic reading direction
3. **Premium Aesthetics:** Modern, professional look with attention to typography
4. **Accurate Pagination:** No approximate or "best effort" pagination—must be exact
5. **Minimal Invasiveness:** Prefer targeted fixes over large refactors when possible

---

## Session Handoff Notes | ملاحظات تسليم الجلسة

### What Was Working On
- Search term highlighting in result snippets and page content
- Two-step query approach to bypass GROUP_CONCAT limitations

### Where Stopped
- User requested to defer the search highlighting fix to another time
- Code is in a stable state (compiles, runs)

### Recommended Next Steps
1. Complete testing of Two-Step Query in `database_queries.dart`
2. Verify search highlighting works for all result types
3. Consider adding "Copy Search Term" functionality to context menu

---

## Documentation Conventions | اتفاقيات التوثيق

- **Bilingual:** English + Arabic for key sections
- **Tables:** Use markdown tables for structured data
- **Code Blocks:** Include relevant code snippets with context
- **Status Indicators:** ✅ Complete, ⚠️ Partial, 🔴 In Progress, ❌ Blocked

---

*Last Updated: December 25, 2024*  
*آخر تحديث: 25 ديسمبر 2024*
