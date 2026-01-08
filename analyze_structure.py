"""
تحليل الفقرات داخل الجداول
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def analyze_structure(docx_path):
    print(f"Analyzing structure: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    # عد الفقرات في المستوى الأول
    top_level_p = 0
    top_level_tbl = 0
    paras_in_tables = 0
    
    for element in body:
        if element.tag == f"{{{NS['w']}}}p":
            top_level_p += 1
        elif element.tag == f"{{{NS['w']}}}tbl":
            top_level_tbl += 1
            # عد الفقرات داخل الجدول
            for p in element.findall(f".//{{{NS['w']}}}p"):
                paras_in_tables += 1
    
    # عد كل الفقرات في المستند (بما فيها المتداخلة)
    all_paras = len(list(body.iter(f"{{{NS['w']}}}p")))
    
    print(f"\n=== Structure Analysis ===")
    print(f"Top-level paragraphs: {top_level_p}")
    print(f"Top-level tables: {top_level_tbl}")
    print(f"Paragraphs INSIDE tables: {paras_in_tables}")
    print(f"Total ALL paragraphs (including nested): {all_paras}")
    print(f"Expected Word count: {top_level_p + paras_in_tables}")
    
    # البحث عن فواصل الصفحات في الجداول
    breaks_in_tables = 0
    for tbl in body.findall(f".//{{{NS['w']}}}tbl"):
        for br in tbl.findall(f".//{{{NS['w']}}}lastRenderedPageBreak"):
            breaks_in_tables += 1
        for br in tbl.findall(f".//{{{NS['w']}}}br"):
            if br.get(f"{{{NS['w']}}}type") == "page":
                breaks_in_tables += 1
    
    print(f"Page breaks INSIDE tables: {breaks_in_tables}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        analyze_structure(sys.argv[1])
