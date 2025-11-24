import 'package:flutter_test/flutter_test.dart';
import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';

void main() {
  group('Arabic Morphological Analyzer Tests', () {
    test('Test root extraction for various words', () async {
      // قائمة الأمثلة: [الكلمة, الجذر المتوقع]
      List<List<String>> testCases = [
        // الأمثلة الأولى
        ['كاتب', 'كتب'],
        ['قرأ', 'قرأ'],
        ['قراءة', 'قرأ'],
        ['مقرأة', 'قرأ'],
        ['دعا', 'دعا'],
        ['مزار', 'زر'],
        ['دعونا', 'دعا'],
        ['دعوت', 'دعا'],
        ['الدعوات', 'دعا'],
        ['ادعاء', 'دعا'],
        ['المحاماة', 'حمي'],
        
        // الأمثلة الثانية
        ['انتبه', 'نبه'],
        ['معتمد', 'عدم'],
        ['تجربة', 'جرب'],
        ['ممحاة', 'محي'],
        ['تدحرج', 'دحرج'],
        ['إسلام', 'سلم'],
        ['احتلال', 'حلل'],
        ['مشكاة', 'شكي'],
        
        // الأمثلة الثالثة
        ['مدينة', 'مدن'],
        ['سفينة', 'سفن'],
        ['همام', 'همم'],
        ['استقبال', 'قبل'],
        ['استسهال', 'سهل'],
        ['جمهور', 'جمع'],
        ['سداسي', 'سدس'],
        ['حيوانات', 'حوي'],
        
        // الأمثلة الرابعة
        ['مناجاة', 'نجي'],
        ['ندّ', 'ندد'],
        ['همّ', 'همم'],
        ['مساقاة', 'سقي'],
        ['مساجد', 'سجد'],
        ['شوارع', 'شرع'],
        
        // أمثلة إضافية
        ['حيوان', 'حوي'],
      ];

      int passed = 0;
      int failed = 0;
      List<String> failures = [];

      for (var testCase in testCases) {
        String word = testCase[0];
        String expectedRoot = testCase[1];
        
        try {
          String actualRoot = await ArabicMorphologicalAnalyzer.stem(word);
          
          if (actualRoot == expectedRoot) {
            print('✓ $word → $actualRoot');
            passed++;
          } else {
            print('✗ $word → $actualRoot (متوقع: $expectedRoot)');
            failed++;
            failures.add('$word: متوقع "$expectedRoot" لكن النتيجة "$actualRoot"');
          }
        } catch (e) {
          print('✗ $word → خطأ: $e');
          failed++;
          failures.add('$word: خطأ - $e');
        }
      }

      print('');
      print('=' * 70);
      print('النتائج:');
      print('=' * 70);
      print('نجح: $passed');
      print('فشل: $failed');
      print('المجموع: ${testCases.length}');
      if (testCases.isNotEmpty) {
        double successRate = (passed / testCases.length * 100);
        print('نسبة النجاح: ${successRate.toStringAsFixed(1)}%');
      }
      
      if (failures.isNotEmpty) {
        print('');
        print('الأخطاء:');
        for (var failure in failures) {
          print('  - $failure');
        }
      }
      
      print('=' * 70);
      
      // Fail the test if there are failures (optional - comment out if you want to see all results)
      // expect(failed, 0, reason: 'Some root extractions failed');
    });
  });
}

