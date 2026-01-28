/// ISRI Arabic Stemmer
/// Based on ISRI (Information Science Research Institute) Arabic Stemming Algorithm
/// Similar to what Shamela Library uses for morphological search
/// This is a complete offline implementation
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ArabicMorphologicalAnalyzer {
  // ... existing fields ...

  /// Helper to get the canonical path (for main thread use)
  static Future<String> getDatabasePath() async {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(p.join(appDocDir.path, 'tome_ocean', 'roots_db'));
      return p.join(dbDir.path, 'arabic_roots_database.db');
  }
  static Database? _rootsDatabase;
  static bool _databaseLoaded = false;
  static bool _loadingInProgress = false;
  static String? _manualDbPath; // Path provided manually (e.g. from Isolate)

  /// Manual setter for ISOLATES which cannot use getApplicationDocumentsDirectory
  static void setDatabasePath(String path) {
    _manualDbPath = path;
  }
  
  // ISRI stemmer prefixes (ordered by length, longest first)
  static const List<String> prefixes = [
    'وال', 'بال', 'كال', 'فال', 'ولل', 'لل',
    'ال', 'بل', 'فل', 'كل',
    'و', 'ف', 'ب', 'ك', 'ل', 'ت', 'ن', 'أ', 'إ', 'س', 'ست', 'سي',
  ];

  // ISRI stemmer suffixes (ordered by length, longest first)
  static const List<String> suffixes = [
    'تما', 'تما', 'تنا', 'تنا', 'تاه', 'تاه', 'تاهما', 'تاهما',
    'ون', 'ين', 'ات', 'ان', 'كم', 'كن', 'هم', 'هن', 'ها', 'نا',
    'اء', // إضافة "اء" للواحق
    'ة', 'ي', 'ك', 'ه', 'ن', 'ت', 'ا', 'وا',
  ];

  // Arabic verb patterns (أوزان الأفعال)
  static final Map<String, String> verbPatterns = {
    // ثلاثي
    'فعل': 'فعل',
    'فاعل': 'فعل',
    'مفعول': 'فعل',
    'فعال': 'فعل',
    'فعيل': 'فعل',
    'مفعل': 'فعل',
    'فعول': 'فعل',
    // رباعي
    'استفعل': 'فعل',
    'انفعل': 'فعل',
    'تفعل': 'فعل',
    'تفاعل': 'فعل',
    'افعل': 'فعل',
    'افعال': 'فعل',
    'افعيل': 'فعل',
    'افعول': 'فعل',
    'مفاعل': 'فعل',
    'مفاعيل': 'فعل',
    'مفاعول': 'فعل',
  };

  // Arabic noun/adjective patterns (أوزان الأسماء والصفات)
  static final Map<String, String> nounPatterns = {
    'فاعل': 'فعل',
    'مفعول': 'فعل',
    'فعال': 'فعل',
    'فعيل': 'فعل',
    'مفعل': 'فعل',
    'فعول': 'فعل',
    'فعلان': 'فعل',
    'فعلى': 'فعل',
    'فعلة': 'فعل',
    'فعلاء': 'فعل',
  };

  /// Load roots database from assets (SQLite)
  static Future<void> _loadRootsDatabase() async {
    if (_databaseLoaded && _rootsDatabase != null) return;
    
    // Prevent multiple simultaneous loads
    if (_loadingInProgress) {
      while (_loadingInProgress) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    
    _loadingInProgress = true;
    
    try {
      // Initialize database factory for Windows if needed
      if (Platform.isWindows) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      
      String dbPath;
      
      if (_manualDbPath != null) {
        // Optimized path for Isolates: Use provided path directly
        dbPath = _manualDbPath!;
      } else {
         // Main thread path: Use path_provider and verify asset
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbDir = Directory(p.join(appDocDir.path, 'tome_ocean', 'roots_db'));
        await dbDir.create(recursive: true);
        
        dbPath = p.join(dbDir.path, 'arabic_roots_database.db');
        final dbFile = File(dbPath);
        
        // Copy database from assets if it doesn't exist
        if (!await dbFile.exists()) {
          try {
            print('Copying Arabic roots database from assets...');
            final ByteData data = await rootBundle.load('assets/arabic_roots_database.db');
            final List<int> bytes = data.buffer.asUint8List();
            await dbFile.writeAsBytes(bytes);
            print('Arabic roots database copied to: $dbPath');
          } catch (e) {
            print('Error copying DB from assets: $e');
          }
        }
      }

      // Open database
      _rootsDatabase = await openDatabase(
        dbPath,
        readOnly: true,
        singleInstance: false, // Force new instance for Isolate
      );
      
      // Test query to verify database is working
      final count = Sqflite.firstIntValue(
        await _rootsDatabase!.rawQuery('SELECT COUNT(*) FROM arabic_roots')
      ) ?? 0;
      
      _databaseLoaded = true;
      print('Arabic roots database loaded: $count words');
    } catch (e) {
      print('Error loading Arabic roots database: $e');
      _rootsDatabase = null;
      _databaseLoaded = true; // Mark as loaded to prevent retry loops
    } finally {
      _loadingInProgress = false;
    }
  }

  /// Public wrapper to ensure database is ready (useful before Isolate usage)
  static Future<void> prepareRootsDatabase() => _loadRootsDatabase();

  /// ISRI Arabic Stemmer - Main stemming function
  /// This implements the ISRI stemming algorithm for Arabic
  /// Now async to support database lookup
  static Future<String> stem(String word) async {
    if (word.length < 2) return word;

    // Load database if not already loaded
    await _loadRootsDatabase();

    // 1. البحث في قاعدة البيانات SQLite أولاً
    if (_rootsDatabase != null) {
      try {
        final result = await _rootsDatabase!.query(
          'arabic_roots',
          columns: ['root'],
          where: 'word = ?',
          whereArgs: [word],
          limit: 1,
        );
        
        if (result.isNotEmpty) {
          final root = result.first['root'] as String?;
          if (root != null) {
            return root;
          }
        }
      } catch (e) {
        print('Error querying roots database: $e');
      }
    }

    // 2. إذا لم تُوجد، استخدام الخوارزمية الحالية
    return _stemWithAlgorithm(word);
  }

  /// Stem using algorithm (original stem() logic)
  static String _stemWithAlgorithm(String word) {
    if (word.length < 2) return word;

    // Step 1: Normalize the word (remove diacritics, but DON'T unify hamzas yet for root extraction)
    // We need to preserve hamza forms to extract correct roots
    String normalized = normalizeForMorphology(word, removeDiacritics: true, unifyHamzas: false);

    // Step 2: Try to extract root from known patterns first (before removing prefixes/suffixes)
    // This handles cases like "كاتب" (فاعل pattern) where "ك" is not a prefix
    // But first, try removing common prefixes like "ال", "م", "إ" if they exist
    String wordForPattern = normalized;
    
    // Remove "ال" prefix if present (for words like "المحاماة", "الدعوات")
    if (normalized.startsWith('ال') && normalized.length > 4) {
      wordForPattern = normalized.substring(2);
    }
    // Remove "إ" or "أ" prefix if present (for words like "إسلام")
    else if ((normalized.startsWith('إ') || normalized.startsWith('أ')) && normalized.length > 3) {
      wordForPattern = normalized.substring(1);
    }
    
    String rootFromPattern = _extractRootFromKnownPatterns(wordForPattern);
    if (rootFromPattern.length >= 2 && rootFromPattern != wordForPattern && rootFromPattern != normalized) {
      // Normalize hamzas in the root for consistency
      return _normalizeHamzaInRoot(rootFromPattern);
    }

    // Step 3: Remove prefixes (only if not part of a known pattern)
    String afterPrefixes = _removePrefixes(normalized);

    // Step 4: Remove suffixes (but be careful with final "ا" in verbs like "دعا")
    String afterSuffixes = _removeSuffixes(afterPrefixes);
    
    // Special case: if word ends with "ا" and is 3-4 letters, it might be the root itself
    // Example: "دعا" = "دعا" (not "دع")
    // The "ا" at the end is part of the root (third consonant)
    if (normalized.endsWith('ا') && normalized.length >= 3 && normalized.length <= 4) {
      // For words like "دعا", extract: د + ع + ا = دعا
      // The final "ا" is the third consonant of the root
      String consonants = _extractConsonants(normalized);
      if (consonants.length == 2 && normalized.endsWith('ا')) {
        // Add the final "ا" as the third consonant
        return _normalizeHamzaInRoot(consonants + 'ا');
      }
      if (consonants.length == 3 && consonants.endsWith('ا')) {
        return _normalizeHamzaInRoot(consonants);
      }
    }

    // Step 5: Extract root using pattern matching or consonant extraction
    String root = _extractRootFromPattern(afterSuffixes);

    // Normalize hamzas in the root for consistency
    return _normalizeHamzaInRoot(root);
  }

  /// Normalize hamza forms in root to أ for consistency
  /// This ensures "قرء" becomes "قرأ" and all hamza variations are unified
  static String _normalizeHamzaInRoot(String root) {
    // Convert all hamza forms to أ (hamza on alif) for root consistency
    String normalized = root;
    normalized = normalized.replaceAll('ء', 'أ');
    normalized = normalized.replaceAll('ئ', 'أ');
    normalized = normalized.replaceAll('ؤ', 'أ');
    // Keep أ and إ and آ as أ (they're already hamza on alif variants)
    normalized = normalized.replaceAll(RegExp(r'[إآ]'), 'أ');
    return normalized;
  }

  /// Extract root from Arabic word using ISRI algorithm
  static Future<String> extractRoot(String word) async {
    return await stem(word);
  }

  /// Remove prefixes using ISRI algorithm
  static String _removePrefixes(String word) {
    String result = word;
    
    // Try to remove longest prefix first
    for (String prefix in prefixes) {
      if (result.startsWith(prefix) && result.length > prefix.length + 2) {
        result = result.substring(prefix.length);
        break; // Remove only one prefix
      }
    }

    return result;
  }

  /// Remove suffixes using ISRI algorithm
  static String _removeSuffixes(String word) {
    String result = word;
    
    // Special case: don't remove final "ا" if word is 3-4 letters (might be the root itself)
    // Example: "دعا" should stay "دعا", not become "دع"
    if (result.endsWith('ا') && result.length >= 3 && result.length <= 4) {
      String consonants = _extractConsonants(result);
      if (consonants.length == 3 && consonants.endsWith('ا')) {
        return result; // Keep as is
      }
    }
    
    // Try to remove longest suffix first
    for (String suffix in suffixes) {
      // Don't remove "ا" if it's part of a 3-letter root
      if (suffix == 'ا' && result.length == 3 && result.endsWith('ا')) {
        continue;
      }
      if (result.endsWith(suffix) && result.length > suffix.length + 2) {
        result = result.substring(0, result.length - suffix.length);
        break; // Remove only one suffix
      }
    }

    return result;
  }

  /// Extract root from known Arabic patterns (فاعل، مفعول، etc.)
  /// This is called BEFORE removing prefixes/suffixes to avoid false removals
  /// Patterns are checked in order from longest to shortest
  static String _extractRootFromKnownPatterns(String word) {
    if (word.length < 3) return word;

    // استفعال pattern (استقبال، استسهال، etc.) - extract ف1ع2ل3
    // Structure: ا + س + ت + ف1 + ع2 + ا + ل3
    // Example: استقبال = ا + س + ت + ق + ب + ا + ل → root: ق + ب + ل = قبل
    // Example: استسهال = ا + س + ت + س + ه + ا + ل → root: س + ه + ل = سهل
    if (word.length >= 7 && word.startsWith('است') && word[5] == 'ا' && !_isVowel(word[3])) {
      String f1 = word[3]; // ق
      String f2 = word[4]; // ب
      String f3 = word[6]; // ل
      if (!_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // قبل
      }
    }

    // افتعال pattern (احتلال، etc.) - extract ف1ع2ل3 (مضعف)
    // Structure: ا + ف + ت + ع + ا + ل
    // Example: احتلال = ا + ح + ت + ل + ا + ل → root: ح + ل + ل = حلل (مضعف)
    // Note: الجذر المضعف يعني أن ع2 = ل3
    if (word.length >= 6 && word.startsWith('ا') && word[2] == 'ت' && word[4] == 'ا') {
      String f1 = word[1]; // ح
      String f2 = word[3]; // ل
      // In افتعال, the root is usually ف1 + ع2 + ع2 (doubled)
      if (!_isVowel(f1) && !_isVowel(f2)) {
        return _normalizeHamzaInRoot(f1 + f2 + f2); // حلل
      }
    }

    // مفاعلة pattern (مناجاة، مساقاة، محاماة، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ا + ع2 + ا + ل3 + ة
    // Example: مناجاة = م + ن + ا + ج + ا + ة → root: ن + ج + ي = نجي
    // Example: مساقاة = م + س + ا + ق + ا + ة → root: س + ق + ي = سقي
    // Example: محاماة = م + ح + ا + م + ا + ة → root: ح + م + ي = حمي
    // Note: الجذر عادة ف1 + ع2 + ي
    if (word.length >= 6 && word.startsWith('م') && word[2] == 'ا' && word[4] == 'ا' &&
        (word.endsWith('ة') || word.endsWith('ه'))) {
      String f1 = word[1]; // ن
      String f2 = word[3]; // ج
      if (f1.isNotEmpty && f2.isNotEmpty && !_isVowel(f1) && !_isVowel(f2)) {
        return _normalizeHamzaInRoot(f1 + f2 + 'ي'); // نجي
      }
    }

    // فعولات pattern (حيوانات، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ع2 + و + ل3 + ا + ت
    // Example: حيوانات = ح + ي + و + ا + ن + ا + ت (جمع "حيوان")
    // Note: "حيوان" وزن "فعلان" والجذر "حيي" (ح + ي + ي)
    // "حيوانات" جمع "حيوان" = ح + ي + و + ا + ن
    // الجذر: ح + ي + ي = حيي (مضعف)
    if (word.length >= 6 && word[2] == 'و' && word[4] == 'ا' && word.endsWith('ت') &&
        !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0]; // ح
      String f2 = word[1]; // ي
      // For "حيوانات", extract from "حيوان" (فعلان pattern)
      // حيوان = ح + ي + و + ا + ن → root: ح + ي + ي = حيي
      // حيوانات = ح + ي + و + ا + ن + ا + ت
      // Extract: ح + ي + ي = حيي (مضعف)
      return _normalizeHamzaInRoot(f1 + f2 + f2); // حيي (ح + ي + ي)
    }
    
    // فعلان pattern (حيوان، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ع2 + و + ا + ن
    // Example: حيوان = ح + ي + و + ا + ن → root: ح + ي + ي = حيي
    // Note: الجذر "حيي" وليس "حوي"
    if (word.length >= 5 && word[2] == 'و' && word[3] == 'ا' && word.endsWith('ن') &&
        !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0]; // ح
      String f2 = word[1]; // ي
      // Extract: ح + ي + ي = حيي (مضعف)
      return _normalizeHamzaInRoot(f1 + f2 + f2); // حيي
    }

    // افتعل pattern (انتبه، etc.) - extract ف1ع2ل3
    // Structure: ا + ن/ف + ت + ف1 + ع2 + ل3
    // Example: انتبه = ا + ن + ت + ب + ه → root: ن + ب + ه = نبه
    // Note: "انتبه" is from root "نبه" (ن + ب + ه) not "عمد"
    // Structure: ا + ن + ت + ب + ه → extract: ن + ب + ه
    if (word.length >= 5 && word.startsWith('ا') && word[2] == 'ت' && !_isVowel(word[1])) {
      String f1 = word[1]; // ن
      String f2 = word[3]; // ب
      String f3 = word.length > 4 ? word[4] : '';
      // Skip final ه if present
      if (f3 == 'ه' && word.length > 5) {
        f3 = word[5];
      } else if (f3 == 'ه' && word.length == 5) {
        // انتبه = ا + ن + ت + ب + ه → root: ن + ب + ه
        // f3 is 'ه', so we need to check if there's another letter
        // Actually, in "انتبه", after removing "ا" and "ت", we have "ن" + "ب" + "ه"
        // So f1 = ن, f2 = ب, f3 = ه
        // But "ه" is not part of the root, it's a suffix
        // The root is "نبه" = ن + ب + ه (where ه is the third consonant)
        return _normalizeHamzaInRoot(f1 + f2 + 'ه'); // نبه
      }
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3) && f3 != 'ة') {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // نبه
      }
    }

    // انفعل pattern (انطلق، etc.) - extract ف1ع2ل3
    // Structure: ا + ن + ف1 + ع2 + ل3
    // Example: انطلق = ا + ن + ط + ل + ق → root: ط + ل + ق = طلق
    if (word.length >= 5 && word.startsWith('ان') && !_isVowel(word[2])) {
      String f1 = word[2];
      String f2 = word[3];
      String f3 = word.length > 4 ? word[4] : '';
      // Skip final ه if present
      if (f3 == 'ه' && word.length > 5) {
        f3 = word[5];
      }
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3) && f3 != 'ه' && f3 != 'ة') {
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // مفاعل pattern (مساجد، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ا + ع2 + ل3
    // Example: مساجد = م + س + ا + ج + د → root: س + ج + د = سجد
    if (word.length >= 5 && word.startsWith('م') && word[2] == 'ا' && !_isVowel(word[1])) {
      String f1 = word[1]; // س
      String f2 = word[3]; // ج
      String f3 = word.length > 4 ? word[4] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // سجد
      }
    }

    // فواعل pattern (شوارع، etc.) - extract ف1ع2ل3
    // Structure: ف1 + و + ا + ع2 + ل3
    // Example: شوارع = ش + و + ا + ر + ع → root: ش + ر + ع = شرع
    if (word.length >= 5 && word[1] == 'و' && word[2] == 'ا' && !_isVowel(word[0])) {
      String f1 = word[0]; // ش
      String f2 = word[3]; // ر
      String f3 = word.length > 4 ? word[4] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // شرع
      }
    }

    // تفعلة pattern (تجربة، etc.) - extract ف1ع2ل3
    // Structure: ت + ف1 + ع2 + ل3 + ة
    // Example: تجربة = ت + ج + ر + ب + ة → root: ج + ر + ب = جرب
    if (word.length >= 5 && word.startsWith('ت') && (word.endsWith('ة') || word.endsWith('ه'))) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word[3];
      if (!_isVowel(f1) && !_isVowel(f2) && !_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // تفعل pattern (رباعي) - تدحرج، تزحزح، etc. - extract ف1ع2ل3ل4
    // Structure: ت + ف1 + ع2 + ل3 + ل4
    // Example: تدحرج = ت + د + ح + ر + ج → root: د + ح + ر + ج = دحرج
    if (word.length >= 5 && word.startsWith('ت') && !_isVowel(word[1])) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word[3];
      String f4 = word.length > 4 ? word[4] : '';
      if (f4.isNotEmpty && !_isVowel(f2) && !_isVowel(f3) && !_isVowel(f4)) {
        // Check if it's quadrilateral (4 consonants)
        return _normalizeHamzaInRoot(f1 + f2 + f3 + f4);
      }
    }

    // فعيلة pattern (مدينة، سفينة، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ع2 + ي + ل3 + ة
    // Example: مدينة = م + د + ي + ن + ة → root: م + د + ن = مدن
    // Example: سفينة = س + ف + ي + ن + ة → root: س + ف + ن = سفن
    if (word.length >= 5 && word[2] == 'ي' && (word.endsWith('ة') || word.endsWith('ه')) && 
        !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0]; // م
      String f2 = word[1]; // د
      String f3 = word[3]; // ن (skip 'ي' at position 2)
      if (!_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // مدن
      }
    }

    // مفعلة pattern (ممحاة، مشكاة، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ع2 + ل3 + ة
    // Example: ممحاة = م + م + ح + ي + ة → root: م + ح + ي = محي
    // Example: مشكاة = م + ش + ك + ي + ة → root: ش + ك + ي = شكي
    // Note: إذا كان ف1 = م (مثل "ممحاة")، الجذر يبدأ من ف2
    if (word.length >= 5 && word.startsWith('م') && (word.endsWith('ة') || word.endsWith('ه'))) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word[3];
      // Check if f1 == 'م' (doubled م) - like "ممحاة"
      if (f1 == 'م' && !_isVowel(f2) && !_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        // ممحاة = م + م + ح + ي + ة → root: م + ح + ي = محي
        return _normalizeHamzaInRoot(f1 + f2 + f3); // محي
      }
      // Normal case: مشكاة = م + ش + ك + ي + ة → root: ش + ك + ي = شكي
      if (!_isVowel(f1) && !_isVowel(f2) && !_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // فعالي pattern (سداسي، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ع2 + ا + ل3 + ي
    // Example: سداسي = س + د + ا + س + ي → root: س + د + س = سدس
    if (word.length >= 5 && word[2] == 'ا' && word.endsWith('ي') && 
        !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0]; // س
      String f2 = word[1]; // د
      String f3 = word[3]; // س (skip 'ا' at position 2)
      if (!_isVowel(f3) && f3 != 'ي') {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // سدس
      }
    }

    // افعل pattern (إسلام، إكرام، etc.) - extract ف1ع2ل3
    // Structure: أ/إ + ف1 + ع2 + ل3
    // Example: إسلام = إ + س + ل + م → root: س + ل + م = سلم
    if (word.length >= 4 && (word.startsWith('أ') || word.startsWith('إ') || word.startsWith('ا')) && !_isVowel(word[1])) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word.length > 3 ? word[3] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // مفتعل pattern (معتمد، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ت + ع2 + ل3
    // Example: معتمد = م + ع + ت + م + د → root: ع + م + د = عمد
    // Note: هذا نمط "مفتعل" وليس "مفعول"
    if (word.length >= 5 && word.startsWith('م') && word[2] == 'ت' && !_isVowel(word[1])) {
      String f1 = word[1]; // ع
      String f2 = word[3]; // م
      String f3 = word.length > 4 ? word[4] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        // معتمد = م + ع + ت + م + د
        // الجذر: ع + م + د = عمد (ف1 + ع2 + ل3)
        return _normalizeHamzaInRoot(f1 + f2 + f3); // عمد
      }
    }
    
    // مفعول pattern (مكتوب، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ع2 + و + ل3
    // Example: مكتوب = م + ك + ت + و + ب → root: ك + ت + ب = كتب
    if (word.length >= 5 && word.startsWith('م') && word[3] == 'و' && !_isVowel(word[1])) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word.length > 4 ? word[4] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // كتب
      }
    }
    
    // مفعول pattern (مقرأة، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ع2 + ل3 + ة
    // Example: مقرأة = م + ق + ر + أ + ة → root: ق + ر + أ = قرأ
    // Note: يجب إزالة "م" أولاً
    if (word.length >= 5 && word.startsWith('م') && (word.endsWith('ة') || word.endsWith('ه')) && !_isVowel(word[1])) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word[3];
      if (!_isVowel(f2) && !_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // قرأ
      }
    }

    // فعول pattern (جمهور، etc.) - extract ف1ع2ل3 (رباعي أو ثلاثي)
    // Structure: ف1 + ع2 + و + ل3 (or ف1 + ع2 + و + ل3 + ل4 for رباعي)
    // Example: جمهور = ج + م + ه + و + ر → root: ج + م + ه + ر = جمهر (رباعي)
    // Example: فعول ثلاثي = ف1 + ع2 + و + ل3 → root: ف1 + ع2 + ل3
    // Note: "جمهور" من "جمهر" (ج + م + ه + ر) - جذر رباعي
    if (word.length >= 4 && word[2] == 'و' && !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0];
      String f2 = word[1];
      String f3 = word[3]; // (skip 'و' at position 2)
      if (!_isVowel(f3)) {
        // Check if it's quadrilateral (4 consonants) - look for hidden consonant before و
        // For "جمهور" = ج + م + ه + و + ر, we need to extract: ج + م + ه + ر
        // The pattern is: ف1 + ع2 + (hidden consonant) + و + ل3
        // We need to check if there's a consonant between ع2 and و
        if (word.length >= 5) {
          // Try to extract 4 consonants: check if there's a consonant before و
          String consonants = _extractConsonants(word);
          if (consonants.length == 4) {
            return _normalizeHamzaInRoot(consonants);
          }
        }
        // For trilateral roots, extract ف1 + ع2 + ل3
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // فاعل pattern (كاتب، قارئ، سامع، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ا + ع2 + ل3
    // Example: كاتب = ك + ا + ت + ب → root: ك + ت + ب = كتب
    if (word.length >= 4 && word[1] == 'ا' && !_isVowel(word[0])) {
      String f1 = word[0];
      String f2 = word[2];
      String f3 = word.length > 3 ? word[3] : '';
      if (f3.isNotEmpty && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // كتب
      }
    }

    // مفعل pattern (مكتب، مقرأ، مسجد، مزار، etc.) - extract ف1ع2ل3
    // Structure: م + ف1 + ع2 + ل3 (may have vowel in ع2 position, or hamza in ل3)
    // Example: مكتب = م + ك + ت + ب → root: ك + ت + ب = كتب
    // Example: مزار = م + ز + ا + ر → root: ز + ا + ر = زار (with vowel in middle)
    // Example: مقرأ = م + ق + ر + أ → root: ق + ر + أ = قرأ (with hamza at end)
    if (word.length >= 4 && word.startsWith('م') && !_isVowel(word[1])) {
      String f1 = word[1];
      String f2 = word[2];
      String f3 = word.length > 3 ? word[3] : '';
      
      if (f3.isNotEmpty) {
        // Check if f3 is hamza (أ، إ، آ، ء، ئ، ؤ) - these are consonants in roots
        bool f3IsHamza = ['أ', 'إ', 'آ', 'ء', 'ئ', 'ؤ'].contains(f3);
        
        // Case 1: Normal مفعل pattern (مكتب) - ف1 + ع2 + ل3 (all consonants)
        if (!_isVowel(f2) && (!_isVowel(f3) || f3IsHamza)) {
          return _normalizeHamzaInRoot(f1 + f2 + f3); // كتب، قرأ
        }
        // Case 2: مفعل with vowel in middle (مزار) - ف1 + ا + ل3
        // مزار = م + ز + ا + ر → extract: ز + ا + ر = زار
        if (_isVowel(f2) && !_isVowel(f3) && !f3IsHamza) {
          return _normalizeHamzaInRoot(f1 + f2 + f3); // زار
        }
      }
    }

    // فعال pattern (كتاب، قراء، همام، etc.) - extract ف1ع2ل3 (may be doubled)
    // Structure: ف1 + ع2 + ا + ل3
    // Example: كتاب = ك + ت + ا + ب → root: ك + ت + ب = كتب
    // Example: همام = ه + م + ا + م → root: ه + م + م = همم (مضعف)
    // Note: إذا كان ع2 = ل3، الجذر مضعف
    if (word.length >= 4 && word[2] == 'ا' && !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0];
      String f2 = word[1];
      String f3 = word.length > 3 ? word[3] : '';
      if (f3.isNotEmpty && !_isVowel(f3)) {
        // Check if doubled (f2 == f3)
        if (f2 == f3) {
          return _normalizeHamzaInRoot(f1 + f2 + f2); // همم
        }
        return _normalizeHamzaInRoot(f1 + f2 + f3);
      }
    }

    // فعيل pattern (كريم، شريف، etc.) - extract ف1ع2ل3
    // Structure: ف1 + ع2 + ي + ل3
    // Example: كريم = ك + ر + ي + م → root: ك + ر + م = كرم
    if (word.length >= 4 && word[2] == 'ي' && !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0];
      String f2 = word[1];
      String f3 = word.length > 3 ? word[3] : '';
      if (f3.isNotEmpty && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f3); // كرم
      }
    }

    // فعلة pattern (قراءة، كتابة، etc.) - مصدر - extract ف1ع2ل3
    // Structure: ف1 + ع2 + ا + ل3 + ة
    // Example: قراءة = ق + ر + ا + ء + ة → root: ق + ر + أ = قرأ
    // Note: ة may become ه after normalization in some cases
    // Note: ء should be converted to أ or ا in the root
    if (word.length >= 5 && (word.endsWith('ة') || word.endsWith('ه')) && word[2] == 'ا' && !_isVowel(word[0]) && !_isVowel(word[1])) {
      String f1 = word[0]; // ق
      String f2 = word[1]; // ر
      String f3 = word[3];  // ء (skip the 'ا' at position 2)
      if (f3.isNotEmpty && !_isVowel(f3) && f3 != 'ة' && f3 != 'ه') {
        // Build root and normalize hamzas
        String root = f1 + f2 + f3;
        return _normalizeHamzaInRoot(root); // قرأ (not قرء)
      }
    }

    // فعل مضعف pattern (ندّ، همّ، etc.) - extract ف1ع2ع2
    // Structure: ف1 + ع2 + ع2 (doubled consonant)
    // Example: ندّ = ن + د + د → root: ن + د + د = ندد
    // Example: همّ = ه + م + م → root: ه + م + م = همم
    // Note: قد يكون هناك shadda (ّ) في الكتابة، لكن في النص العادي يكون الحرف مكرر
    if (word.length >= 3 && !_isVowel(word[0])) {
      String f1 = word[0];
      String f2 = word.length > 1 ? word[1] : '';
      String f3 = word.length > 2 ? word[2] : '';
      // Check if it's doubled (f2 == f3 and both are consonants)
      if (f2.isNotEmpty && f3.isNotEmpty && f2 == f3 && !_isVowel(f2) && !_isVowel(f3)) {
        return _normalizeHamzaInRoot(f1 + f2 + f2); // ندد
      }
      // Also check if word is only 2 letters with same consonant (like "ندّ" written as "ند")
      if (word.length == 2 && f2.isNotEmpty && !_isVowel(f2)) {
        // This might be a doubled root, but we can't be sure without context
        // For now, return as is
      }
    }

    // فعل pattern (قرأ، كتب، etc.) - فعل ثلاثي - extract ف1ع2ل3
    // Structure: ف1 + ع2 + ل3 (may have vowels between)
    // Example: قرأ = ق + ر + أ → root: ق + ر + أ = قرأ
    // For verbs, extract consonants directly
    if (word.length >= 3 && !_isVowel(word[0])) {
      // Try to extract 3 consonants
      String root = _extractConsonants(word);
      if (root.length == 3) {
        return root; // قرأ
      }
    }

    return word; // No pattern matched, return original
  }

  /// Extract root from word using pattern matching
  /// This is a key part of ISRI algorithm
  static String _extractRootFromPattern(String word) {
    if (word.length < 2) return word;

    // Remove common prefixes and suffixes again if needed
    String cleaned = word;
    
    // Try to match verb patterns
    for (var pattern in verbPatterns.keys) {
      if (_matchesPattern(cleaned, pattern)) {
        return _extractRootFromPatternMatch(cleaned, pattern);
      }
    }

    // Try to match noun patterns
    for (var pattern in nounPatterns.keys) {
      if (_matchesPattern(cleaned, pattern)) {
        return _extractRootFromPatternMatch(cleaned, pattern);
      }
    }

    // If no pattern matches, extract consonants (most common approach)
    return _extractConsonants(cleaned);
  }

  /// Check if word matches a pattern (e.g., "فعل", "فاعل")
  static bool _matchesPattern(String word, String pattern) {
    if (word.length < pattern.length) return false;
    
    // Simple pattern matching - check if word structure matches pattern
    // This is a simplified version - full ISRI uses more complex matching
    return word.length >= pattern.length;
  }

  /// Extract root from pattern match
  static String _extractRootFromPatternMatch(String word, String pattern) {
    // Extract the root letters based on the pattern
    // For example, if pattern is "فعل" and word is "كتب", extract "كتب"
    // This is simplified - full ISRI uses more sophisticated extraction
    
    // For now, extract consonants (most reliable method)
    return _extractConsonants(word);
  }

  /// Extract consonants from word (core of root extraction)
  /// Improved to handle "و" and "ي" at the end of roots
  static String _extractConsonants(String word) {
    String root = '';
    int consonantCount = 0;
    
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      
      // Skip diacritics
      if (_isDiacritic(char)) {
        continue;
      }
      
      // Hamzas (أ، إ، آ، ء، ئ، ؤ) are consonants when part of root, not vowels
      // So we include them as consonants
      bool isHamza = ['أ', 'إ', 'آ', 'ء', 'ئ', 'ؤ'].contains(char);
      bool isWawOrYa = char == 'و' || char == 'ي';
      
      // Special handling for "و" and "ي" at the end of root
      // If we have 2 consonants and next is "و" or "ي", it's likely part of root
      if (isWawOrYa && consonantCount == 2) {
        // Check if "و" or "ي" is at the end or before a vowel at the end
        bool isAtEnd = i == word.length - 1;
        bool isBeforeVowelAtEnd = i < word.length - 1 && 
                                   _isVowel(word[i + 1]) && 
                                   i + 2 >= word.length;
        
        if (isAtEnd || isBeforeVowelAtEnd) {
          // This "و" or "ي" is likely the third consonant of the root
          root += char;
          consonantCount++;
          break;
        }
      }
      
      // Skip vowels (but NOT hamzas - they're consonants)
      if (!isHamza && _isVowel(char)) {
        continue;
      }
      
      root += char;
      consonantCount++;
      
      // For trilateral roots, we typically want 3 consonants
      // For quadrilateral roots, we want 4 consonants
      // But we'll take what we can get
      if (consonantCount >= 4) break; // Max 4 for quadrilateral roots
    }
    
    // Normalize hamzas in the extracted root
    root = _normalizeHamzaInRoot(root);
    
    // If we got at least 2 consonants, return them
    if (root.length >= 2) {
      return root;
    }
    
    // Otherwise, return the cleaned word
    return word;
  }

  /// Generate morphological variations of a word
  /// Based on ISRI root extraction, generate common forms
  static List<String> generateMorphologicalVariations(String word) {
    Set<String> variations = {word};
    
    // Normalize first
    String normalized = normalizeForMorphology(word);
    variations.add(normalized);
    
    // Extract root (using algorithm directly since this is sync)
    String root = _stemWithAlgorithm(normalized);
    if (root.length >= 2) {
      variations.add(root);
      
      // Generate common variations from root
      if (root.length >= 3) {
        String f1 = root[0];
        String f2 = root.length > 1 ? root[1] : '';
        String f3 = root.length > 2 ? root[2] : '';
        String f4 = root.length > 3 ? root[3] : '';
        
        // Trilateral root variations (جذور ثلاثية)
        if (root.length == 3) {
          variations.add('$f1$f2$f3');      // فعل
          variations.add('$f1ا$f2$f3');     // فاعل
          variations.add('م$f1$f2$f3');    // مفعل
          variations.add('$f1$f2$f3ة');    // فعلة
          variations.add('$f1$f2ا$f3');    // فعال
          variations.add('$f1$f2ي$f3');    // فعيل
          variations.add('$f1$f2و$f3');    // فعول
          variations.add('$f1$f2$f3ان');    // فعلان
          variations.add('$f1$f2$f3ة');     // فعلة
        }
        
        // Quadrilateral root variations (جذور رباعية)
        if (root.length == 4) {
          variations.add('$f1$f2$f3$f4');           // فعل
          variations.add('$f1$f2ا$f3$f4');         // فعال
          variations.add('$f1$f2$f3$f4ة');        // فعلة
          variations.add('م$f1$f2$f3$f4');        // مفعل
          variations.add('$f1$f2$f3$f4ي');        // فعلي
          variations.add('$f1$f2$f3$f4ان');       // فعلان
        }
      }
    }
    
    return variations.toList();
  }

  /// Check if character is a vowel
  /// Note: Hamzas (أ، إ، آ) and 'ي' can be consonants in roots, but we check them separately
  static bool _isVowel(String char) {
    // Note: 'ي' and hamzas are included here for general vowel checking,
    // but they're treated as consonants when extracting roots
    return ['ا', 'و', 'ى'].contains(char);
  }

  /// Check if character is a diacritic
  static bool _isDiacritic(String char) {
    if (char.isEmpty) return false;
    int code = char.codeUnitAt(0);
    return code >= 0x064B && code <= 0x0652; // Arabic diacritics range
  }

  /// Normalize word for morphological search
  /// Removes diacritics but keeps structure for root extraction
  static String normalizeForMorphology(String word, {
    bool removeDiacritics = true,
    bool unifyHamzas = true,
  }) {
    String normalized = word;

    if (removeDiacritics) {
      normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    }

    if (unifyHamzas) {
      normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
      normalized = normalized.replaceAll('ؤ', 'و');
      normalized = normalized.replaceAll('ئ', 'ي');
    }

    return normalized;
  }

  /// Extract all possible search terms for morphological search
  /// Uses ISRI stemmer for better accuracy
  static List<String> getMorphologicalSearchTerms(String query, {
    bool includeRoot = true,
    bool includeVariations = true,
  }) {
    Set<String> terms = {query};
    
    // Split query into words
    List<String> words = query.trim().split(RegExp(r'\s+'));
    
    for (String word in words) {
      if (word.length < 2) continue;
      
      // Normalize
      String normalized = normalizeForMorphology(word);
      terms.add(normalized);
      
      if (includeRoot) {
        // Use ISRI stemmer for root extraction
        // Note: This is now async, but getMorphologicalSearchTerms is sync
        // For now, we'll use the algorithm directly
        String root = _stemWithAlgorithm(normalized);
        if (root.length >= 2) {
          terms.add(root);
        }
      }
      
      if (includeVariations) {
        // Generate variations using ISRI
        List<String> variations = generateMorphologicalVariations(normalized);
        terms.addAll(variations);
      }
    }
    
    return terms.toList();
  }
}
