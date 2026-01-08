import sys
import os
import shutil
import tempfile
import stat
import zipfile
from lxml import etree as ET  # استخدام lxml بدلاً من ElementTree للحفاظ على namespaces
import win32com.client as win32
import psutil
# Namespaces for OpenXML
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

def register_namespaces():
    """تسجيل جميع namespaces المطلوبة لـ Word XML"""
    for prefix, uri in NS.items():
        ET.register_namespace(prefix, uri)
    # إضافة namespaces أخرى ضرورية
    ET.register_namespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')
    ET.register_namespace('w14', 'http://schemas.microsoft.com/office/word/2010/wordml')
    ET.register_namespace('w15', 'http://schemas.microsoft.com/office/word/2012/wordml')
    ET.register_namespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
    ET.register_namespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    ET.register_namespace('pic', 'http://schemas.openxmlformats.org/drawingml/2006/picture')
    ET.register_namespace('wps', 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape')
    ET.register_namespace('wpg', 'http://schemas.microsoft.com/office/word/2010/wordprocessingGroup')
    ET.register_namespace('wpc', 'http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas')


# ================== VBA MACRO للحصول السريع على أرقام الصفحات ==================
VBA_CODE = '''
Public Function GetAllPageNumbers() As String
    On Error Resume Next
    Application.ScreenUpdating = False
    
    Dim result As String
    Dim para As Paragraph
    Dim rng As Range
    
    result = ""
    For Each para In ActiveDocument.Content.Paragraphs
        Set rng = para.Range.Duplicate
        rng.Collapse wdCollapseStart
        result = result & rng.Information(wdActiveEndPageNumber) & ","
    Next
    
    Application.ScreenUpdating = True
    GetAllPageNumbers = result
End Function
'''

def get_page_numbers_via_vba(doc, word_app):
    """
    الحصول على أرقام الصفحات لكل الفقرات باستخدام VBA macro.
    هذا أسرع بكثير من استدعاء COM لكل فقرة.
    يرجع قائمة بأرقام الصفحات أو None إذا فشل.
    """
    try:
        # حذف module قديم إن وجد
        try:
            for mod in doc.VBProject.VBComponents:
                if mod.Name == "PageHelper":
                    doc.VBProject.VBComponents.Remove(mod)
                    break
        except:
            pass
        
        # إنشاء module جديد
        vb_module = doc.VBProject.VBComponents.Add(1)  # vbext_ct_StdModule
        vb_module.Name = "PageHelper"
        vb_module.CodeModule.AddFromString(VBA_CODE)
        
        # تشغيل الماكرو
        result = word_app.Application.Run("GetAllPageNumbers")
        
        # حذف الـ module
        try:
            for mod in doc.VBProject.VBComponents:
                if mod.Name == "PageHelper":
                    doc.VBProject.VBComponents.Remove(mod)
                    break
        except:
            pass
        
        # تحليل النتيجة
        if result:
            parts = result.strip(',').split(',')
            page_numbers = [int(p) for p in parts if p.strip().isdigit()]
            return page_numbers
        
        return None
        
    except Exception as e:
        print(f"WARNING: VBA failed: {e}", flush=True)
        print("TIP: Enable 'Trust access to VBA project' in Word Trust Center", flush=True)
        return None



def kill_word_processes():
    """إغلاق نسخ الوورد المفتوحة"""
    # طريقة 1: psutil
    for process in psutil.process_iter():
        try:
            if process.name().lower() == "winword.exe":
                process.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    # طريقة 2: taskkill (أقوى)
    try:
        import subprocess
        subprocess.run(['taskkill', '/F', '/IM', 'WINWORD.EXE'], 
                       capture_output=True, timeout=5)
    except:
        pass


def validate_input():
    """التحقق من المدخلات"""
    if len(sys.argv) < 3:
        print("ERROR: يرجى توفير مسار ملف الوورد كوسيط.")
        sys.exit(1)

    books_folder = sys.argv[1]
    word_file_path = sys.argv[2]

    if not os.path.exists(word_file_path):
        print(f"ERROR: الملف غير موجود: {word_file_path}")
        sys.exit(1)

    file_name = os.path.splitext(os.path.basename(word_file_path))[0]
    output_file_path = os.path.join(books_folder, f"{file_name}.docx")
    
    return word_file_path, output_file_path

def create_temp_copy(word_file_path):
    """إنشاء نسخة مؤقتة للعمل عليها"""
    temp_dir = tempfile.gettempdir()
    file_name = os.path.basename(word_file_path)
    temp_path = os.path.join(temp_dir, f"pageRender_{file_name}")
    
    if os.path.exists(temp_path):
        os.remove(temp_path)
    
    shutil.copy2(word_file_path, temp_path)
    os.chmod(temp_path, stat.S_IWRITE | stat.S_IREAD)
    
    return temp_path

def open_word_document(word_file_path):
    """فتح الملف في Word"""
    import time
    import threading
    
    # التحقق من حجم الملف
    file_size_mb = os.path.getsize(word_file_path) / (1024 * 1024)
    print(f"STATUS:حجم الملف: {file_size_mb:.1f} MB", flush=True)
    
    # للملفات الكبيرة جداً (>40MB)، نفتحها Visible لأنها أحياناً أسرع
    use_visible = file_size_mb > 40
    
    if use_visible:
        print(f"STATUS:ملف كبير - سيتم فتح Word مرئياً للأداء الأفضل", flush=True)
        print(f"STATUS:قد يستغرق الفتح عدة دقائق، من فضلك لا تتفاعل مع Word", flush=True)
    
    word_app = win32.Dispatch('Word.Application')
    try:
        word_app.Visible = use_visible  # مرئي للملفات الكبيرة
        # لا نقوم بـ minimize - نتركه مرئي بالكامل لرؤية المشاكل
        word_app.DisplayAlerts = 0  # wdAlertsNone - تعطيل جميع التنبيهات
    except:
        pass
    
    doc = None
    try:
        print(f"STATUS:فتح المستند...", flush=True)
        
        # إنشاء thread للطباعة الدورية
        stop_printing = threading.Event()
        def print_waiting():
            counter = 0
            while not stop_printing.is_set():
                time.sleep(15)  # كل 15 ثانية
                if not stop_printing.is_set():
                    counter += 15
                    print(f"STATUS:لا يزال يفتح... ({counter}s)", flush=True)
        
        printer_thread = threading.Thread(target=print_waiting, daemon=True)
        printer_thread.start()
        
        try:
            # محاولة فتح الملف
            doc = word_app.Documents.Open(
                word_file_path, 
                ReadOnly=False,
                ConfirmConversions=False,
                AddToRecentFiles=False
            )
            stop_printing.set()
            print(f"STATUS:تم فتح المستند بنجاح!", flush=True)
        finally:
            stop_printing.set()
            
    except Exception as e:
        print(f"ERROR:فشل فتح المستند: {e}", flush=True)
        try:
            word_app.Quit()
        except:
            pass
        raise Exception(f"فشل فتح الملف: {e}")
    
    # إيقاف تضمين الخطوط المقيدة
    try:
        doc.EmbedTrueTypeFonts = False
        if doc.Final:
            doc.Final = False
    except:
        pass
    
    return word_app, doc

def force_pagination(word_app, doc):
    """إجبار Word على حساب التخطيط وإدراج w:lastRenderedPageBreak"""
    import time
    
    # 1. تعيين وضع العرض إلى Print Layout
    try:
        word_app.ActiveWindow.View.Type = 3  # wdPrintView
    except Exception as e:
        pass
    
    # 2. للملفات الكبيرة، Repaginate أفضل من cursor movement
    # لأنه يجبر Word على إعادة حساب كل الصفحات بدقة
    print("STATUS:إعادة حساب التخطيط (Repaginate)...", flush=True)
    try:
        doc.Repaginate()
        print("STATUS:تم Repaginate بنجاح", flush=True)
        time.sleep(2)  # انتظار لضمان الانتهاء
    except Exception as e:
        print(f"WARNING: Repaginate failed: {e}", flush=True)
        # fallback: cursor movement
        try:
            print("STATUS:محاولة cursor movement كبديل...", flush=True)
            selection = word_app.Selection
            selection.EndKey(Unit=6)
            time.sleep(1)
            selection.HomeKey(Unit=6)
        except:
            pass
    
    # 3. الحصول على عدد الصفحات حسب حسابات Word
    total_pages_word = None
    max_retries = 5
    
    for attempt in range(max_retries):
        try:
            print(f"STATUS:محاولة {attempt + 1}/{max_retries} للحصول على عدد الصفحات...", flush=True)
            total_pages_word = doc.ComputeStatistics(2)  # wdStatisticPages
            print(f"STATUS_INITIAL_PAGES:{total_pages_word}", flush=True)
            break
        except Exception as e:
            print(f"WARNING: محاولة {attempt + 1} فشلت: {e}", flush=True)
            if attempt < max_retries - 1:
                wait_time = 3 + (attempt * 2)
                print(f"STATUS:انتظار {wait_time} ثانية قبل إعادة المحاولة...", flush=True)
                time.sleep(wait_time)
                try:
                    word_app.ScreenRefresh()
                except:
                    pass
            else:
                print(f"ERROR: فشل الحصول على عدد الصفحات بعد {max_retries} محاولات", flush=True)
    
    # 4. حفظ التغييرات لضمان كتابة علامات lastRenderedPageBreak في ملف XML
    # هذا الحفظ يحدث قبل إضافة VBA module، لذا الملف نظيف
    print("STATUS:جاري حفظ المستند...", flush=True)
    try:
        doc.Save()
        print("STATUS:تم حفظ المستند بنجاح", flush=True)
    except Exception as e:
        print(f"WARNING: Save failed: {e}", flush=True)
    
    return total_pages_word

def create_hidden_run_element(text_content):
    """إنشاء عنصر Run مخفي يحتوي على رقم الصفحة"""
    # <w:r>
    run = ET.Element(f"{{{NS['w']}}}r")
    
    # <w:rPr>
    rPr = ET.SubElement(run, f"{{{NS['w']}}}rPr")
    # <w:vanish/> (Hidden text)
    ET.SubElement(rPr, f"{{{NS['w']}}}vanish")
    
    # <w:t>{PG:X}</w:t>
    t = ET.SubElement(run, f"{{{NS['w']}}}t")
    t.text = text_content
    
    return run

def process_with_native_xml(docx_path, total_pages_word=None, vba_page_numbers=None):
    """
    معالجة XML وحقن أرقام الصفحات.
    
    إذا توفرت vba_page_numbers (من VBA macro)، نستخدمها مباشرة.
    وإلا نستخدم المنطق القديم (عد الفواصل).
    
    هذا يضمن:
    1. كل فقرة تحصل على رقم صفحتها الصحيح من Word
    2. خطأ في فقرة لا يؤثر على الفقرات التالية
    3. دعم الفقرات الممتدة بين صفحتين
    """
    print("STATUS:جاري المعالجة باستخدام Native XML...", flush=True)
    
    # تسجيل الـ Namespaces لضمان قراءة/كتابة صحيحة
    register_namespaces()

    
    temp_dir = os.path.dirname(docx_path)
    extract_dir = os.path.join(temp_dir, "docx_extract")
    
    # حذف مجلد الاستخراج القديم مع إعادة المحاولة
    if os.path.exists(extract_dir):
        import time as time_module
        for attempt in range(3):
            try:
                shutil.rmtree(extract_dir)
                break
            except Exception as e:
                if attempt < 2:
                    time_module.sleep(1)
                else:
                    print(f"WARNING: Could not delete old extract dir: {e}", flush=True)
    
    os.makedirs(extract_dir, exist_ok=True)


    # 1. فك الضغط extraction
    try:
        with zipfile.ZipFile(docx_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
    except Exception as e:
        print(f"ERROR: فشل فك ضغط الملف: {e}", flush=True)
        raise e

    # 2. قراءة document.xml
    doc_xml_path = os.path.join(extract_dir, 'word', 'document.xml')
    if not os.path.exists(doc_xml_path):
        print("ERROR: document.xml غير موجود داخل الـ docx", flush=True)
        return

    tree = ET.parse(doc_xml_path)
    root = tree.getroot()
    body = root.find(f"{{{NS['w']}}}body")

    if body is None:
        print("ERROR: لا يوجد body في ملف الـ XML", flush=True)
        return

    injected_count = 0
    total_elements = len(list(body))
    processed_elements = 0

    # 3. جمع كل الفقرات باستخدام iter() للوصول لكل الفقرات بما فيها المتداخلة
    all_paragraphs = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"STATUS:إجمالي الفقرات للمعالجة: {len(all_paragraphs)}", flush=True)

    # ================== منطق VBA (الطريقة الجديدة) ==================
    if vba_page_numbers is not None and len(vba_page_numbers) > 0:
        print(f"STATUS:استخدام أرقام VBA ({len(vba_page_numbers)} رقم)...", flush=True)
        
        # قراءة XML مباشرة من الـ zip (مثل inject_vba.py)
        with zipfile.ZipFile(docx_path, 'r') as z:
            content = z.read('word/document.xml')
        
        root = ET.fromstring(content)
        body = root.find(f"{{{NS['w']}}}body")
        
        if body is None:
            print("ERROR: لا يوجد body في ملف الـ XML", flush=True)
            return
        
        all_paragraphs = list(body.iter(f"{{{NS['w']}}}p"))
        print(f"STATUS:إجمالي الفقرات للمعالجة: {len(all_paragraphs)}", flush=True)
        
        injected_count = 0
        for i, para in enumerate(all_paragraphs):
            # تحديد رقم الصفحة
            if i < len(vba_page_numbers):
                page_num = vba_page_numbers[i]
            else:
                page_num = vba_page_numbers[-1] if vba_page_numbers else 1
            
            # حقن hidden run
            hidden_run = create_hidden_run_element(f"{{{{PG:{page_num}}}}}")
            
            pPr = para.find(f"{{{NS['w']}}}pPr")
            insert_index = 0
            if pPr is not None:
                for idx, child in enumerate(para):
                    if child == pPr:
                        insert_index = idx + 1
                        break
            
            para.insert(insert_index, hidden_run)
            injected_count += 1
            
            if injected_count % 500 == 0:
                print(f"STATUS:التقدم {(injected_count * 100) // len(all_paragraphs)}%", flush=True)
        
        # حساب أقصى صفحة محقونة
        max_injected_page = max(vba_page_numbers) if vba_page_numbers else 0
        
        print(f"STATUS:تم حقن {injected_count} فقرة بطريقة VBA", flush=True)
        print(f"STATUS:=== مقارنة الصفحات ===", flush=True)
        print(f"STATUS:صفحات Word الأصلية: {total_pages_word}", flush=True)
        print(f"STATUS:أقصى صفحة VBA: {max_injected_page}", flush=True)
        print(f"STATUS:فقرات XML: {len(all_paragraphs)}", flush=True)
        print(f"STATUS:فقرات VBA: {len(vba_page_numbers)}", flush=True)
        
        if total_pages_word and max_injected_page:
            if max_injected_page == total_pages_word:
                print(f"STATUS:✓ تطابق تام!", flush=True)
            else:
                diff = abs(total_pages_word - max_injected_page)
                error_pct = (diff / total_pages_word) * 100
                print(f"STATUS:الفرق: {diff} صفحات ({error_pct:.1f}%)", flush=True)

        
        # حفظ مباشرة في zip (بدون ملفات مؤقتة)
        try:
            new_zip_path = docx_path + "_new"
            with zipfile.ZipFile(new_zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_out:
                with zipfile.ZipFile(docx_path, 'r') as zip_in:
                    for item in zip_in.infolist():
                        if item.filename == 'word/document.xml':
                            # كتابة XML المعدل باستخدام lxml
                            xml_bytes = ET.tostring(root, encoding='UTF-8', xml_declaration=True)
                            zip_out.writestr(item.filename, xml_bytes)
                        else:
                            # نسخ الملفات الأخرى كما هي
                            zip_out.writestr(item, zip_in.read(item.filename))
            
            if os.path.exists(docx_path):
                os.remove(docx_path)
            shutil.move(new_zip_path, docx_path)
            
            # تنظيف مجلد الاستخراج إن وجد
            if os.path.exists(extract_dir):
                try:
                    shutil.rmtree(extract_dir)
                except:
                    pass
            
        except Exception as e:

            print(f"ERROR: فشل في إعادة بناء ملف الـ docx: {e}", flush=True)
            raise e
        
        return  # انتهى بنجاح مع VBA
    
    # ================== المنطق القديم (fallback) ==================
    print("STATUS:استخدام طريقة عد الفواصل (fallback)...", flush=True)
    
    current_page = 1
    xml_page_count = 1
    prev_para_ended_with_manual = False
    
    for element in body:
        processed_elements += 1
        tag_name = element.tag
        
        # البحث عن جميع الفقرات
        for para in [element] if element.tag == f"{{{NS['w']}}}p" else element.findall(f".//{{{NS['w']}}}p"):
            breaks_sequence = []
            
            for run_idx, run in enumerate(para.findall(f".//{{{NS['w']}}}r")):
                has_manual = False
                has_lastRendered = False
                
                for br in run.findall(f".//{{{NS['w']}}}br"):
                    if br.get(f"{{{NS['w']}}}type") == "page":
                        has_manual = True
                        break
                
                if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                    has_lastRendered = True
                
                if has_manual:
                    breaks_sequence.append(('manual', run_idx))
                if has_lastRendered:
                    breaks_sequence.append(('lastRendered', run_idx))
            
            # عد بذكاء
            i = 0
            while i < len(breaks_sequence):
                xml_page_count += 1
                if (i + 1 < len(breaks_sequence) and 
                    breaks_sequence[i][0] == 'manual' and 
                    breaks_sequence[i + 1][0] == 'lastRendered' and
                    breaks_sequence[i + 1][1] - breaks_sequence[i][1] <= 1):
                    i += 2
                else:
                    i += 1
    
    # مقارنة مع Word count
    if total_pages_word:
        diff = abs(total_pages_word - xml_page_count)
        if diff > 1:
            print(f"WARNING:فرق بين Word ({total_pages_word}) و XML ({xml_page_count}): {diff} صفحات", flush=True)
            print(f"WARNING:قد يكون الملف يحتاج إعادة فتح/حفظ في Word", flush=True)
        else:
            print(f"STATUS:Word و XML متطابقان ({total_pages_word} صفحات)", flush=True)
    
    current_page = 1
    prev_para_ended_with_manual = False
    
    for element in body:
        processed_elements += 1
        tag_name = element.tag
        
        # طباعة التقدم كل 100 عنصر
        if processed_elements % 100 == 0:
            progress = (processed_elements * 100) // total_elements
            print(f"STATUS:التقدم {progress}% ({processed_elements}/{total_elements}) - الصفحة الحالية: {current_page}", flush=True)
        
        # معالجة الفقرات <w:p>
        if tag_name == f"{{{NS['w']}}}p":
            para = element
            
            # 1. حقن hidden run يحتوي على {PG:X}
            hidden_run = create_hidden_run_element(f"{{{{PG:{current_page}}}}}")
            
            # إدراج بعد properties مباشرة إن وجدت، أو في البداية
            pPr = para.find(f"{{{NS['w']}}}pPr")
            insert_index = 0
            if pPr is not None:
                # البحث عن اندكس pPr للإدراج بعده
                for idx, child in enumerate(para):
                    if child == pPr:
                        insert_index = idx + 1
                        break
            
            para.insert(insert_index, hidden_run)
            injected_count += 1
            
            # 2. البحث عن فواصل الصفحات داخل الفقرة
            # تحديث: يشمل البحث داخل الصور (drawings)
            
            breaks_sequence = []  # قائمة بترتيب: ('type', run_index)
            has_text_content = False # هل الفقرة تحتوي على نص حقيقي؟
            
            for run_idx, run in enumerate(para.findall(f".//{{{NS['w']}}}r")):
                # التحقق من وجود نص
                if run.find(f".//{{{NS['w']}}}t") is not None:
                     text_val = run.find(f".//{{{NS['w']}}}t").text
                     if text_val and text_val.strip(): # نص حقيقي ليس مسافات فقط
                         has_text_content = True
                
                has_manual = False
                has_lastRendered = False
                
                # فحص عادي
                for br in run.findall(f".//{{{NS['w']}}}br"):
                    if br.get(f"{{{NS['w']}}}type") == "page":
                        has_manual = True
                        break
                
                if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                    has_lastRendered = True
                
                # فحص داخل الصور (drawings)
                # أحياناً يكون الفاصل داخل textbox داخل drawing
                for drawing in run.findall(f".//{{{NS['w']}}}drawing"):
                    if drawing.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                        has_lastRendered = True
                    # نادراً ما يكون manual داخل drawing لكن للاحتياط
                    for d_br in drawing.findall(f".//{{{NS['w']}}}br"):
                         if d_br.get(f"{{{NS['w']}}}type") == "page":
                             has_manual = True

                if has_manual:
                    breaks_sequence.append(('manual', run_idx))
                if has_lastRendered:
                    breaks_sequence.append(('lastRendered', run_idx))
            
            # معالجة الفواصل
            current_i = 0
            paragraph_has_manual = False
            
            while current_i < len(breaks_sequence):
                b_type, b_idx = breaks_sequence[current_i]
                
                if b_type == 'manual':
                    paragraph_has_manual = True
                    current_page += 1
                    # Intra-paragraph deduplication
                    if (current_i + 1 < len(breaks_sequence) and 
                        breaks_sequence[current_i + 1][0] == 'lastRendered' and
                        breaks_sequence[current_i + 1][1] - breaks_sequence[current_i][1] <= 1):
                        current_i += 2
                    else:
                        current_i += 1
                        
                elif b_type == 'lastRendered':
                    # Inter-paragraph Smart Deduplication
                    # نتجاهل lastRendered فقط إذا:
                    # 1. الفقرة السابقة انتهت بفاصل يدوي
                    # 2. الفقرة الحالية *لا* تحتوي على نص حقيقي (مجرد وعاء للفاصل)
                    # 3. الفاصل هو أول شيء في الفقرة
                    if (prev_para_ended_with_manual and 
                        not has_text_content and 
                        current_i == 0 and b_idx <= 1):
                        
                        print(f"STATUS:Smart Deduplication: Ignored redundant lastRendered at page {current_page} (empty para after manual)", flush=True)
                        current_i += 1
                    else:
                        current_page += 1
                        current_i += 1
            
            # تحديث الحالة للفقرة القادمة
            prev_para_ended_with_manual = False
            if breaks_sequence:
                 if breaks_sequence[-1][0] == 'manual':
                     prev_para_ended_with_manual = True
            
            # ملاحظة: إذا كانت الفقرة فارغة تماماً (لا فواصل)، نحتفظ بالحالة السابقة؟
            # لا، لأن السطر الفارغ يعتبر محتوى يفصل بين الفاصلين
            if not breaks_sequence and has_text_content:
                prev_para_ended_with_manual = False

        # معالجة الجداول <w:tbl>
        elif tag_name == f"{{{NS['w']}}}tbl":
            prev_para_ended_with_manual = False
            # البحث عن page breaks في الجدول
            for tbl_para in element.findall(f".//{{{NS['w']}}}p"):
                breaks_sequence = []
                for run_idx, run in enumerate(tbl_para.findall(f".//{{{NS['w']}}}r")):
                    has_manual = False
                    has_lastRendered = False
                    
                    for br in run.findall(f".//{{{NS['w']}}}br"):
                        if br.get(f"{{{NS['w']}}}type") == "page":
                            has_manual = True
                            break
                    if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                        has_lastRendered = True
                    
                    if has_manual:
                        breaks_sequence.append(('manual', run_idx))
                    if has_lastRendered:
                         breaks_sequence.append(('lastRendered', run_idx))
                
                i = 0
                while i < len(breaks_sequence):
                    current_page += 1
                    if (i + 1 < len(breaks_sequence) and 
                        breaks_sequence[i][0] == 'manual' and 
                        breaks_sequence[i + 1][0] == 'lastRendered' and
                        breaks_sequence[i + 1][1] - breaks_sequence[i][1] <= 1):
                        i += 2
                    else:
                        i += 1

    # استخدام عدد الصفحات من Word كمرجع نهائي
    if total_pages_word is not None:
        final_page_count = total_pages_word
    else:
        # Fallback: استخدام الحساب من XML فقط إذا فشل Word
        final_page_count = current_page

    print(f"STATUS:تم حقن {injected_count} علامة صفحة. عدد الصفحات الكلي: {final_page_count}", flush=True)

    # 4. حفظ XML المعدل
    tree.write(doc_xml_path, encoding='UTF-8', xml_declaration=True)

    # 5. إعادة الضغط Re-zip
    # نقوم بإنشاء ملف zip جديد من المجلد المستخرج واستبدال الملف الأصلي
    try:
        new_zip_path = docx_path + "_new"
        with zipfile.ZipFile(new_zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_out:
            for foldername, subfolders, filenames in os.walk(extract_dir):
                for filename in filenames:
                    file_path = os.path.join(foldername, filename)
                    # نحسب المسار النسبي داخل الـ zip
                    arcname = os.path.relpath(file_path, extract_dir)
                    zip_out.write(file_path, arcname)
        
        # استبدال القديم بالجديد
        if os.path.exists(docx_path):
            os.remove(docx_path)
        shutil.move(new_zip_path, docx_path)
        
        # تنظيف
        shutil.rmtree(extract_dir)
        
    except Exception as e:
        print(f"ERROR: فشل في إعادة بناء ملف الـ docx: {e}", flush=True)
        raise e

def main():
    print("START", flush=True)
    
    # 1. تنظيف العمليات السابقة
    kill_word_processes()
    
    # 2. التحقق من المدخلات
    word_file_path, output_file_path = validate_input()
    
    # 3. إنشاء نسخة مؤقتة
    print("STATUS:جاري إنشاء نسخة مؤقتة...", flush=True)
    temp_file_path = create_temp_copy(word_file_path)
    
    try:
        # 4. استخدام Word (COM) لإجبار الترقيم وتوليد lastRenderedPageBreak
        # نحاول دائماً استخدام Word للحصول على العدد الدقيق
        file_size_mb = os.path.getsize(temp_file_path) / (1024 * 1024)
        print(f"STATUS:حجم الملف: {file_size_mb:.1f} MB", flush=True)
        
        if file_size_mb > 40:
            print(f"STATUS:ملف كبير - قد يستغرق Word عدة دقائق...", flush=True)
        
        print("STATUS:جاري تشغيل Word لحساب التخطيط...", flush=True)
        
        total_pages_word = None
        vba_page_numbers = None
        
        try:
            word_app, doc = open_word_document(temp_file_path)
            
            try:
                total_pages_word = force_pagination(word_app, doc)
                
                # =============== استخدام VBA للحصول على أرقام الصفحات ===============
                print("STATUS:جاري الحصول على أرقام الصفحات عبر VBA...", flush=True)
                vba_page_numbers = get_page_numbers_via_vba(doc, word_app)
                
                if vba_page_numbers:
                    print(f"STATUS:تم الحصول على {len(vba_page_numbers)} رقم صفحة", flush=True)
                else:
                    print("WARNING:فشل VBA، سيتم استخدام الطريقة القديمة", flush=True)
                
                # إغلاق Word بعد الحصول على النتيجة
                try:
                    doc.Close(False)  # لا نحفظ التغييرات
                    word_app.Quit()
                except:
                    pass

                    
            except Exception as e:
                print(f"WARNING: خطأ في force_pagination: {e}", flush=True)
                try:
                    doc.Close(False)
                    word_app.Quit()
                except:
                    pass
                total_pages_word = None
        
        except Exception as e:
            print(f"WARNING: فشل Word COM: {e}", flush=True)
            total_pages_word = None
            vba_page_numbers = None
            try:
                kill_word_processes()
            except:
                pass
        
        # إذا فشل Word، نستخدم XML fallback
        if total_pages_word is None:
            print("WARNING: سيتم استخدام حساب XML كبديل", flush=True)
        
        # تنظيف Word قبل معالجة XML
        try:
            kill_word_processes()
        except:
            pass
        
        import time as time_mod
        time_mod.sleep(1)  # انتظار لتحرير الملفات
        
        # 5. المعالجة بـ Native XML (مع أرقام VBA إن توفرت)
        process_with_native_xml(temp_file_path, total_pages_word, vba_page_numbers)


        
        # 6. نقل الملف الناتج
        print("STATUS:جاري حفظ الملف النهائي...", flush=True)
        if os.path.exists(output_file_path):
            os.remove(output_file_path)
        
        shutil.move(temp_file_path, output_file_path)
        print("SUCCESS", flush=True)

    except Exception as e:
        print(f"ERROR:Final Exception: {e}", flush=True)
        # محاولة تنظيف
        try:
            kill_word_processes()
        except:
            pass
        if os.path.exists(temp_file_path):
            try:
                os.remove(temp_file_path)
            except:
                pass
        sys.exit(1)

if __name__ == "__main__":
    main()
