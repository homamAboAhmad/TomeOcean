"""
البحث الشامل عن كل الفقرات في كل ملفات XML
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def search_all_xml(docx_path):
    print(f"Searching ALL XML files: {docx_path}\n")
    
    total_paras = 0
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_files = [f for f in z.namelist() if f.endswith('.xml')]
        
        for xml_file in sorted(xml_files):
            try:
                content = z.read(xml_file)
                root = ET.fromstring(content)
                
                # عد الفقرات
                paras = list(root.iter(f"{{{NS['w']}}}p"))
                
                if paras:
                    print(f"{xml_file}: {len(paras)} paragraphs")
                    total_paras += len(paras)
                    
            except Exception as e:
                pass
    
    print(f"\n=== TOTAL: {total_paras} paragraphs ===")
    print(f"Word says: 287")
    print(f"Difference: {287 - total_paras}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        search_all_xml(sys.argv[1])
