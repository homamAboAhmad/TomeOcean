
import zipfile
import xml.etree.ElementTree as ET
import os
import shutil
import win32com.client as win32

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def create_partial_docx(src_path, dest_path, start_idx, end_idx):
    # نسخ الملف الأصلي
    shutil.copy2(src_path, dest_path)
    
    # تعديل document.xml للاحتفاظ فقط بالنطاق المحدد من الفقرات
    with zipfile.ZipFile(src_path, 'r') as z_in:
        xml_content = z_in.read('word/document.xml')
        
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    # جمع كل الفقرات (بما فيها الجداول ككتلة واحدة)
    all_elements = list(body)
    
    # العناصر التي سنحذفها (خارج النطاق)
    # ملاحظة: آخر عنصر هو sectPr لا نحذفه
    elements_to_remove = []
    
    content_elements = [e for e in all_elements if e.tag != f"{{{NS['w']}}}sectPr"]
    
    # تحديد النطاق
    actual_end = min(end_idx, len(content_elements))
    
    # حذف ما قبل البداية
    for i in range(start_idx):
        if i < len(content_elements):
            body.remove(content_elements[i])
            
    # حذف ما بعد النهاية
    for i in range(actual_end, len(content_elements)):
        body.remove(content_elements[i])
        
    # حفظ الملف الجديد
    with zipfile.ZipFile(dest_path, 'w', zipfile.ZIP_DEFLATED) as z_out:
        # نسخ باقي الملفات كما هي
        with zipfile.ZipFile(src_path, 'r') as z_in:
             for item in z_in.infolist():
                 if item.filename != 'word/document.xml':
                     z_out.writestr(item, z_in.read(item.filename))
        
        # كتابة document.xml المعدل
        z_out.writestr('word/document.xml', ET.tostring(root, encoding='UTF-8', xml_declaration=True))

def count_pages_word(file_path):
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    try:
        doc = word.Documents.Open(file_path, ReadOnly=True)
        # Force repaginate locally
        doc.Repaginate()
        count = doc.ComputeStatistics(2) # wdStatisticPages
        doc.Close(False)
        return count
    except Exception as e:
        print(f"Error counting pages: {e}")
        return -1
    finally:
        try:
            word.Quit()
        except:
            pass

def analyze_chunk(file_path, chunk_name):
    # 1. Count using Word (Truth)
    print(f"[{chunk_name}] Counting Word pages...", end=' ', flush=True)
    word_count = count_pages_word(file_path)
    print(f"{word_count}")
    
    # 2. Count using XML Logic (Ours)
    print(f"[{chunk_name}] Counting XML pages...", end=' ', flush=True)
    
    # Simple XML Counter based on our current logic in pageRender.py
    with zipfile.ZipFile(file_path, 'r') as z:
        xml = z.read('word/document.xml')
    
    root = ET.fromstring(xml)
    body = root.find(f"{{{NS['w']}}}body")
    
    xml_count = 1
    # ... (Here I will replicate the exact logic we have in pageRender.py currently)
    # For now, let's use a simplified version to detect the delta
    
    # NOTE: Replicating full logic is complex here, but I will do a quick scan 
    # using current pageRender logic manually injected here or by calling the script?
    # Better: Use the same logic
    
    # Let's count simple breaks first to see raw data
    manual = 0
    last = 0
    for e in body.iter():
        if e.tag == f"{{{NS['w']}}}br" and e.get(f"{{{NS['w']}}}type") == 'page':
            manual += 1
        elif e.tag == f"{{{NS['w']}}}lastRenderedPageBreak":
            last += 1
            
    print(f"Raw XML: Manual={manual}, Last={last} => RawSum={manual+last}")
    print(f"[{chunk_name}] Delta: { (manual+last) - word_count } (Approx)")

def main_bisect(docx_path):
    print(f"Bisecting: {docx_path}")
    
    # 1. Count total elements
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    total_elements = len([e for e in body])
    print(f"Total Body Elements: {total_elements}")
    
    # 2. Split into 5 chunks
    chunk_size = total_elements // 5
    abspath = os.path.abspath(docx_path)
    base_dir = os.path.dirname(abspath)
    
    for i in range(5):
        start = i * chunk_size
        end = (i + 1) * chunk_size
        if i == 4: end = total_elements # catch remaining
        
        chunk_name = f"chunk_{i+1}.docx"
        chunk_path = os.path.join(base_dir, chunk_name)
        
        print(f"\nCreating {chunk_name} (Elements {start} to {end})...")
        create_partial_docx(abspath, chunk_path, start, end)
        
        analyze_chunk(chunk_path, chunk_name)
        
        # Cleanup
        try: os.remove(chunk_path)
        except: pass

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main_bisect(sys.argv[1])
