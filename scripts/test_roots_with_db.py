#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
سكريبت لاختبار استخراج الجذور من قاعدة البيانات
"""

import sqlite3
from pathlib import Path

def test_roots():
    """اختبار الجذور من قاعدة البيانات"""
    
    # مسار قاعدة البيانات
    db_path = Path(__file__).parent.parent / "assets" / "arabic_roots_database.db"
    
    if not db_path.exists():
        print(f"❌ قاعدة البيانات غير موجودة في: {db_path}")
        print("   سيتم استخدام الخوارزمية فقط (لا يمكن اختبارها من Python)")
        return
    
    # الاتصال بقاعدة البيانات
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # قائمة الأمثلة: [الكلمة, الجذر المتوقع]
    test_cases = [
        # الأمثلة الأولى
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
        
        # الأمثلة الثانية
        ['انتبه', 'نبه'],
        ['معتمد', 'عدم'],
        ['تجربة', 'جرب'],
        ['ممحاة', 'محي'],
        ['تدحرج', 'دحرج'],
        ['إسلام', 'سلم'],
        ['احتلال', 'حلل'],
        ['مشكاة', 'شكي'],
        
        # الأمثلة الثالثة
        ['مدينة', 'مدن'],
        ['سفينة', 'سفن'],
        ['همام', 'همم'],
        ['استقبال', 'قبل'],
        ['استسهال', 'سهل'],
        ['جمهور', 'جمع'],
        ['سداسي', 'سدس'],
        ['حيوانات', 'حوي'],
        
        # الأمثلة الرابعة
        ['مناجاة', 'نجي'],
        ['ندّ', 'ندد'],
        ['همّ', 'همم'],
        ['مساقاة', 'سقي'],
        ['مساجد', 'سجد'],
        ['شوارع', 'شرع'],
        
        # أمثلة إضافية
        ['حيوان', 'حوي'],
    ]
    
    print("=" * 70)
    print("اختبار استخراج الجذور من قاعدة البيانات")
    print("=" * 70)
    print()
    
    passed = 0
    failed = 0
    not_found = 0
    failures = []
    
    for word, expected_root in test_cases:
        # البحث في قاعدة البيانات
        cursor.execute(
            'SELECT root FROM arabic_roots WHERE word = ?',
            (word,)
        )
        result = cursor.fetchone()
        
        if result:
            actual_root = result[0]
            if actual_root == expected_root:
                print(f"✓ {word:15s} → {actual_root:10s} (متوقع: {expected_root})")
                passed += 1
            else:
                print(f"✗ {word:15s} → {actual_root:10s} (متوقع: {expected_root})")
                failed += 1
                failures.append(f"{word}: متوقع '{expected_root}' لكن النتيجة '{actual_root}'")
        else:
            print(f"? {word:15s} → {'غير موجود':10s} (متوقع: {expected_root})")
            not_found += 1
            failures.append(f"{word}: غير موجود في قاعدة البيانات (متوقع: '{expected_root}')")
    
    print()
    print("=" * 70)
    print("النتائج:")
    print("=" * 70)
    print(f"نجح: {passed}")
    print(f"فشل: {failed}")
    print(f"غير موجود: {not_found}")
    print(f"المجموع: {len(test_cases)}")
    if len(test_cases) > 0:
        success_rate = (passed / len(test_cases) * 100)
        print(f"نسبة النجاح: {success_rate:.1f}%")
    
    if failures:
        print()
        print("التفاصيل:")
        for failure in failures:
            print(f"  - {failure}")
    
    print("=" * 70)
    print()
    print("ملاحظة: الكلمات غير الموجودة في قاعدة البيانات")
    print("         سيتم استخراج جذورها باستخدام الخوارزمية")
    print("=" * 70)
    
    conn.close()

if __name__ == "__main__":
    test_roots()

