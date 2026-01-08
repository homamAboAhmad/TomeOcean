"""
الحقن فائق السرعة - باستخدام VBA Macro
يجمع أرقام الصفحات داخل Word مباشرة (سريع جداً)
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

VBA_CODE = '''
Public Function GetAllPageNumbers() As String
    On Error Resume Next
    Application.ScreenUpdating = False
    
    Dim result As String
    Dim para As Paragraph
    Dim total As Long
    Dim i As Long
    
    total = ActiveDocument.Content.Paragraphs.Count
    result = ""
    i = 0
    
    For Each para In ActiveDocument.Content.Paragraphs
        result = result & para.Range.Information(wdActiveEndPageNumber) & ","
        i = i + 1
    Next
    
    Application.ScreenUpdating = True
    GetAllPageNumbers = result
End Function
'''

def get_page_numbers_via_vba(docx_path):
    """الحصول على أرقام الصفحات باستخدام VBA (سريع جداً)"""
    print("Opening Word and running VBA macro...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False  # إخفاء Word
    word.DisplayAlerts = 0  # wdAlertsNone
    word.ScreenUpdating = False  # تسريع
    
    page_numbers = []
    total_pages = 0
    
    try:
        # فتح الملف بدون تحديثات
        doc = word.Documents.Open(
            os.path.abspath(docx_path),
            ReadOnly=True,
            AddToRecentFiles=False,
            Visible=False
        )
        
        print("  Document opened, repaginating...")
        doc.Repaginate()
        
        total_pages = doc.ComputeStatistics(2)  # wdStatisticPages
        print(f"  Total pages: {total_pages}")

        
        # إضافة VBA module
        print("  Injecting VBA module...")
        
        try:
            # حذف module قديم إن وجد
            for mod in doc.VBProject.VBComponents:
                if mod.Name == "PageHelper":
                    doc.VBProject.VBComponents.Remove(mod)
                    break
        except:
            pass
        
        # إنشاء module جديد
        vb_module = doc.VBProject.VBComponents.Add(1)  # 1 = vbext_ct_StdModule
        vb_module.Name = "PageHelper"
        vb_module.CodeModule.AddFromString(VBA_CODE)
        
        # تشغيل الماكرو
        print("  Running macro (this is the fast part!)...")
        start = time.time()
        
        result = word.Application.Run("GetAllPageNumbers")
        
        elapsed = time.time() - start
        print(f"  Macro completed in {elapsed:.2f} seconds!")
        
        # تحليل النتيجة
        if result:
            parts = result.strip(',').split(',')
            page_numbers = [int(p) for p in parts if p.strip().isdigit()]
            print(f"  Got {len(page_numbers)} page numbers")
        
        # حذف الـ module (تنظيف)
        try:
            for mod in doc.VBProject.VBComponents:
                if mod.Name == "PageHelper":
                    doc.VBProject.VBComponents.Remove(mod)
                    break
        except:
            pass
        
        doc.Close(False)
        word.Quit()
        
    except Exception as e:
        print(f"  Error: {e}")
        print("  Tip: Make sure 'Trust access to VBA project object model' is enabled in Word Trust Center")
        try:
            word.Quit()
        except:
            pass
        return None, 0
    
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

def inject_vba(docx_path, output_path):
    """الحقن باستخدام VBA"""
    start_time = time.time()
    register_namespaces()
    
    # 1. الحصول على أرقام الصفحات من VBA
    page_numbers, total_pages = get_page_numbers_via_vba(docx_path)
    
    if not page_numbers:
        print("ERROR: Could not get page numbers")
        print("\nTo enable VBA access:")
        print("1. Open Word")
        print("2. File > Options > Trust Center > Trust Center Settings")
        print("3. Macro Settings > Check 'Trust access to the VBA project object model'")
        return False
    
    # 2. قراءة XML
    print("\nInjecting into XML...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml')
    
    root = ET.fromstring(content)
    body = root.find(f"{{{NS['w']}}}body")
    
    all_paras = list(body.iter(f"{{{NS['w']}}}p"))
    print(f"  XML paragraphs: {len(all_paras)}")
    print(f"  Word paragraphs: {len(page_numbers)}")
    
    # 3. الحقن
    injected = 0
    for i, para in enumerate(all_paras):
        if i < len(page_numbers):
            inject_into_para(para, page_numbers[i])
            injected += 1
    
    # 4. حفظ
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
    
    # 5. التحقق
    import re
    with zipfile.ZipFile(output_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
    
    markers = re.findall(r'\{PG:(\d+)\}', content)
    pages = [int(m) for m in markers]
    
    print(f"\n{'='*50}")
    print(f"=== RESULT ===")
    print(f"Total time: {elapsed:.1f} seconds")
    print(f"Injected: {injected} markers")
    print(f"Page range: {min(pages)} to {max(pages)}")
    print(f"Word pages: {total_pages}")
    
    if max(pages) == total_pages:
        print("✓ PERFECT MATCH!")
    elif max(pages) >= total_pages - 1:
        print("✓ CLOSE MATCH!")
    else:
        print(f"⚠ Gap: {total_pages - max(pages)}")
    
    print(f"\nOutput: {output_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        output_path = input_path.replace('.docx', '_VBA.docx')
        inject_vba(input_path, output_path)
    else:
        print("Usage: python inject_vba.py <docx_path>")
        print("\nIMPORTANT: Enable VBA access in Word:")
        print("  File > Options > Trust Center > Trust Center Settings")
        print("  > Macro Settings > Check 'Trust access to VBA project object model'")
