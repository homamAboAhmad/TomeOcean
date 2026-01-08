"""
حقن أرقام الصفحات باستخدام Word API مباشرة
هذا يضمن دقة 100% لأننا نسأل Word نفسه عن رقم الصفحة
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import os
import sys
import shutil
import tempfile

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def register_namespaces():
    """تسجيل الـ namespaces للحفاظ على البادئات"""
    for prefix, uri in NS.items():
        ET.register_namespace(prefix, uri)
    # تسجيل namespaces إضافية شائعة
    ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    ET.register_namespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')
    ET.register_namespace('w14', 'http://schemas.microsoft.com/office/word/2010/wordml')
    ET.register_namespace('w15', 'http://schemas.microsoft.com/office/word/2012/wordml')
    ET.register_namespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')

def get_page_numbers_from_word(docx_path):
    """استخدام Word API للحصول على رقم الصفحة لكل فقرة"""
    print("Opening Word to get actual page numbers...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    page_numbers = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        total_paras = doc.Content.Paragraphs.Count
        print(f"Total paragraphs: {total_paras}")
        
        for i in range(1, total_paras + 1):
            try:
                para = doc.Content.Paragraphs(i)
                page_num = para.Range.Information(3)  # wdActiveEndPageNumber
                page_numbers.append(page_num)
                
                if i % 100 == 0:
                    print(f"  Processed {i}/{total_paras}...")
            except:
                page_numbers.append(-1)  # خطأ
        
        total_pages = doc.ComputeStatistics(2)  # wdStatisticPages
        print(f"Total pages according to Word: {total_pages}")
        
        doc.Close(False)
        
    finally:
        try:
            word.Quit()
        except:
            pass
    
    return page_numbers, total_pages

def create_hidden_run_element(text):
    """إنشاء w:r مخفي يحتوي على النص"""
    run = ET.Element(f"{{{NS['w']}}}r")
    
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    vanish = ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = text
    
    return run

def inject_page_numbers_using_word_api(docx_path, output_path):
    """حقن أرقام الصفحات من Word API في XML"""
    
    register_namespaces()
    
    # 1. الحصول على أرقام الصفحات من Word
    page_numbers, total_pages = get_page_numbers_from_word(docx_path)
    
    if not page_numbers:
        print("ERROR: Could not get page numbers from Word")
        return False
    
    # 2. نسخ الملف
    shutil.copy2(docx_path, output_path)
    
    # 3. قراءة وتعديل XML
    print("Injecting page numbers into XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z_in:
        xml_content = z_in.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    para_index = 0
    injected_count = 0
    
    for element in body:
        if element.tag == f"{{{NS['w']}}}p":
            if para_index < len(page_numbers):
                page_num = page_numbers[para_index]
                
                # إنشاء hidden run
                hidden_run = create_hidden_run_element(f"{{{{PG:{page_num}}}}}")
                
                # إدراج في بداية الفقرة (بعد pPr إن وجد)
                pPr = element.find(f"{{{NS['w']}}}pPr")
                insert_index = 0
                if pPr is not None:
                    for idx, child in enumerate(element):
                        if child == pPr:
                            insert_index = idx + 1
                            break
                
                element.insert(insert_index, hidden_run)
                injected_count += 1
            
            para_index += 1
    
    # 4. حفظ الملف المعدل
    print(f"Saving modified file...")
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        with zipfile.ZipFile(docx_path, 'r') as z_in:
            for item in z_in.infolist():
                if item.filename != 'word/document.xml':
                    z_out.writestr(item, z_in.read(item.filename))
        
        z_out.writestr('word/document.xml', 
                       ET.tostring(root, encoding='unicode', xml_declaration=True).encode('utf-8'))
    
    print(f"\n=== SUMMARY ===")
    print(f"Total paragraphs in Word: {len(page_numbers)}")
    print(f"Paragraphs in XML body: {para_index}")
    print(f"Injected markers: {injected_count}")
    print(f"Total pages: {total_pages}")
    print(f"Output: {output_path}")
    
    return True

def verify_injection(output_path):
    """التحقق من الحقن"""
    print("\n=== VERIFICATION ===")
    
    with zipfile.ZipFile(output_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    # البحث عن علامات الصفحات
    import re
    markers = re.findall(r'\{PG:(\d+)\}', xml_content.decode('utf-8'))
    
    if markers:
        print(f"Found {len(markers)} page markers")
        print(f"First 10: {markers[:10]}")
        print(f"Last 10: {markers[-10:]}")
        
        # التحقق من التسلسل
        unique_pages = sorted(set(int(m) for m in markers))
        print(f"Pages covered: {unique_pages[:20]}...")
        print(f"Max page: {max(unique_pages)}")
    else:
        print("ERROR: No markers found!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_WORD_API.docx')
        
        if inject_page_numbers_using_word_api(input_path, output_path):
            verify_injection(output_path)
    else:
        print("Usage: python inject_word_api.py <docx_path>")
