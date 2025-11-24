import 'package:flutter_test/flutter_test.dart';
import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';

void main() {
  group('ArabicMorphologicalAnalyzer - Root Extraction Tests', () {
    
    test('Test root extraction for various patterns', () async {
      // أمثلة على كلمات مختلفة وأجذارها المتوقعة
      final testCases = [
        // فاعل pattern
        {'word': 'كاتب', 'expected': 'كتب'},
        {'word': 'قارئ', 'expected': 'قرأ'},
        {'word': 'سامع', 'expected': 'سمع'},
        
        // مفعول pattern
        {'word': 'مكتوب', 'expected': 'كتب'},
        {'word': 'مقرأ', 'expected': 'قرأ'},
        
        // مفعل pattern
        {'word': 'مكتب', 'expected': 'كتب'},
        {'word': 'مسجد', 'expected': 'سجد'},
        {'word': 'مزار', 'expected': 'زار'}, // مفعل مع حرف علة في الوسط
        
        // مفتعل pattern (معتمد)
        {'word': 'معتمد', 'expected': 'عمد'}, // م + ع + ت + م + د → عمد
        
        // فعال pattern
        {'word': 'كتاب', 'expected': 'كتب'},
        {'word': 'قراء', 'expected': 'قرأ'},
        
        // فعيل pattern
        {'word': 'كريم', 'expected': 'كرم'},
        {'word': 'شريف', 'expected': 'شرف'},
        
        // فعلة pattern (مصدر)
        {'word': 'قراءة', 'expected': 'قرأ'},
        {'word': 'كتابة', 'expected': 'كتب'},
        
        // استفعال pattern
        {'word': 'استقبال', 'expected': 'قبل'},
        {'word': 'استسهال', 'expected': 'سهل'},
        
        // مفاعلة pattern
        {'word': 'محاماة', 'expected': 'حمي'},
        {'word': 'مناجاة', 'expected': 'نجي'},
        
        // فعلان pattern
        {'word': 'حيوان', 'expected': 'حيي'},
        
        // انفعل pattern
        {'word': 'انطلق', 'expected': 'طلق'},
        
        // مفاعل pattern
        {'word': 'مساجد', 'expected': 'سجد'},
        
        // فواعل pattern
        {'word': 'شوارع', 'expected': 'شرع'},
        
        // فعيلة pattern
        {'word': 'مدينة', 'expected': 'مدن'},
        {'word': 'سفينة', 'expected': 'سفن'},
        
        // إسلام pattern
        {'word': 'إسلام', 'expected': 'سلم'},
        
        // دعا pattern (ends with ا)
        {'word': 'دعا', 'expected': 'دعا'},
        
        // جذور رباعية
        {'word': 'تدحرج', 'expected': 'دحرج'},
      ];
      
      print('\n=== اختبار استخراج الجذر ===\n');
      
      int passed = 0;
      int failed = 0;
      List<Map<String, String>> failures = [];
      
      for (var testCase in testCases) {
        final word = testCase['word'] as String;
        final expected = testCase['expected'] as String;
        
        try {
          final result = await ArabicMorphologicalAnalyzer.extractRoot(word);
          final success = result == expected;
          
          if (success) {
            passed++;
            print('✓ $word → $result');
          } else {
            failed++;
            failures.add({'word': word, 'expected': expected, 'got': result});
            print('✗ $word → $result (متوقع: $expected) ❌');
          }
        } catch (e) {
          failed++;
          failures.add({'word': word, 'expected': expected, 'got': 'خطأ: $e'});
          print('✗ $word → خطأ: $e ❌');
        }
      }
      
      print('\n=== النتائج ===');
      print('نجح: $passed');
      print('فشل: $failed');
      print('المجموع: ${testCases.length}');
      
      if (failures.isNotEmpty) {
        print('\n=== الأخطاء ===');
        for (var failure in failures) {
          print('${failure['word']}: متوقع "${failure['expected']}"، حصلنا على "${failure['got']}"');
        }
      }
      
      expect(failed, 0, reason: 'يجب أن تمر جميع الاختبارات');
    });
    
    test('Test specific problematic words', () async {
      print('\n=== اختبار الكلمات المشكلة ===\n');
      
      final problematicWords = [
        {'word': 'مزار', 'expected': 'زار', 'pattern': 'مفعل'},
        {'word': 'معتمد', 'expected': 'عمد', 'pattern': 'مفتعل'},
        {'word': 'جمهور', 'expected': 'جمهر', 'pattern': 'فعول (رباعي)'},
      ];
      
      for (var test in problematicWords) {
        final word = test['word'] as String;
        final expected = test['expected'] as String;
        final pattern = test['pattern'] as String;
        
        final result = await ArabicMorphologicalAnalyzer.extractRoot(word);
        final success = result == expected;
        
        print('$word ($pattern): $result ${success ? "✓" : "✗ (متوقع: $expected)"}');
        expect(result, expected, reason: 'الجذر المتوقع لـ "$word" هو "$expected"');
      }
    });
  });
}

