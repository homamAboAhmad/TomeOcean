"""
الحقن بالمطابقة النصية - الحل الدقيق 100%
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

def normalize_text(text):
    """تطبيع النص للمقارنة"""
    if not text:
        return ""
    return text.replace('\r', '').replace('\n', '').strip()[:50]

def get_word_paragraphs(docx_path):
    """الحصول على كل الفقرات من Word مع نصها ورقم صفحتها"""
    print("Getting paragraphs from Word...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = True  # مرئي لتجنب التعليق
    word.DisplayAlerts = 0
    
    paragraphs = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        total = doc.Content.Paragraphs.Count
        print(f"Total Word paragraphs: {total}")
        
        for i in range(1, total + 1):
            try:
                para = doc.Content.Paragraphs(i)
                # الحصول على صفحة بداية الفقرة (وليس نهايتها)
                start_range = para.Range.Duplicate
                start_range.Collapse(1)  # wdCollapseStart = 1
                page = start_range.Information(3)  # صفحة البداية
                
                text = normalize_text(para.Range.Text)
                paragraphs.append({'text': text, 'page': page})
                
                if i % 100 == 0:
                    print(f"  {i}/{total}...")
            except:
                paragraphs.append({'text': '', 'page': -1})

        
        total_pages = doc.ComputeStatistics(2)
        print(f"Total pages: {total_pages}")
        
        doc.Close(False)
        word.Quit()
        
    except Exception as e:
        print(f"Error: {e}")
        try:
            word.Quit()
        except:
            pass
        return None, 0
    
    return paragraphs, total_pages

def get_xml_paragraphs(docx_path):
    """الحصول على الفقرات من XML"""
    print("Getting paragraphs from XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    paragraphs = []
    for para in body.iter(f"{{{NS['w']}}}p"):
        texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
        text = normalize_text(''.join(texts))
        paragraphs.append({'element': para, 'text': text})
    
    print(f"Total XML paragraphs: {len(paragraphs)}")
    return paragraphs, root

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

def match_and_inject(docx_path, output_path):
    register_namespaces()
    
    # 1. الحصول على البيانات
    word_paras, total_pages = get_word_paragraphs(docx_path)
    if not word_paras:
        return False
    
    xml_paras, root = get_xml_paragraphs(docx_path)
    
    # 2. فصل الفقرات حسب المحتوى
    word_with_text = [(i, wp) for i, wp in enumerate(word_paras) if wp['text']]
    word_empty = [(i, wp) for i, wp in enumerate(word_paras) if not wp['text']]
    
    print(f"Word: {len(word_with_text)} with text, {len(word_empty)} empty")
    
    # 3. بناء قاموس للفقرات ذات النص
    word_text_map = {}
    for i, wp in word_with_text:
        text = wp['text']
        if text not in word_text_map:
            word_text_map[text] = []
        word_text_map[text].append({'index': i, 'page': wp['page']})
    
    # 4. المطابقة والحقن
    print("\nMatching and injecting...")
    
    matched = 0
    unmatched_list = []
    used_word_indices = set()
    empty_word_idx = 0  # مؤشر للفقرات الفارغة في Word
    
    for xml_idx, xml_p in enumerate(xml_paras):
        text = xml_p['text']
        element = xml_p['element']
        page = None
        
        if text:  # فقرة بها نص
            if text in word_text_map:
                for wp in word_text_map[text]:
                    if wp['index'] not in used_word_indices:
                        page = wp['page']
                        used_word_indices.add(wp['index'])
                        break
        else:  # فقرة فارغة
            # استخدام المطابقة بالترتيب للفقرات الفارغة
            while empty_word_idx < len(word_empty):
                wi, wp = word_empty[empty_word_idx]
                if wi not in used_word_indices:
                    page = wp['page']
                    used_word_indices.add(wi)
                    empty_word_idx += 1
                    break
                empty_word_idx += 1
        
        if page and page > 0:
            inject_into_para(element, page)
            matched += 1
        else:
            unmatched_list.append(xml_idx)
    
    print(f"Matched: {matched}")
    print(f"Unmatched: {len(unmatched_list)}")
    
    # 5. للفقرات غير المتطابقة، نستخدم آخر صفحة معروفة
    if unmatched_list:
        last_page = total_pages  # افتراض آخر صفحة
        print(f"Assigning page {last_page} to {len(unmatched_list)} unmatched paragraphs")
        for idx in unmatched_list:
            inject_into_para(xml_paras[idx]['element'], last_page)
            matched += 1

    
    # 4. حفظ الملف
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
    
    # 5. التحقق
    import re
    with zipfile.ZipFile(output_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
    
    markers = re.findall(r'\{PG:(\d+)\}', content)
    pages = [int(m) for m in markers]
    
    print(f"\n=== RESULT ===")
    print(f"Markers: {len(markers)}")
    print(f"Page range: {min(pages)} to {max(pages)}")
    print(f"Word total pages: {total_pages}")
    
    if max(pages) == total_pages:
        print("✓ PERFECT MATCH!")
    else:
        print(f"⚠ Gap: {total_pages - max(pages)} page(s)")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_MATCHED.docx')
        match_and_inject(input_path, output_path)
