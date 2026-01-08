"""
البحث عن الفقرات المفقودة
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def find_all_paragraphs(docx_path):
    print(f"Searching all paragraphs: {docx_path}\n")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        # 1. Main document
        xml_content = z.read('word/document.xml')
        root = ET.fromstring(xml_content)
        body = root.find(f"{{{NS['w']}}}body")
        
        # Count different ways
        direct_p = len([e for e in body if e.tag == f"{{{NS['w']}}}p"])
        all_p_iter = len(list(body.iter(f"{{{NS['w']}}}p")))
        
        # Tables
        tables = body.findall(f".//{{{NS['w']}}}tbl")
        p_in_tables = 0
        for tbl in tables:
            p_in_tables += len(list(tbl.iter(f"{{{NS['w']}}}p")))
        
        # SDT (Structured Document Tags - like Table of Contents)
        sdts = body.findall(f".//{{{NS['w']}}}sdt")
        p_in_sdts = 0
        for sdt in sdts:
            p_in_sdts += len(list(sdt.iter(f"{{{NS['w']}}}p")))
        
        # Text boxes (in drawings)
        # These are in different namespace
        
        print("=== document.xml ===")
        print(f"Direct <w:p> in body: {direct_p}")
        print(f"All <w:p> via iter(): {all_p_iter}")
        print(f"Tables found: {len(tables)}")
        print(f"<w:p> inside tables: {p_in_tables}")
        print(f"SDT elements: {len(sdts)}")
        print(f"<w:p> inside SDTs: {p_in_sdts}")
        
        # 2. Check for other XML files
        print("\n=== Other XML files ===")
        xml_files = [f for f in z.namelist() if f.endswith('.xml')]
        
        for xml_file in xml_files:
            if xml_file == 'word/document.xml':
                continue
            if 'header' in xml_file or 'footer' in xml_file or 'footnote' in xml_file or 'endnote' in xml_file:
                try:
                    content = z.read(xml_file)
                    file_root = ET.fromstring(content)
                    p_count = len(list(file_root.iter(f"{{{NS['w']}}}p")))
                    if p_count > 0:
                        print(f"{xml_file}: {p_count} paragraphs")
                except:
                    pass

if __name__ == "__main__":
    if len(sys.argv) > 1:
        find_all_paragraphs(sys.argv[1])
