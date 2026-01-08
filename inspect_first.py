"""
فحص أول 10 عناصر في المستند بالتفصيل
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def inspect_first_elements(docx_path, count=15):
    print(f"Inspecting first {count} elements: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    elements = list(body)
    
    for i, elem in enumerate(elements[:count]):
        tag = elem.tag.split('}')[1] if '}' in elem.tag else elem.tag
        
        print(f"\n{'='*50}")
        print(f"Element {i+1}: <w:{tag}>")
        
        if tag == 'p':
            # فحص الفقرة
            # هل فيها pPr؟
            pPr = elem.find(f"{{{NS['w']}}}pPr")
            if pPr is not None:
                # هل فيها sectPr (section break)?
                sectPr = pPr.find(f"{{{NS['w']}}}sectPr")
                if sectPr is not None:
                    print("  >>> Contains SECTION PROPERTIES (sectPr)!")
                    type_elem = sectPr.find(f"{{{NS['w']}}}type")
                    if type_elem is not None:
                        w_ns = NS['w']
                        val = type_elem.get(f"{{{w_ns}}}val")
                        print(f"      Section type: {val}")
                    else:
                        print("      Section type: nextPage (implicit)")
                
                # pageBreakBefore?
                pbBefore = pPr.find(f"{{{NS['w']}}}pageBreakBefore")
                if pbBefore is not None:
                    print("  >>> Has pageBreakBefore property!")
            
            # البحث عن breaks
            breaks = []
            for run in elem.findall(f".//{{{NS['w']}}}r"):
                if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                    breaks.append("lastRenderedPageBreak")
                for br in run.findall(f".//{{{NS['w']}}}br"):
                    if br.get(f"{{{NS['w']}}}type") == "page":
                        breaks.append("manual br:page")
            
            if breaks:
                print(f"  Breaks: {breaks}")
            
            # النص
            texts = []
            for t in elem.findall(f".//{{{NS['w']}}}t"):
                if t.text:
                    texts.append(t.text)
            text = ''.join(texts)[:60]
            print(f"  Text: '{text}'")
            
        elif tag == 'tbl':
            # جدول
            rows = len(elem.findall(f".//{{{NS['w']}}}tr"))
            cells = len(elem.findall(f".//{{{NS['w']}}}tc"))
            print(f"  Table with {rows} rows, {cells} cells")
            
            # هل يوجد فواصل صفحات في الجدول؟
            breaks_in_tbl = len(elem.findall(f".//{{{NS['w']}}}lastRenderedPageBreak"))
            if breaks_in_tbl:
                print(f"  >>> Contains {breaks_in_tbl} lastRenderedPageBreak!")
        
        elif tag == 'sectPr':
            print("  Final section properties")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        inspect_first_elements(sys.argv[1])
