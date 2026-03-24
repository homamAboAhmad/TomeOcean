"""Check TOC styles and indentation in a docx file."""
import zipfile
import re
import xml.etree.ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def check_toc(path):
    z = zipfile.ZipFile(path, 'r')
    
    # 1. Check styles
    styles_xml = z.read('word/styles.xml').decode('utf-8')
    root = ET.fromstring(styles_xml)
    
    print("=== TOC Styles ===")
    for style in root.findall('.//w:style', NS):
        sid = style.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}styleId', '')
        if 'toc' in sid.lower() or 'TOC' in sid:
            print(f"\nStyle: {sid}")
            pPr = style.find('w:pPr', NS)
            if pPr is not None:
                ind = pPr.find('w:ind', NS)
                if ind is not None:
                    print(f"  w:ind attrs: {dict(ind.attrib)}")
                else:
                    print("  No w:ind element")
                tabs = pPr.find('w:tabs', NS)
                if tabs is not None:
                    for tab in tabs.findall('w:tab', NS):
                        print(f"  tab: {dict(tab.attrib)}")
            else:
                print("  No w:pPr")
    
    # 2. Check first few TOC paragraphs in document.xml
    doc_xml = z.read('word/document.xml').decode('utf-8')
    doc_root = ET.fromstring(doc_xml)
    
    print("\n=== First 10 TOC paragraphs in document ===")
    count = 0
    for p in doc_root.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p'):
        pPr = p.find('w:pPr', NS)
        if pPr is None:
            continue
        pStyle = pPr.find('w:pStyle', NS)
        if pStyle is None:
            continue
        val = pStyle.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val', '')
        if 'toc' in val.lower() or 'TOC' in val:
            # Get text
            texts = [t.text or '' for t in p.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t')]
            text_preview = ''.join(texts)[:60]
            print(f"\n  Style: {val}, Text: {text_preview}")
            ind = pPr.find('w:ind', NS)
            if ind is not None:
                print(f"    w:ind: {dict(ind.attrib)}")
            else:
                print(f"    No w:ind in paragraph pPr")
            count += 1
            if count >= 10:
                break
    
    z.close()

check_toc(r'C:\Users\HP\Documents\ex10_50p.docx')
