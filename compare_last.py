"""
مقارنة دقيقة بين فقرات Word و XML
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import os
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def compare_paragraphs(docx_path):
    print(f"Comparing: {docx_path}\n")
    
    # 1. من Word
    print("Getting paragraphs from Word...")
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    word_paras = []
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        for i in range(1, doc.Content.Paragraphs.Count + 1):
            try:
                para = doc.Content.Paragraphs(i)
                text = para.Range.Text[:30].replace('\r', '').replace('\n', '').strip()
                page = para.Range.Information(3)
                word_paras.append({'idx': i, 'text': text, 'page': page})
            except:
                pass
        
        doc.Close(False)
    finally:
        try:
            word.Quit()
        except:
            pass
    
    # 2. من XML
    print("Getting paragraphs from XML...")
    xml_paras = []
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        # document.xml
        content = z.read('word/document.xml')
        root = ET.fromstring(content)
        body = root.find(f"{{{NS['w']}}}body")
        
        for para in body.iter(f"{{{NS['w']}}}p"):
            texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
            text = ''.join(texts)[:30].strip()
            xml_paras.append({'text': text, 'source': 'document.xml'})
        
        # footnotes
        try:
            fn_content = z.read('word/footnotes.xml')
            fn_root = ET.fromstring(fn_content)
            for para in fn_root.iter(f"{{{NS['w']}}}p"):
                texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
                text = ''.join(texts)[:30].strip()
                xml_paras.append({'text': text, 'source': 'footnotes.xml'})
        except:
            pass
        
        # endnotes
        try:
            en_content = z.read('word/endnotes.xml')
            en_root = ET.fromstring(en_content)
            for para in en_root.iter(f"{{{NS['w']}}}p"):
                texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
                text = ''.join(texts)[:30].strip()
                xml_paras.append({'text': text, 'source': 'endnotes.xml'})
        except:
            pass
    
    print(f"\nWord paragraphs: {len(word_paras)}")
    print(f"XML paragraphs: {len(xml_paras)}")
    
    # 3. آخر 20 فقرة من Word
    print("\n=== LAST 20 PARAGRAPHS FROM WORD ===")
    for p in word_paras[-20:]:
        print(f"  {p['idx']:3d} | Page {p['page']:2d} | '{p['text']}'")
    
    # 4. آخر 10 فقرات من XML
    print("\n=== LAST 10 PARAGRAPHS FROM XML ===")
    for i, p in enumerate(xml_paras[-10:]):
        print(f"  {len(xml_paras)-10+i+1:3d} | {p['source']:15s} | '{p['text']}'")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        compare_paragraphs(sys.argv[1])
