"""
pageRender.py - الحل الهجين لترقيم الصفحات
===========================================
1. COM: فتح Word وعمل Repaginate() لتحديث lastRenderedPageBreak
2. حفظ الملف (لتحديث الـ breaks)
3. XML: قراءة document.xml وعد lastRenderedPageBreak + w:br type="page"
4. حقن {{PG:X}} بناءً على العدّ
"""

import sys
import os
import shutil
import tempfile
import re
import zipfile
import psutil
from lxml import etree as ET

# Force UTF-8 for stdout/stderr (Fix for Windows UnicodeEncodeError)
# Force UTF-8 for stdout/stderr (Fix for Windows UnicodeEncodeError)
# We use io.TextIOWrapper to override the default cp1252 on Windows consoles
import io
if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except Exception as e:
        pass

# Namespaces
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

def register_namespaces():
    for prefix, uri in NS.items():
        ET.register_namespace(prefix, uri)
    ET.register_namespace('w14', 'http://schemas.microsoft.com/office/word/2010/wordml')
    ET.register_namespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')

def kill_word_processes():
    for process in psutil.process_iter():
        try:
            if process.name().lower() == "winword.exe":
                process.kill()
        except:
            pass
    try:
        import subprocess
        subprocess.run(['taskkill', '/F', '/IM', 'WINWORD.EXE'], 
                       capture_output=True, timeout=5)
    except:
        pass

def repaginate_and_save(docx_path):
    """
    فتح Word وعمل Repaginate ثم حفظ لتحديث lastRenderedPageBreak
    """
    import win32com.client as win32
    
    word_app = win32.Dispatch('Word.Application')
    try:
        word_app.Visible = False
        word_app.DisplayAlerts = 0
    except:
        pass
    
    doc = None
    total_pages = 0
    
    try:
        print("STATUS:Opening Word for Repaginate...", flush=True)
        doc = word_app.Documents.Open(docx_path, ReadOnly=False, AddToRecentFiles=False)
        
        # تحديث التخطيط
        try:
            word_app.ActiveWindow.View.Type = 3  # wdPrintView
            doc.Repaginate()
        except Exception as e:
            print(f"WARNING: Repaginate failed: {e}", flush=True)
        
        # الحصول على عدد الصفحات
        total_pages = doc.ComputeStatistics(2)
        print(f"STATUS:Total Pages: {total_pages}", flush=True)

        # ---------------------------------------------------------
        # Active Tagging: حقن إشارات مرجعية في بداية كل صفحة
        # ---------------------------------------------------------
        try:
            print(f"STATUS:Injecting bookmarks for {total_pages} pages...", flush=True)
            # wdGoToPage = 1, wdGoToAbsolute = 1
            for p in range(1, total_pages + 1):
                word_app.Selection.GoTo(1, 1, p)
                # استخدام Selection.Range يضمن وضع الإشارة في مكان المؤشر الحالي
                doc.Bookmarks.Add(Name=f"ShamelaPage_{p}", Range=word_app.Selection.Range)
            print("STATUS:Bookmarks injection complete.", flush=True)
        except Exception as e:
             print(f"ERROR: Bookmark injection failed: {e}", flush=True)
        # ---------------------------------------------------------
        
        # حفظ لتحديث الملف بالـ Bookmarks
        doc.Save()
        print("STATUS:Document saved with updated page breaks.", flush=True)
        
        doc.Close(False)
        
    except Exception as e:
        print(f"ERROR: Word operation failed: {e}", flush=True)
        if doc:
            try:
                doc.Close(False)
            except:
                pass
    finally:
        if word_app:
            try:
                word_app.Quit()
            except:
                pass
    
    return total_pages

def create_hidden_run_element(text_content):
    """إنشاء run مخفي يحتوي على الـ marker"""
    run = ET.Element(f"{{{NS['w']}}}r")
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = text_content
    return run

def split_paragraph_at_break(para, break_elem):
    """
    تقسيم الفقرة عند lastRenderedPageBreak إلى فقرتين
    الـ lastRenderedPageBreak يأتي داخل <w:r> ويفصل بين <w:t> elements
    مثال:
    <w:r>
      <w:t>This is the end</w:t>
      <w:lastRenderedPageBreak/>
      <w:t> of the page</w:t>
    </w:r>
    تُرجع (para_before, para_after) أو None إذا فشل التقسيم
    """
    from copy import deepcopy
    
    # إيجاد الـ run الذي يحتوي على الفاصل
    break_run = break_elem.getparent()
    if break_run is None or break_run.tag != f"{{{NS['w']}}}r":
        return None
    
    # إيجاد موقع الـ run في الفقرة
    # نبحث فقط في الأبناء المباشرين للفقرة
    direct_children = list(para)
    break_run_index = None
    for i, child in enumerate(direct_children):
        if child.tag == f"{{{NS['w']}}}r":
            if child.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                break_run_index = i
                break
    
    if break_run_index is None:
        return None
    
    # إنشاء نسختين من الفقرة
    para_before = deepcopy(para)
    para_after = deepcopy(para)
    
    # الحصول على الأبناء المباشرين في كل نسخة
    children_before = list(para_before)
    children_after = list(para_after)
    
    # معالجة para_before:
    # - إزالة كل العناصر بعد الـ run الذي يحتوي على الفاصل
    # - في الـ run نفسه: إزالة كل ما بعد lastRenderedPageBreak
    for i in range(len(children_before) - 1, break_run_index, -1):
        para_before.remove(children_before[i])
    
    # معالجة الـ run المقسوم في para_before
    split_run_before = children_before[break_run_index]
    run_children = list(split_run_before)
    found_break = False
    for child in run_children:
        if child.tag == f"{{{NS['w']}}}lastRenderedPageBreak":
            found_break = True
            split_run_before.remove(child)
        elif found_break:
            split_run_before.remove(child)
    
    # معالجة para_after:
    # - إزالة كل العناصر قبل الـ run الذي يحتوي على الفاصل (ما عدا pPr)
    # - في الـ run نفسه: إزالة كل ما قبل وبما فيه lastRenderedPageBreak
    for i in range(break_run_index - 1, -1, -1):
        if children_after[i].tag != f"{{{NS['w']}}}pPr":
            para_after.remove(children_after[i])
    
    # معالجة الـ run المقسوم في para_after
    split_run_after = None
    for child in para_after:
        if child.tag == f"{{{NS['w']}}}r" and child.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
            split_run_after = child
            break
    
    if split_run_after is not None:
        run_children = list(split_run_after)
        found_break = False
        for child in run_children:
            if child.tag == f"{{{NS['w']}}}lastRenderedPageBreak":
                found_break = True
                split_run_after.remove(child)
            elif not found_break:
                # إزالة ما قبل الفاصل (ما عدا rPr)
                if child.tag != f"{{{NS['w']}}}rPr":
                    split_run_after.remove(child)
    
    # --- إصلاح الخصائص (Sanitize pPr) لمنع تغيير التنسيق وزيادة الصفحات ---
    # المشكلة: تقسيم الفقرة يكرر المسافات (Spacing) والبادئة (Indentation) مما يزيد الطول العمودي ويضرب الترقيم
    # الحل: فرض قيم صفرية بدلاً من الحذف (لأن الحذف يعيد القيم الافتراضية للنمط)

    # 1. معالجة الجزء الأول (P1): إزالة المسافة البعدية (Spacing After)
    pPr_before = para_before.find(f"{{{NS['w']}}}pPr")
    if pPr_before is not None:
        spacing = pPr_before.find(f"{{{NS['w']}}}spacing")
        if spacing is None:
            spacing = ET.SubElement(pPr_before, f"{{{NS['w']}}}spacing")
        
        # فرض مسافة بعدية 0
        spacing.attrib[f"{{{NS['w']}}}after"] = "0"
        # إزالة afterLines إذا وجدت لتجنب التعارض
        if f"{{{NS['w']}}}afterLines" in spacing.attrib:
            del spacing.attrib[f"{{{NS['w']}}}afterLines"]

    # 2. معالجة الجزء الثاني (P2): إزالة المسافة القبلية (Spacing Before) والبادئة (Indentation)
    pPr_after = para_after.find(f"{{{NS['w']}}}pPr")
    if pPr_after is not None:
        # إزالة البادئة (First Line Indent)
        ind = pPr_after.find(f"{{{NS['w']}}}ind")
        if ind is not None:
            # فرض بادئة 0 للسطر الأول
            ind.attrib[f"{{{NS['w']}}}firstLine"] = "0"
            if f"{{{NS['w']}}}firstLineChars" in ind.attrib:
                del ind.attrib[f"{{{NS['w']}}}firstLineChars"]
        
        # إزالة المسافة قبل (Spacing Before)
        spacing = pPr_after.find(f"{{{NS['w']}}}spacing")
        if spacing is None:
            spacing = ET.SubElement(pPr_after, f"{{{NS['w']}}}spacing")
        
        # فرض مسافة قبلية 0
        spacing.attrib[f"{{{NS['w']}}}before"] = "0"
        # إزالة beforeLines إذا وجدت
        if f"{{{NS['w']}}}beforeLines" in spacing.attrib:
            del spacing.attrib[f"{{{NS['w']}}}beforeLines"]
    
    return para_before, para_after


def process_xml_with_page_breaks(docx_path, output_path):
    """
    قراءة XML وحقن أرقام الصفحات بناءً على lastRenderedPageBreak و w:br type="page"
    """
    print("STATUS:Processing XML with page break detection...", flush=True)
    
    temp_dir = tempfile.gettempdir()
    extract_dir = os.path.join(temp_dir, "xml_extract")
    
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    
    try:
        # فك ضغط الملف
        with zipfile.ZipFile(docx_path, 'r') as z:
            z.extractall(extract_dir)
        
        doc_xml = os.path.join(extract_dir, 'word', 'document.xml')
        register_namespaces()
        tree = ET.parse(doc_xml)
        root = tree.getroot()
        body = root.find(f"{{{NS['w']}}}body")
        
        if body is None:
            raise Exception("No body found in document.xml")
        
        current_page = 1
        injected_count = 0
        para_index = 0
        
        # جمع كل الفقرات أولاً (لأننا سنضيف عناصر جديدة)
        all_paras = list(body.findall(f".//{{{NS['w']}}}p"))
        
        for para in all_paras:
            para_index += 1
            
            # 1. إزالة أي markers قديمة أولاً
            for run in para.findall(f".//{{{NS['w']}}}r"):
                t_elem = run.find(f"{{{NS['w']}}}t")
                if t_elem is not None and t_elem.text and "{{PG:" in t_elem.text:
                    t_elem.text = re.sub(r'\{\{PG:\d+\}\}', '', t_elem.text)
                    if not t_elem.text.strip():
                        parent = run.getparent()
                        if parent is not None:
                            parent.remove(run)
            
            # 2. البحث عن bookmarks المحقونة (ShamelaPage_X)
            bookmarks_in_para = []
            all_bookmarks = para.findall(f".//{{{NS['w']}}}bookmarkStart")
            for bm in all_bookmarks:
                name = bm.attrib.get(f"{{{NS['w']}}}name", "")
                if name.startswith("ShamelaPage_"):
                    bookmarks_in_para.append(bm)
            
            # 3. البحث عن w:br type="page" (فاصل صفحة صريح) - احتياط
            explicit_breaks = para.findall(f".//{{{NS['w']}}}br[@{{{NS['w']}}}type='page']")
            
            # DEBUG: أول 15 فقرة
            para_text = "".join([t.text for t in para.findall(f".//{{{NS['w']}}}t") if t.text])[:30]
            if para_index <= 15:
                # print(f"[P{para_index}] bookmarks={len(bookmarks_in_para)}, explicitBreaks={len(explicit_breaks)}, page={current_page}, text='{para_text}'", flush=True)
                pass
            
            # 4. معالجة الفقرة
            if len(bookmarks_in_para) > 0:
                # الفقرة تحتوي على bookmark لصفحة جديدة
                # نأخذ أول bookmark (عادة لا يوجد أكثر من واحد في الفقرة إلا نادراً)
                target_bookmark = bookmarks_in_para[0]
                bm_name = target_bookmark.attrib.get(f"{{{NS['w']}}}name", "")
                
                # استخراج رقم الصفحة
                try:
                    new_page_num = int(bm_name.split("_")[1])
                    current_page = new_page_num
                except:
                    pass

                # تقسيم الـ run عند Bookmark وحقن marker في المنتصف
                bm_run = target_bookmark.getparent()
                
                # حالة: Bookmark inside a Run (common) -> Split Run
                if bm_run is not None and bm_run.tag == f"{{{NS['w']}}}r":
                     # تقسيم الـ run: run_before + marker + run_after
                    from copy import deepcopy
                    
                    run_before = ET.Element(f"{{{NS['w']}}}r")
                    run_after = ET.Element(f"{{{NS['w']}}}r")
                    
                    found_bm = False
                    rPr = bm_run.find(f"{{{NS['w']}}}rPr")
                    
                    # نسخ rPr
                    if rPr is not None:
                        run_before.append(deepcopy(rPr))
                        run_after.append(deepcopy(rPr))
                    
                    for child in list(bm_run):
                        if child.tag == f"{{{NS['w']}}}rPr":
                            continue
                        elif child == target_bookmark:
                            found_bm = True
                            # Bookmark itself goes to run_before or explicitly removed? 
                            # We can leave it in run_before to persist valid doc structure
                            run_before.append(deepcopy(child)) 
                        elif not found_bm:
                            run_before.append(deepcopy(child))
                        else:
                            run_after.append(deepcopy(child))
                    
                    # إيجاد موقع bm_run في الفقرة
                    direct_children = list(para)
                    for i, child in enumerate(direct_children):
                        if child == bm_run:
                            para.remove(bm_run)
                            
                            # إدراج run_before
                            has_before_content = len([c for c in run_before if c.tag != f"{{{NS['w']}}}rPr"]) > 0
                            if has_before_content:
                                para.insert(i, run_before)
                                i += 1
                            
                            # إدراج marker للصفحة الجديدة
                            marker_after = create_hidden_run_element(f"{{{{PG:{current_page}}}}}")
                            para.insert(i, marker_after)
                            i += 1
                            injected_count += 1
                            
                            # إدراج run_after
                            has_after_content = len([c for c in run_after if c.tag != f"{{{NS['w']}}}rPr"]) > 0
                            if has_after_content:
                                para.insert(i, run_after)
                            
                            break
                # حالة: Bookmark direct child of Paragraph (less common but possible)
                else: 
                     # Bookmark is directly in P
                     # Just insert marker after it
                     direct_children = list(para)
                     for i, child in enumerate(direct_children):
                         if child == target_bookmark:
                             marker = create_hidden_run_element(f"{{{{PG:{current_page}}}}}")
                             para.insert(i + 1, marker)
                             injected_count += 1
                             break

            else:
                # لا يوجد bookmark - نحقن marker للصفحة الحالية (عادة للصفحة 1)
                # إذا كنا في الصفحة 1 ولم نحقن بعد
                if current_page == 1 and injected_count == 0:
                     marker_text = f"{{{{PG:{current_page}}}}}"
                     hidden_run = create_hidden_run_element(marker_text)
                     para.insert(0, hidden_run) # Insert at very start
                     injected_count += 1
                
                # إذا وجدنا explicit break، هل نزيد الصفحة؟
                # في نظام Active Tagging الجديد، Bookmarks هي الأساس.
                # explicit breaks قد تكون مكررة أو غير متزامنة.
                # الأفضل الاعتماد كلياً على Bookmarks.
                # لكن، إذا كان هناك صفحات فارغة؟
                # Bookmarks injected by GoTo Loop should cover all pages.
                pass
        
        print(f"STATUS:Injected {injected_count} markers. Last Page: {current_page}", flush=True)
        
        # كتابة XML
        tree.write(doc_xml, encoding='UTF-8', xml_declaration=True)
        
        # إعادة ضغط الملف
        if os.path.exists(output_path):
            os.remove(output_path)
        
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z:
            for folder, subs, files in os.walk(extract_dir):
                for f in files:
                    fp = os.path.join(folder, f)
                    an = os.path.relpath(fp, extract_dir)
                    z.write(fp, an)
        
        print("SUCCESS", flush=True)
        
    except Exception as e:
        print(f"ERROR: XML Processing failed: {e}", flush=True)
        import traceback
        traceback.print_exc()
    finally:
        if os.path.exists(extract_dir):
            shutil.rmtree(extract_dir)

def process_file(docx_path, output_path):
    """
    المعالجة الكاملة: COM + XML
    """
    print("START", flush=True)
    
    if not os.path.exists(docx_path):
        print(f"ERROR: File not found: {docx_path}")
        return

    # إغلاق Word إذا كان مفتوحاً (لتحرير الملفات العالقة)
    kill_word_processes()
    
    # نسخ الملف للعمل عليه
    # استخدام مجلد مؤقت محلي لتجنب مشاكل صلاحيات النظام أو المسارات الطويلة
    script_dir = os.path.dirname(os.path.abspath(__file__))
    temp_dir = os.path.join(script_dir, "temp_work")
    if not os.path.exists(temp_dir):
        os.makedirs(temp_dir)
        
    import uuid
    work_docx = os.path.join(temp_dir, f"work_{uuid.uuid4().hex}.docx")
    
    # تأكد من أن المسار مطلق
    work_docx = os.path.abspath(work_docx)
    print(f"DEBUG: Working file path: {work_docx}", flush=True)

    
    shutil.copy2(docx_path, work_docx)
    
    if not os.path.exists(work_docx):
         print(f"ERROR: Failed to create working file at {work_docx}")
         return
    total_pages = repaginate_and_save(work_docx)
    
    # إغلاق Word مرة أخرى
    kill_word_processes()
    
    # الخطوة 2: معالجة XML
    process_xml_with_page_breaks(work_docx, output_path)
    
    # تنظيف
    if os.path.exists(work_docx):
        try:
            os.remove(work_docx)
        except:
            pass

def process_word_only(docx_path, output_path):
    """
    المرحلة 1 فقط: Word Repaginate
    يخرج ملف مؤقت جاهز للـ XML processing
    """
    print("START:WORD_STAGE", flush=True)
    print(f"DEBUG: Input path: {docx_path}", flush=True)
    print(f"DEBUG: Output path: {output_path}", flush=True)
    
    if not os.path.exists(docx_path):
        print(f"ERROR: File not found: {docx_path}", flush=True)
        return
    
    kill_word_processes()
    
    # نسخ للعمل
    script_dir = os.path.dirname(os.path.abspath(__file__))
    temp_dir = os.path.join(script_dir, "temp_work")
    if not os.path.exists(temp_dir):
        os.makedirs(temp_dir)
    
    import uuid
    work_docx = os.path.join(temp_dir, f"work_{uuid.uuid4().hex}.docx")
    work_docx = os.path.abspath(work_docx)
    
    try:
        shutil.copy2(docx_path, work_docx)
    except Exception as e:
        print(f"ERROR: Failed to copy source file: {e}", flush=True)
        return
    
    if not os.path.exists(work_docx):
        print(f"ERROR: Failed to create working file at {work_docx}", flush=True)
        return
    
    try:
        total_pages = repaginate_and_save(work_docx)
        if total_pages == 0:
            print("WARNING: repaginate_and_save returned 0 pages - Word may have failed", flush=True)
    except Exception as e:
        print(f"ERROR: repaginate_and_save failed: {e}", flush=True)
        import traceback
        traceback.print_exc()
        # تنظيف الملف المؤقت
        if os.path.exists(work_docx):
            try:
                os.remove(work_docx)
            except:
                pass
        return
    
    kill_word_processes()
    
    # التحقق من أن الملف المعالج موجود قبل نسخه
    if not os.path.exists(work_docx):
        print(f"ERROR: Working file disappeared after Word processing: {work_docx}", flush=True)
        return
    
    # نسخ الملف المعالج للـ output
    try:
        shutil.copy2(work_docx, output_path)
        print(f"DEBUG: Copied to output: {output_path}", flush=True)
    except Exception as e:
        print(f"ERROR: Failed to copy to output: {e}", flush=True)
        return
    
    # التحقق من أن الملف الناتج تم إنشاؤه
    if not os.path.exists(output_path):
        print(f"ERROR: Output file was not created: {output_path}", flush=True)
        return
    
    # تنظيف
    if os.path.exists(work_docx):
        try:
            os.remove(work_docx)
        except:
            pass
    
    print(f"WORD_DONE:{output_path}", flush=True)

def process_xml_only(input_path, output_path):
    """
    المرحلة 2 فقط: XML Processing
    يأخذ ملف تم عمل Repaginate له مسبقاً
    """
    print("START:XML_STAGE", flush=True)
    
    if not os.path.exists(input_path):
        print(f"ERROR: File not found: {input_path}")
        return
    
    process_xml_with_page_breaks(input_path, output_path)
    
    # لا نحذف input_path لأنه قد يكون ملف المستخدم الأصلي
    print("XML_DONE", flush=True)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Page Render Script')
    parser.add_argument('books_folder', help='Books output folder')
    parser.add_argument('docx_path', help='Input docx file path')
    parser.add_argument('--stage', choices=['word', 'xml', 'full'], default='full',
                        help='Processing stage: word (repaginate only), xml (parse only), full (both)')
    
    args = parser.parse_args()
    
    # Ensure output folder exists
    if not os.path.exists(args.books_folder):
        try:
            os.makedirs(args.books_folder, exist_ok=True)
            print(f"STATUS: Created output directory: {args.books_folder}", flush=True)
        except Exception as e:
            print(f"WARNING: Failed to create output directory {args.books_folder}: {e}", flush=True)

    file_name = os.path.splitext(os.path.basename(args.docx_path))[0]
    
    # Fix: If stage is XML, we are receiving a temp file (e.g., _temp_Book), 
    # but we want the output to be the original name (Book).
    if args.stage == 'xml' and file_name.startswith('_temp_'):
        file_name = file_name[6:] # len('_temp_') == 6

    output_file = os.path.join(args.books_folder, f"{file_name}.docx")
    
    if args.stage == 'word':
        # مرحلة Word فقط - الخرج ملف مؤقت
        temp_output = os.path.join(args.books_folder, f"_temp_{file_name}.docx")
        process_word_only(args.docx_path, temp_output)
    elif args.stage == 'xml':
        # مرحلة XML فقط - المدخل ملف مؤقت من مرحلة Word
        process_xml_only(args.docx_path, output_file)
    else:
        # المعالجة الكاملة (الوضع القديم)
        process_file(args.docx_path, output_file)

