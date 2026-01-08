"""
الحقن الهجين المحسن
- XML لتحديد الفواصل
- Word API للتأكيد عند الفواصل فقط
- استنتاج أرقام الفقرات الأخرى
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

def normalize_text(text):
    if not text:
        return ""
    return text.replace('\r', '').replace('\n', '').strip()[:80]

def has_page_break(para):
    """التحقق من وجود فاصل صفحة في الفقرة"""
    for run in para.findall(f".//{{{NS['w']}}}r"):
        if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
            return True
        for br in run.findall(f".//{{{NS['w']}}}br"):
            if br.get(f"{{{NS['w']}}}type") == "page":
                return True
    return False

def get_para_text(para):
    """استخراج نص الفقرة"""
    texts = [t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text]
    return normalize_text(''.join(texts))

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

def inject_hybrid(docx_path, output_path):
    """الحقن الهجين السريع"""
    start_time = time.time()
    register_namespaces()
    
    # 1. تحليل XML وجمع معلومات الفقرات
    print("Step 1: Analyzing XML structure...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    all_paras = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"  Total paragraphs: {len(all_paras)}")
    
    # تحديد الفقرات عند الفواصل
    break_indices = []  # قائمة بـ indices الفقرات التي فيها فواصل
    para_info = []  # معلومات كل فقرة
    
    for idx, para in enumerate(all_paras):
        text = get_para_text(para)
        has_break = has_page_break(para)
        para_info.append({
            'element': para,
            'text': text,
            'has_break': has_break,
            'verified_page': None  # سيُملأ من Word
        })
        if has_break:
            break_indices.append(idx)
    
    print(f"  Page breaks found: {len(break_indices)}")
    
    # 2. فتح Word والتأكد من أرقام الصفحات عند الفواصل فقط
    print("\nStep 2: Verifying page numbers with Word...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = True
    word.DisplayAlerts = 0
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        total_pages = doc.ComputeStatistics(2)
        print(f"  Total pages (Word): {total_pages}")
        
        # بناء قاموس سريع: نص -> أرقام صفحات من Word
        # نستعلم فقط عن الفقرات عند الفواصل + عينة
        
        word_paras = doc.Content.Paragraphs
        word_total = word_paras.Count
        print(f"  Total paragraphs (Word): {word_total}")
        
        # استعلام عن الفقرات عند الفواصل
        # نحتاج لتحديد أي فقرة Word تقابل كل فقرة XML عند الفواصل
        
        # بناء خريطة بالنص
        print("  Building text-to-page map for break paragraphs...")
        
        text_to_page = {}
        verified_count = 0
        
        # نستعلم عن الفقرات في Word التي نحتاجها فقط
        # لتسريع: نجمع نصوص الفقرات عند الفواصل ونبحث عنها
        break_texts = set()
        for idx in break_indices:
            text = para_info[idx]['text']
            if text:
                break_texts.add(text)
        
        # نضيف أيضاً أول فقرة وآخر فقرة
        if para_info:
            first_text = para_info[0]['text']
            last_text = para_info[-1]['text']
            if first_text:
                break_texts.add(first_text)
            if last_text:
                break_texts.add(last_text)
        
        print(f"  Unique break texts to verify: {len(break_texts)}")
        
        # البحث في Word (أسرع: نمر على الفقرات مرة واحدة)
        for i in range(1, min(word_total + 1, 5000)):  # حد 5000 للسرعة
            try:
                para = word_paras(i)
                text = normalize_text(para.Range.Text)
                
                if text in break_texts:
                    # الحصول على صفحة البداية
                    rng = para.Range.Duplicate
                    rng.Collapse(1)
                    page = rng.Information(3)
                    
                    if text not in text_to_page:
                        text_to_page[text] = []
                    text_to_page[text].append(page)
                    verified_count += 1
                    
                    if verified_count % 50 == 0:
                        print(f"    Verified {verified_count}...")
                        
            except:
                pass
        
        print(f"  Verified {verified_count} break paragraphs")
        
        # إغلاق Word
        doc.Close(False)
        word.Quit()
        
    except Exception as e:
        print(f"  Error: {e}")
        try:
            word.Quit()
        except:
            pass
        return False
    
    # 3. ملء أرقام الصفحات
    print("\nStep 3: Assigning page numbers...")
    
    current_page = 1
    
    for idx, info in enumerate(para_info):
        text = info['text']
        
        # هل لدينا تأكيد من Word؟
        if text and text in text_to_page and text_to_page[text]:
            verified_page = text_to_page[text].pop(0)
            current_page = verified_page
        
        info['verified_page'] = current_page
        
        # إذا كان هناك فاصل، نزيد الصفحة للفقرة التالية
        if info['has_break']:
            current_page += 1
    
    # التأكد من عدم تجاوز عدد الصفحات
    max_assigned = max(info['verified_page'] for info in para_info)
    print(f"  Max page assigned: {max_assigned}")
    
    if max_assigned > total_pages:
        print(f"  Capping to {total_pages}")
        for info in para_info:
            if info['verified_page'] > total_pages:
                info['verified_page'] = total_pages
    
    # 4. الحقن
    print("\nStep 4: Injecting markers...")
    
    for info in para_info:
        inject_into_para(info['element'], info['verified_page'])
    
    # 5. حفظ الملف
    print("\nStep 5: Saving...")
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
    
    print(f"\n{'='*50}")
    print(f"=== RESULT ===")
    print(f"Time: {elapsed:.1f} seconds")
    print(f"Markers: {len(markers)}")
    print(f"Page range: {min(pages)} to {max(pages)}")
    print(f"Word pages: {total_pages}")
    
    if max(pages) == total_pages:
        print("✓ PERFECT MATCH!")
    elif max(pages) >= total_pages - 1:
        print("✓ CLOSE MATCH (within 1 page)")
    else:
        print(f"⚠ Gap: {total_pages - max(pages)}")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_HYBRID.docx')
        inject_hybrid(input_path, output_path)
