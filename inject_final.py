"""
حقن أرقام الصفحات - النسخة النهائية الشاملة
يشمل: document.xml + footnotes.xml + endnotes.xml
يستخدم iter() للوصول لكل الفقرات
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
    """الحصول على رقم الصفحة لكل فقرة"""
    print("Opening Word to get page numbers...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    page_numbers = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        main_range = doc.Content
        total_paras = main_range.Paragraphs.Count
        print(f"Total paragraphs: {total_paras}")
        
        for i in range(1, total_paras + 1):
            try:
                para = main_range.Paragraphs(i)
                page_num = para.Range.Information(3)
                page_numbers.append(page_num)
                
                if i % 100 == 0:
                    print(f"  Processed {i}/{total_paras}...")
            except:
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

def inject_full(docx_path, output_path):
    register_namespaces()
    
    # 1. الحصول على أرقام الصفحات
    page_numbers, total_pages = get_all_page_numbers_from_word(docx_path)
    
    if not page_numbers:
        print("ERROR: Could not get page numbers")
        return False
    
    # 2. نسخ الملف
    shutil.copy2(docx_path, output_path)
    
    # 3. قراءة الملفات
    print("Processing XML files...")
    
    modified_files = {}
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        # قراءة document.xml
        doc_content = z.read('word/document.xml')
        doc_root = ET.fromstring(doc_content)
        body = doc_root.find(f"{{{NS['w']}}}body")
        
        # جمع كل الفقرات باستخدام iter()
        all_paras_in_body = list(body.iter(f"{{{NS['w']}}}p"))
        print(f"Paragraphs in document.xml (iter): {len(all_paras_in_body)}")
        
        # حقن الـ markers
        para_idx = 0
        injected = 0
        
        for para in all_paras_in_body:
            if para_idx < len(page_numbers) and page_numbers[para_idx] > 0:
                inject_into_para(para, page_numbers[para_idx])
                injected += 1
            para_idx += 1
        
        modified_files['word/document.xml'] = ET.tostring(doc_root, encoding='unicode', xml_declaration=True)
        
        # معالجة footnotes.xml إن وجد
        try:
            fn_content = z.read('word/footnotes.xml')
            fn_root = ET.fromstring(fn_content)
            fn_paras = list(fn_root.iter(f"{{{NS['w']}}}p"))
            print(f"Paragraphs in footnotes.xml: {len(fn_paras)}")
            
            for para in fn_paras:
                if para_idx < len(page_numbers) and page_numbers[para_idx] > 0:
                    inject_into_para(para, page_numbers[para_idx])
                    injected += 1
                para_idx += 1
            
            modified_files['word/footnotes.xml'] = ET.tostring(fn_root, encoding='unicode', xml_declaration=True)
        except:
            pass
        
        # معالجة endnotes.xml إن وجد
        try:
            en_content = z.read('word/endnotes.xml')
            en_root = ET.fromstring(en_content)
            en_paras = list(en_root.iter(f"{{{NS['w']}}}p"))
            print(f"Paragraphs in endnotes.xml: {len(en_paras)}")
            
            for para in en_paras:
                if para_idx < len(page_numbers) and page_numbers[para_idx] > 0:
                    inject_into_para(para, page_numbers[para_idx])
                    injected += 1
                para_idx += 1
            
            modified_files['word/endnotes.xml'] = ET.tostring(en_root, encoding='unicode', xml_declaration=True)
        except:
            pass
    
    # 4. حفظ الملف
    print("Saving...")
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        with zipfile.ZipFile(docx_path, 'r') as z_in:
            for item in z_in.infolist():
                if item.filename in modified_files:
                    z_out.writestr(item.filename, modified_files[item.filename].encode('utf-8'))
                else:
                    z_out.writestr(item, z_in.read(item.filename))
    
    # 5. التحقق
    print(f"\n=== SUMMARY ===")
    print(f"Word paragraphs: {len(page_numbers)}")
    print(f"Processed: {para_idx}")
    print(f"Injected: {injected}")
    print(f"Total pages: {total_pages}")
    
    with zipfile.ZipFile(output_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
    
    import re
    markers = re.findall(r'\{PG:(\d+)\}', content)
    pages = [int(m) for m in markers] if markers else []
    
    print(f"\n=== VERIFICATION ===")
    print(f"Markers in document.xml: {len(markers)}")
    if pages:
        print(f"Page range: {min(pages)} to {max(pages)}")
        print(f"First 10: {markers[:10]}")
        
        if max(pages) == total_pages:
            print(f"\n✓ SUCCESS: Coverage complete!")
        else:
            diff = total_pages - max(pages)
            print(f"\n⚠ Missing last {diff} page(s) - likely in footnotes/endnotes")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_FINAL.docx')
        inject_full(input_path, output_path)
