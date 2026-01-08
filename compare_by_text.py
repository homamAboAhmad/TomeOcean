"""
تحليل أدق: مطابقة الفقرات بالنص لا بالترتيب
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import sys
import os

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def get_word_paragraphs_with_text(docx_path):
    """الحصول على الفقرات من Word مع نصها ورقم صفحتها"""
    print("Getting paragraphs from Word API...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    results = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        # الحصول على نطاق المستند الرئيسي فقط (بدون Headers/Footers)
        main_range = doc.Content
        
        # تقسيم حسب الفقرات
        for i, para in enumerate(main_range.Paragraphs):
            if i >= 50: break  # حد للسرعة
            
            try:
                text = para.Range.Text.strip()[:40]
                page = para.Range.Information(3)  # wdActiveEndPageNumber
                
                results.append({
                    'index': i + 1,
                    'text': text.replace('\r', '').replace('\n', ''),
                    'page': page
                })
            except:
                pass
                
        doc.Close(False)
        
    finally:
        try:
            word.Quit()
        except:
            pass
    
    return results

def get_xml_paragraphs_with_text(docx_path):
    """الحصول على الفقرات من XML مع نصها"""
    print("Getting paragraphs from XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    results = []
    current_page = 1
    
    for i, element in enumerate(body):
        if element.tag != f"{{{NS['w']}}}p":
            continue
            
        if len(results) >= 50: break
            
        # النص
        texts = []
        for t in element.findall(f".//{{{NS['w']}}}t"):
            if t.text:
                texts.append(t.text)
        text = ''.join(texts).strip()[:40]
        
        # الصفحة الحالية
        page_now = current_page
        
        # البحث عن breaks
        has_break = False
        for run in element.findall(f".//{{{NS['w']}}}r"):
            if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                has_break = True
            for br in run.findall(f".//{{{NS['w']}}}br"):
                if br.get(f"{{{NS['w']}}}type") == "page":
                    has_break = True
        
        if has_break:
            current_page += 1
        
        results.append({
            'index': len(results) + 1,
            'text': text,
            'page': page_now,
            'has_break': has_break
        })
    
    return results

def compare_by_text(word_results, xml_results):
    """مقارنة الفقرات بناءً على النص"""
    print("\n" + "="*70)
    print("COMPARISON BY TEXT (First 30)")
    print("="*70)
    print(f"{'Idx':4} | {'Word Page':10} | {'XML Page':10} | {'Match':5} | Text")
    print("-"*70)
    
    for i in range(min(30, len(word_results), len(xml_results))):
        w = word_results[i]
        x = xml_results[i]
        
        match = "✓" if w['page'] == x['page'] else "✗"
        text = w['text'][:30] if w['text'] else x['text'][:30]
        
        print(f"{i+1:4} | {w['page']:10} | {x['page']:10} | {match:5} | {text}")

def main(docx_path):
    word_results = get_word_paragraphs_with_text(docx_path)
    xml_results = get_xml_paragraphs_with_text(docx_path)
    
    print(f"\nWord paragraphs (main content first 50): {len(word_results)}")
    print(f"XML paragraphs (first 50): {len(xml_results)}")
    
    compare_by_text(word_results, xml_results)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
