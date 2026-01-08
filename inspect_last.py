"""
فحص آخر 20 فقرة في document.xml
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def inspect_last_paragraphs(docx_path):
    print(f"Inspecting last paragraphs: {docx_path}\n")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    all_p = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"Total paragraphs: {len(all_p)}")
    
    print("\n=== LAST 20 PARAGRAPHS ===")
    for i, para in enumerate(all_p[-20:]):
        idx = len(all_p) - 20 + i + 1
        
        # النص
        texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
        text = ''.join(texts)[:40].strip()
        
        # هل داخل txbxContent؟
        # (صعب التحقق مباشرة، نتجاوز)
        
        print(f"{idx:3d}: '{text}'")
    
    # أيضاً، فحص الـ sectPr الأخير
    final_sect = body.find(f"{{{NS['w']}}}sectPr")
    if final_sect is not None:
        print("\n[Final sectPr found at end of body]")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        inspect_last_paragraphs(sys.argv[1])
