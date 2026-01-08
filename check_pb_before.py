"""
فحص pageBreakBefore و sectPr
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def check_page_break_before(docx_path):
    print(f"Checking pageBreakBefore: {docx_path}\n")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    para_idx = 0
    for element in body:
        if element.tag == f"{{{NS['w']}}}p":
            para_idx += 1
            if para_idx > 20: break
            
            pPr = element.find(f"{{{NS['w']}}}pPr")
            if pPr is not None:
                # Check for pageBreakBefore
                pbBefore = pPr.find(f"{{{NS['w']}}}pageBreakBefore")
                if pbBefore is not None:
                    print(f"Para {para_idx}: >>> HAS pageBreakBefore! <<<")
                    continue
                
                # Check for sectPr
                sectPr = pPr.find(f"{{{NS['w']}}}sectPr")
                if sectPr is not None:
                    print(f"Para {para_idx}: >>> HAS sectPr (section break)! <<<")
                    continue
            
            # Get text preview
            texts = [t.text for t in element.findall(f".//{{{NS['w']}}}t") if t.text]
            text = ''.join(texts)[:30]
            print(f"Para {para_idx}: (normal) '{text}'")
    
    # Also check final sectPr in body
    final_sect = body.find(f"{{{NS['w']}}}sectPr")
    if final_sect is not None:
        type_elem = final_sect.find(f"{{{NS['w']}}}type")
        if type_elem is not None:
            w_ns = NS['w']
            print(f"\nFinal sectPr type: {type_elem.get(f'{{{w_ns}}}val')}")
        else:
            print("\nFinal sectPr exists (default type)")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        check_page_break_before(sys.argv[1])
