"""
مقارنة سريعة - نسخة مصححة
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import os
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def compare_fast(docx_path):
    print(f"Comparing: {docx_path}\n")
    
    # 1. من Word - نسخة سريعة
    print("Getting last 30 paragraphs from Word...")
    word = win32.Dispatch("Word.Application")
    word.Visible = True  # مرئي لتجنب النوافذ المخفية
    word.DisplayAlerts = 0
    
    word_paras = []
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        total = doc.Content.Paragraphs.Count
        print(f"Total: {total}")
        
        # نأخذ فقط آخر 30 فقرة
        start = max(1, total - 29)
        for i in range(start, total + 1):
            para = doc.Content.Paragraphs(i)
            text = para.Range.Text[:30].replace('\r', '').strip()
            page = para.Range.Information(3)
            word_paras.append({'idx': i, 'text': text, 'page': page})
        
        total_pages = doc.ComputeStatistics(2)
        print(f"Total pages: {total_pages}")
        
        doc.Close(False)
        word.Quit()
        
    except Exception as e:
        print(f"Error: {e}")
        try:
            word.Quit()
        except:
            pass
        return
    
    # 2. عرض النتائج
    print("\n=== LAST 30 PARAGRAPHS FROM WORD ===")
    for p in word_paras:
        print(f"  {p['idx']:3d} | Page {p['page']:2d} | '{p['text']}'")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        compare_fast(sys.argv[1])
