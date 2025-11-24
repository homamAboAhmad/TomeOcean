#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Download Arabic Roots Database from HuggingFace and convert to SQLite
This script downloads the arabic-roots dataset and creates a SQLite database
with words and their roots for fast lookup in Flutter app.
"""

import sqlite3
import json
import os
from pathlib import Path

def download_and_convert_to_sqlite():
    """Download arabic-roots dataset and convert to SQLite"""
    
    print("=" * 60)
    print("Arabic Roots Database Downloader")
    print("=" * 60)
    
    # Try to use datasets library
    try:
        from datasets import load_dataset
        print("\n[1] Loading dataset from HuggingFace...")
        dataset = load_dataset("MohamedRashad/arabic-roots")
        print(f"✓ Dataset loaded successfully")
        print(f"  Dataset info: {dataset}")
        
        # Get the train split (or default split)
        if 'train' in dataset:
            data = dataset['train']
        else:
            # Get first available split
            split_name = list(dataset.keys())[0]
            data = dataset[split_name]
        
        print(f"\n[2] Processing {len(data)} entries...")
        
    except ImportError:
        print("\n✗ 'datasets' library not installed.")
        print("  Install with: pip install datasets")
        print("\n  Falling back to manual data entry...")
        
        # Fallback: Create a basic database with known words
        data = None
        print("  Creating basic database with known words...")
    
    # Create output directory
    output_dir = Path(__file__).parent.parent / "assets"
    output_dir.mkdir(parents=True, exist_ok=True)
    db_path = output_dir / "arabic_roots_database.db"
    
    print(f"\n[3] Creating SQLite database at: {db_path}")
    
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
    
    # Insert data
    word_count = 0
    
    if data is not None:
        print(f"\n[4] Inserting {len(data)} entries into database...")
        
        # Batch insert for better performance
        batch_size = 1000
        batch = []
        
        for entry in data:
            # Extract word and root from dataset
            # The dataset structure may vary, so we need to check
            if isinstance(entry, dict):
                # Try different possible field names
                word = entry.get('word') or entry.get('lemma') or entry.get('text') or entry.get('entry') or entry.get('Word') or entry.get('Lemma')
                root = entry.get('root') or entry.get('Root') or entry.get('جذر') or entry.get('الجذر') or entry.get('root_word')
                
                # If we have a root, add the root itself as a word
                if root:
                    if word:
                        batch.append((word, root))
                        word_count += 1
                    # Also add the root as a word pointing to itself
                    batch.append((root, root))
                    word_count += 1
                    
                    # Generate common derivations from root
                    if len(root) >= 3:
                        f1, f2, f3 = root[0], root[1] if len(root) > 1 else '', root[2] if len(root) > 2 else ''
                        if f1 and f2 and f3:
                            # Common patterns
                            derivations = [
                                f"{f1}ا{f2}{f3}",      # فاعل
                                f"م{f1}{f2}{f3}",      # مفعل
                                f"{f1}{f2}ا{f3}",      # فعال
                                f"{f1}{f2}ي{f3}",      # فعيل
                                f"{f1}{f2}{f3}ة",      # فعلة
                                f"{f1}{f2}و{f3}",      # فعول
                            ]
                            for deriv in derivations:
                                if deriv and deriv != root:
                                    batch.append((deriv, root))
                                    word_count += 1
                    
                    if len(batch) >= batch_size:
                        cursor.executemany(
                            'INSERT OR REPLACE INTO arabic_roots (word, root) VALUES (?, ?)',
                            batch
                        )
                        conn.commit()
                        print(f"  Inserted {word_count} words...", end='\r')
                        batch = []
        
        # Insert remaining batch
        if batch:
            cursor.executemany(
                'INSERT OR REPLACE INTO arabic_roots (word, root) VALUES (?, ?)',
                batch
            )
            conn.commit()
        
        print(f"\n  ✓ Inserted {word_count} words")
    
    else:
        # Fallback: Add known words
        print("\n[4] Adding known words to database...")
        known_words = {
            "دعونا": "دعو",
            "دعوت": "دعو",
            "الدعوات": "دعو",
            "دعوات": "دعو",
            "ادعاء": "دعو",
            "المحاماة": "حمي",
            "محاماة": "حمي",
            "كاتب": "كتب",
            "كتاب": "كتب",
            "مكتوب": "كتب",
            "كتابة": "كتب",
            "يكتب": "كتب",
            "كتاتيب": "كتب",
            "كتيبات": "كتب",
            "قراءة": "قرأ",
            "قرأ": "قرأ",
            "مقرأة": "قرأ",
            "مقرأ": "قرأ",
            "قارئ": "قرأ",
            "دعا": "دعو",
            "مزار": "زور",
            "رمى": "رمي",
            "سعى": "سعي",
            "كتب": "كتب",
            "دعو": "دعو",
            "حمي": "حمي",
            "زور": "زور",
            "رمي": "رمي",
            "سعي": "سعي",
        }
        
        cursor.executemany(
            'INSERT OR REPLACE INTO arabic_roots (word, root) VALUES (?, ?)',
            [(word, root) for word, root in known_words.items()]
        )
        conn.commit()
        word_count = len(known_words)
        print(f"  ✓ Added {word_count} known words")
    
    # Get final count
    cursor.execute('SELECT COUNT(*) FROM arabic_roots')
    final_count = cursor.fetchone()[0]
    
    # Get database size
    db_size = db_path.stat().st_size / (1024 * 1024)  # MB
    
    print(f"\n[5] Database created successfully!")
    print(f"  Total words: {final_count}")
    print(f"  Database size: {db_size:.2f} MB")
    print(f"  Location: {db_path}")
    
    # Test query
    print(f"\n[6] Testing database...")
    test_words = ["كاتب", "محاماة", "قراءة"]
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
    download_and_convert_to_sqlite()

