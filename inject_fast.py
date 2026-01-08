"""
الحقن السريع - النسخة المحسنة
يستخدم XML للفواصل + Word فقط للتأكيد
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import os
import sys
import shutil
import time

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def register_namespaces():
    for prefix, uri in NS.items():
        ET.register_namespace(prefix, uri)
    ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    ET.register_namespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')
    ET.register_namespace('w14', 'http://schemas.microsoft.com/office/word/2010/wordml')
    ET.register_namespace('w15', 'http://schemas.microsoft.com/office/word/2012/wordml')
    ET.register_namespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')

def get_word_total_pages_fast(docx_path):
    """الحصول على عدد الصفحات فقط (سريع)"""
    print("Getting page count from Word...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = True
    word.DisplayAlerts = 0
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        total_pages = doc.ComputeStatistics(2)
        doc.Close(False)
        word.Quit()
        return total_pages
    except Exception as e:
        print(f"Error: {e}")
        try:
            word.Quit()
        except:
            pass
        return None

def create_hidden_run(page_num):
    run = ET.Element(f"{{{NS['w']}}}r")
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = f"{{{{PG:{page_num}}}}}"
    return run

def inject_into_para(para, page_num):
    hidden_run = create_hidden_run(page_num)
    pPr = para.find(f"{{{NS['w']}}}pPr")
    insert_index = 0
    if pPr is not None:
        for idx, child in enumerate(para):
            if child == pPr:
                insert_index = idx + 1
                break
    para.insert(insert_index, hidden_run)

def inject_fast(docx_path, output_path):
    """الحقن السريع باستخدام XML"""
    start_time = time.time()
    
    register_namespaces()
    
    # 1. الحصول على عدد الصفحات من Word (سريع)
    total_pages = get_word_total_pages_fast(docx_path)
    if not total_pages:
        print("ERROR: Could not get page count")
        return False
    
    print(f"Total pages: {total_pages}")
    
    # 2. قراءة XML وتحليل الفواصل
    print("Analyzing XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    # 3. جمع كل الفقرات وتحديد الصفحات من XML
    all_paras = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"Total paragraphs: {len(all_paras)}")
    
    current_page = 1
    injected = 0
    
    for para in all_paras:
        # حقن رقم الصفحة الحالية
        inject_into_para(para, current_page)
        injected += 1
        
        # البحث عن فواصل الصفحات في هذه الفقرة
        has_break = False
        
        for run in para.findall(f".//{{{NS['w']}}}r"):
            # lastRenderedPageBreak
            if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                has_break = True
            # manual page break
            for br in run.findall(f".//{{{NS['w']}}}br"):
                if br.get(f"{{{NS['w']}}}type") == "page":
                    has_break = True
        
        if has_break:
            current_page += 1
    
    # 4. معايرة مع عدد صفحات Word
    xml_pages = current_page
    print(f"XML detected pages: {xml_pages}")
    print(f"Word total pages: {total_pages}")
    
    if xml_pages != total_pages:
        diff = total_pages - xml_pages
        print(f"Difference: {diff} pages")
        # إذا كان الفرق إيجابي، هناك صفحات ناقصة
        # نوزعها على آخر الفقرات
    
    # 5. حفظ الملف
    print("Saving...")
    shutil.copy2(docx_path, output_path)
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        with zipfile.ZipFile(docx_path, 'r') as z_in:
            for item in z_in.infolist():
                if item.filename == 'word/document.xml':
                    z_out.writestr(item.filename, 
                                   ET.tostring(root, encoding='unicode', xml_declaration=True).encode('utf-8'))
                else:
                    z_out.writestr(item, z_in.read(item.filename))
    
    elapsed = time.time() - start_time
    
    # 6. التحقق
    import re
    with zipfile.ZipFile(output_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
    
    markers = re.findall(r'\{PG:(\d+)\}', content)
    pages = [int(m) for m in markers]
    
    print(f"\n=== RESULT ===")
    print(f"Time: {elapsed:.1f} seconds")
    print(f"Injected: {injected} markers")
    print(f"Page range: {min(pages)} to {max(pages)}")
    print(f"Word pages: {total_pages}")
    
    if max(pages) == total_pages:
        print("✓ MATCH!")
    else:
        print(f"⚠ Gap: {total_pages - max(pages)}")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_FAST.docx')
        inject_fast(input_path, output_path)
