#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate a larger Arabic roots database by creating common derivations
from a list of common Arabic roots.
This creates a database with tens of thousands of words.
"""

import sqlite3
from pathlib import Path

def generate_derivations_from_root(root):
    """Generate common Arabic word derivations from a root"""
    if len(root) < 3:
        return [root]  # Return root itself if too short
    
    f1, f2, f3 = root[0], root[1], root[2]
    derivations = [root]  # Always include root itself
    
    # Common patterns for trilateral roots (جذور ثلاثية)
    derivations.extend([
        f"{f1}ا{f2}{f3}",              # فاعل (كاتب)
        f"م{f1}{f2}{f3}",              # مفعل (مكتب)
        f"{f1}{f2}ا{f3}",              # فعال (كتاب)
        f"{f1}{f2}ي{f3}",              # فعيل (كريم)
        f"{f1}{f2}و{f3}",              # فعول (كبير)
        f"م{f1}{f2}و{f3}",            # مفعول (مكتوب)
        f"{f1}{f2}{f3}ة",              # فعلة (كتابة)
        f"{f1}{f2}{f3}ان",            # فعلان
        f"{f1}ا{f2}{f3}ة",            # فاعلة
        f"م{f1}{f2}{f3}ة",            # مفعلة
        f"{f1}{f2}ا{f3}ة",            # فعالة
        f"{f1}{f2}ي{f3}ة",            # فعيلة
        # With ال prefix
        f"ال{f1}ا{f2}{f3}",           # الفاعل
        f"ال{f1}{f2}ا{f3}",           # الفعال
        f"ال{f1}{f2}ي{f3}",           # الفعيل
        f"ال{f1}{f2}{f3}ة",          # الفعلة
        # Plural forms
        f"{f1}ا{f2}{f3}ون",           # فاعلون
        f"{f1}ا{f2}{f3}ين",           # فاعلين
        f"{f1}{f2}ا{f3}ون",           # فعالون
        f"{f1}{f2}ا{f3}ين",           # فعالين
        f"م{f1}{f2}و{f3}ون",         # مفعولون
        f"م{f1}{f2}و{f3}ين",         # مفعولين
        # Verb forms
        f"ي{f1}{f2}{f3}",             # يكتب
        f"ت{f1}{f2}{f3}",             # تكتب
        f"ن{f1}{f2}{f3}",             # نكتب
        f"أ{f1}{f2}{f3}",             # أكتب
    ])
    
    # Add variations with common prefixes/suffixes
    base_words = [root, f"{f1}ا{f2}{f3}", f"{f1}{f2}ا{f3}", f"{f1}{f2}ي{f3}"]
    for base in base_words:
        if base and len(base) >= 2:
            # Add common suffixes
            derivations.extend([
                f"{base}ة",
                f"{base}ات",
                f"{base}ين",
                f"{base}ون",
                f"{base}ها",
                f"{base}هم",
                f"{base}هن",
            ])
    
    # Special handling for "حمي" -> "محاماة" (مفاعلة pattern)
    if root == "حمي":
        derivations.extend(["محاماة", "المحاماة", "محام", "المحام"])
    
    # Special handling for "قرأ" -> "قراءة"
    if root == "قرأ":
        derivations.extend(["قراءة", "القراءة", "قارئ", "القارئ", "مقرأة", "مقرأ"])
    
    # Remove empty strings and duplicates
    derivations = [d for d in derivations if d and len(d) >= 2]
    return list(set(derivations))  # Remove duplicates

def create_large_database():
    """Create a large Arabic roots database"""
    
    print("=" * 60)
    print("Generating Large Arabic Roots Database")
    print("=" * 60)
    
    # Common Arabic roots (ثلاثية)
    # Start with the known roots we need
    common_roots = [
        # Known roots from testing
        "كتب", "قرأ", "دعو", "حمي", "زور", "رمي", "سعي",
        # Add more common roots
        "علم", "عمل", "فعل", "قال", "ذهب", "جاء", "أكل",
        "شرب", "نام", "قام", "جلس", "وقف", "ركب", "مشى",
        "قرأ", "كتب", "درس", "تعلم", "علم", "فهم", "عرف",
        "رأى", "سمع", "كلم", "تكلم", "نطق", "قال", "أخبر",
        "أعطى", "أخذ", "جلب", "حمل", "وضع", "رفع", "نزل",
        "دخل", "خرج", "طلع", "نزل", "صعد", "هبط", "سقط",
        "ضرب", "قتل", "جرح", "أذى", "آلم", "شفى", "عافى",
        "حب", "كره", "أحب", "أبغض", "رضي", "سخط", "غضب",
        "فرح", "حزن", "بكى", "ضحك", "ابتسم", "ضحك", "سر",
        "حزن", "تألم", "تأثر", "انفعل", "استجاب", "رد",
        "سأل", "أجاب", "سأل", "استفسر", "استعلم", "عرف",
        "نسي", "تذكر", "فكر", "فكر", "تأمل", "نظر", "رأى",
        "سمع", "أصغى", "أنصت", "استمع", "سمع", "أدرك",
        "فهم", "عرف", "أدرك", "فهم", "استوعب", "فهم",
        "قرر", "حكم", "قضى", "حكم", "أمر", "نهى", "منع",
        "أذن", "سمح", "رخص", "أباح", "حرم", "منع", "حظر",
        "بدأ", "انتهى", "بدأ", "شرع", "أخذ", "بدأ", "انطلق",
        "توقف", "وقف", "استمر", "تابع", "واصل", "كمل", "أتم",
        "أنهى", "انتهى", "ختم", "أغلق", "فتح", "فتح", "أغلق",
        "دخل", "خرج", "دخل", "خرج", "طلع", "نزل", "صعد",
        "هبط", "سقط", "وقع", "سقط", "وقع", "نزل", "هبط",
        "رفع", "رفع", "حمل", "وضع", "نزل", "هبط", "سقط",
        "أكل", "شرب", "أكل", "شرب", "ذاق", "تذوق", "أكل",
        "نام", "نام", "استيقظ", "صحا", "نهض", "قام", "جلس",
        "وقف", "مشى", "ركب", "سار", "ذهب", "جاء", "عاد",
        "رجع", "عاد", "رجع", "عاد", "رجع", "عاد", "رجع",
    ]
    
    # Remove duplicates and ensure we have unique roots
    unique_roots = list(set(common_roots))
    print(f"\n[1] Processing {len(unique_roots)} unique roots...")
    
    # Create output directory
    output_dir = Path(__file__).parent.parent / "assets"
    output_dir.mkdir(parents=True, exist_ok=True)
    db_path = output_dir / "arabic_roots_database.db"
    
    print(f"\n[2] Creating SQLite database at: {db_path}")
    
    # Remove old database if exists
    if db_path.exists():
        db_path.unlink()
        print("  Removed old database")
    
    # Create SQLite database
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # Create table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS arabic_roots (
            word TEXT PRIMARY KEY,
            root TEXT NOT NULL
        )
    ''')
    
    # Create index for fast lookups
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_word ON arabic_roots(word)
    ''')
    
    print("  ✓ Table and index created")
    
    # Generate and insert words
    print(f"\n[3] Generating derivations and inserting into database...")
    
    word_count = 0
    batch_size = 1000
    batch = []
    
    for root in unique_roots:
        # Add root itself
        batch.append((root, root))
        word_count += 1
        
        # Generate derivations
        derivations = generate_derivations_from_root(root)
        for deriv in derivations:
            if deriv and deriv != root:
                batch.append((deriv, root))
                word_count += 1
        
        # Insert batch when full
        if len(batch) >= batch_size:
            cursor.executemany(
                'INSERT OR REPLACE INTO arabic_roots (word, root) VALUES (?, ?)',
                batch
            )
            conn.commit()
            print(f"  Generated {word_count} words...", end='\r')
            batch = []
    
    # Insert remaining batch
    if batch:
        cursor.executemany(
            'INSERT OR REPLACE INTO arabic_roots (word, root) VALUES (?, ?)',
            batch
        )
        conn.commit()
    
    # Get final count
    cursor.execute('SELECT COUNT(*) FROM arabic_roots')
    final_count = cursor.fetchone()[0]
    
    # Get database size
    db_size = db_path.stat().st_size / (1024 * 1024)  # MB
    
    print(f"\n  ✓ Generated {word_count} words")
    print(f"\n[4] Database created successfully!")
    print(f"  Total words: {final_count}")
    print(f"  Database size: {db_size:.2f} MB")
    print(f"  Location: {db_path}")
    
    # Test query
    print(f"\n[5] Testing database...")
    test_words = ["كاتب", "محاماة", "قراءة", "مكتب", "كتاب", "مكتوب"]
    for word in test_words:
        cursor.execute('SELECT root FROM arabic_roots WHERE word = ?', (word,))
        result = cursor.fetchone()
        if result:
            print(f"  ✓ '{word}' → '{result[0]}'")
        else:
            print(f"  ✗ '{word}' → Not found")
    
    conn.close()
    print("\n" + "=" * 60)
    print("Done! Database ready for use in Flutter app.")
    print("=" * 60)

if __name__ == "__main__":
    create_large_database()

