"""
حقن أرقام الصفحات باستخدام Word API - النسخة الكاملة
يشمل كل الفقرات (العادية + داخل الجداول)
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import os
import sys
import shutil

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def register_namespaces():
    for prefix, uri in NS.items():
        ET.register_namespace(prefix, uri)
    ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    ET.register_namespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')
    ET.register_namespace('w14', 'http://schemas.microsoft.com/office/word/2010/wordml')
    ET.register_namespace('w15', 'http://schemas.microsoft.com/office/word/2012/wordml')
    ET.register_namespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')

def get_all_page_numbers_from_word(docx_path):
    """الحصول على رقم الصفحة لكل فقرة في المستند"""
    print("Opening Word to get actual page numbers...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    page_numbers = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        # الحصول على كل الفقرات من المحتوى الرئيسي
        main_range = doc.Content
        total_paras = main_range.Paragraphs.Count
        print(f"Total paragraphs in main content: {total_paras}")
        
        for i in range(1, total_paras + 1):
            try:
                para = main_range.Paragraphs(i)
                page_num = para.Range.Information(3)  # wdActiveEndPageNumber
                page_numbers.append(page_num)
                
                if i % 100 == 0:
                    print(f"  Processed {i}/{total_paras}...")
            except Exception as e:
                print(f"  Error at para {i}: {e}")
                page_numbers.append(-1)
        
        total_pages = doc.ComputeStatistics(2)
        print(f"Total pages: {total_pages}")
        
        doc.Close(False)
        
    finally:
        try:
            word.Quit()
        except:
            pass
    
    return page_numbers, total_pages

def create_hidden_run_element(text):
    run = ET.Element(f"{{{NS['w']}}}r")
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = text
    return run

def inject_into_paragraph(para, page_num):
    """حقن marker في فقرة واحدة"""
    hidden_run = create_hidden_run_element(f"{{{{PG:{page_num}}}}}")
    
    pPr = para.find(f"{{{NS['w']}}}pPr")
    insert_index = 0
    if pPr is not None:
        for idx, child in enumerate(para):
            if child == pPr:
                insert_index = idx + 1
                break
    
    para.insert(insert_index, hidden_run)

def inject_page_numbers_complete(docx_path, output_path):
    """حقن أرقام الصفحات - النسخة الكاملة"""
    
    register_namespaces()
    
    # 1. الحصول على أرقام الصفحات من Word
    page_numbers, total_pages = get_all_page_numbers_from_word(docx_path)
    
    if not page_numbers:
        print("ERROR: Could not get page numbers from Word")
        return False
    
    # 2. نسخ الملف
    shutil.copy2(docx_path, output_path)
    
    # 3. قراءة XML
    print("Reading XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    # 4. جمع كل الفقرات بالترتيب (بما في ذلك داخل الجداول)
    # نستخدم طريقة التكرار على عناصر body بالترتيب
    all_paragraphs = []
    
    def collect_paragraphs(element):
        """جمع الفقرات بالترتيب الصحيح"""
        for child in element:
            if child.tag == f"{{{NS['w']}}}p":
                all_paragraphs.append(child)
            elif child.tag == f"{{{NS['w']}}}tbl":
                # الجدول: نجمع فقراته بالترتيب
                for tbl_para in child.iter(f"{{{NS['w']}}}p"):
                    all_paragraphs.append(tbl_para)
            elif child.tag == f"{{{NS['w']}}}sdt":
                # Structured Document Tag: قد يحتوي على فقرات
                for sdt_para in child.iter(f"{{{NS['w']}}}p"):
                    all_paragraphs.append(sdt_para)
    
    collect_paragraphs(body)
    
    print(f"Found {len(all_paragraphs)} paragraphs in XML (including tables)")
    print(f"Word reported {len(page_numbers)} paragraphs")
    
    # 5. حقن الـ markers
    print("Injecting markers...")
    
    injected = 0
    min_count = min(len(all_paragraphs), len(page_numbers))
    
    for i in range(min_count):
        page_num = page_numbers[i]
        para = all_paragraphs[i]
        
        if page_num > 0:
            inject_into_paragraph(para, page_num)
            injected += 1
    
    # 6. حفظ الملف
    print("Saving file...")
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        with zipfile.ZipFile(docx_path, 'r') as z_in:
            for item in z_in.infolist():
                if item.filename != 'word/document.xml':
                    z_out.writestr(item, z_in.read(item.filename))
        
        xml_str = ET.tostring(root, encoding='unicode', xml_declaration=True)
        z_out.writestr('word/document.xml', xml_str.encode('utf-8'))
    
    # 7. التحقق
    print(f"\n=== SUMMARY ===")
    print(f"Word paragraphs: {len(page_numbers)}")
    print(f"XML paragraphs: {len(all_paragraphs)}")
    print(f"Injected: {injected}")
    print(f"Total pages: {total_pages}")
    
    # التحقق من الـ markers
    with zipfile.ZipFile(output_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
    
    import re
    markers = re.findall(r'\{PG:(\d+)\}', content)
    
    if markers:
        pages = [int(m) for m in markers]
        print(f"\n=== VERIFICATION ===")
        print(f"Markers found: {len(markers)}")
        print(f"Page range: {min(pages)} to {max(pages)}")
        print(f"First 15: {markers[:15]}")
        print(f"Last 10: {markers[-10:]}")
        
        if max(pages) == total_pages:
            print(f"\n✓ SUCCESS: Max page ({max(pages)}) matches Word total ({total_pages})")
        else:
            print(f"\n⚠ WARNING: Max page ({max(pages)}) != Word total ({total_pages})")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_COMPLETE.docx')
        inject_page_numbers_complete(input_path, output_path)
    else:
        print("Usage: python inject_complete.py <docx_path>")
