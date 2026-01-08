"""
اختبار باستخدام lxml بدلاً من ElementTree
"""
from lxml import etree as ET
import zipfile
import os
import sys
import shutil

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def create_hidden_run(page_num):
    """إنشاء عنصر hidden run باستخدام lxml"""
    nsmap = {'w': NS['w']}
    run = ET.Element(f"{{{NS['w']}}}r", nsmap=nsmap)
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = f"{{{{PG:{page_num}}}}}"
    return run

def test_lxml(docx_path, output_path):
    print("Testing with lxml...")
    
    # قراءة XML من zip
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    # Parse باستخدام lxml
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    if body is None:
        print("ERROR: No body found")
        return
    
    # جمع الفقرات
    all_paras = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"Found {len(all_paras)} paragraphs")
    
    # حقن أرقام تجريبية (1 لكل فقرة)
    for i, para in enumerate(all_paras[:5]):  # أول 5 فقط للاختبار
        hidden_run = create_hidden_run(1)
        pPr = para.find(f"{{{NS['w']}}}pPr")
        insert_index = 0
        if pPr is not None:
            insert_index = list(para).index(pPr) + 1
        para.insert(insert_index, hidden_run)
    
    print("Injected test markers")
    
    # حفظ
    shutil.copy2(docx_path, output_path)
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        with zipfile.ZipFile(docx_path, 'r') as z_in:
            for item in z_in.infolist():
                if item.filename == 'word/document.xml':
                    # استخدام lxml للكتابة
                    xml_bytes = ET.tostring(root, encoding='UTF-8', xml_declaration=True)
                    z_out.writestr(item.filename, xml_bytes)
                else:
                    z_out.writestr(item, z_in.read(item.filename))
    
    print(f"Saved to: {output_path}")
    print("Try opening in Word!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_LXML.docx')
        test_lxml(input_path, output_path)
    else:
        print("Usage: python test_lxml.py <docx_path>")
