# Testing Guide: Shamela Search System

## Quick Start Testing

I've added test buttons so you can try the new system without breaking your existing MeiliSearch setup.

### Step 1: Test Indexing

1. **Open your app**
2. **Click the storage icon** (📦) in the top bar
3. **You'll see a toggle switch** in the top-right corner of the Indexing Screen
4. **Toggle it ON** to use "Shamela Indexing (TEST)"
5. **Click "Select Books Folder and Index"**
6. **Select a folder** with your .docx books
7. **Wait for indexing to complete**

**Note**: The new system uses a separate database (`shamela_search.db`), so it won't interfere with your existing MeiliSearch index.

### Step 2: Test Searching

1. **Go back to the main screen**
2. **Look for the orange sparkle icon** (✨) in the top bar (next to the search icon)
3. **Click it** to open the new Shamela search dialog
4. **Try searching** with different options:
   - Enter Arabic text in the search fields
   - Try morphological search (بحث صرفي)
   - Try different operators (و, أو, ليس)
   - Test phrase matching options

### Step 3: Compare Results

- **Old system**: Click the regular search icon (🔍)
- **New system**: Click the orange sparkle icon (✨)

Compare the results and see which one works better for your Arabic books!

---

## What to Test

### 1. Morphological Search (بحث صرفي)
- Enable this option
- Search for "كتب"
- Should find: كاتب, كاتبة, كتاب, مكتبة, etc.

### 2. Multi-term Search
- Enter multiple terms in different fields
- Try different operators (AND/OR/NOT)
- See how results change

### 3. Advanced Options
- **Consider Hamzas**: Test with/without
- **Consider Diacritics**: Test with/without
- **Affix Search**: Test prefix/suffix matching

### 4. Phrase Matching
- **All phrases required**: All terms must appear
- **Ordered**: Terms must appear in order
- **Proximity**: Terms must be close together

### 5. Section Filtering
- Select different sections (المتن, الحواشي, etc.)
- See how results change

---

## Troubleshooting

### "No indexed books" error
**Solution**: You need to index books first using the Shamela indexing system (toggle ON in Indexing Screen).

### Search returns no results
**Possible causes**:
1. Books not indexed with Shamela system
2. Search query too specific
3. Try disabling "Consider Diacritics" and "Consider Hamzas"

### Slow indexing
**Normal**: First-time indexing creates morphological index, which takes longer. Subsequent indexing is faster.

### Database errors
**Solution**: The new system uses `shamela_search.db`. If you see errors, you can delete this file and re-index.

---

## What's Different?

| Feature | Old (MeiliSearch) | New (Shamela) |
|---------|------------------|---------------|
| Database | MeiliSearch server | SQLite FTS5 |
| Morphological Search | ❌ | ✅ |
| Root Extraction | ❌ | ✅ |
| Multi-term Operators | Limited | Full (AND/OR/NOT) |
| Phrase Matching | Basic | Advanced |
| Speed | Good | Excellent |

---

## Switching Back

To use the old system:
1. **Indexing**: Toggle OFF in Indexing Screen
2. **Search**: Use the regular search icon (🔍)

Both systems work independently, so you can switch between them anytime!

---

## Feedback

After testing, let me know:
1. ✅ What works well
2. ❌ What needs improvement
3. 🐛 Any bugs you find
4. 💡 Feature requests

I can then refine the system based on your feedback!

