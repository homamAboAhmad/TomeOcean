import win32com.client as win32
import os
import psutil
import sys
import shutil
import tempfile
import stat

def kill_word_processes():
    """إغلاق نسخ الوورد المفتوحة"""
    for process in psutil.process_iter():
        try:
            if process.name().lower() == "winword.exe":
                process.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
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
    word_app = win32.Dispatch('Word.Application')
    word_app.Visible = False
    
    doc = word_app.Documents.Open(
        word_file_path, 
        ReadOnly=False,
        ConfirmConversions=False,
        AddToRecentFiles=False
    )
    
    # إيقاف تضمين الخطوط المقيدة
    try:
        doc.EmbedTrueTypeFonts = False
        if doc.Final:
            doc.Final = False
    except:
        pass
    
    return word_app, doc

def process_document(doc):
    """تحديث تخطيط الصفحات"""
    num_paragraphs = doc.Paragraphs.Count
    
    # تحديث الـ layout عبر الذهاب لآخر المستند
    try:
        last_para = doc.Paragraphs(doc.Paragraphs.Count)
        _ = last_para.Range.Information(3)  # wdActiveEndPageNumber
    except:
        pass

    # إجبار Word على إعادة حساب الصفحات بالكامل
    print("PROGRESS:20", flush=True)
    try:
        doc.Repaginate()
    except:
        pass
    
    print("PROGRESS:50", flush=True)
    
    # استخدام ComputeStatistics يُجبر Word على حساب عدد الصفحات الفعلي
    try:
        _ = doc.ComputeStatistics(2) # wdStatisticPages
    except:
        pass
        
    print("PROGRESS:100", flush=True)

def save_and_close(doc, word_app, temp_file_path, output_file_path):
    """حفظ ونقل الملف"""
    saved = False
    error_message = None
    
    # محاولة SaveAs2 مباشرة للوجهة
    try:
        doc.EmbedTrueTypeFonts = False
        doc.SaveAs2(output_file_path, FileFormat=16)
        saved = True
    except Exception as e:
        error_str = str(e)
        if "read-only" in error_str.lower() or "restricted" in error_str.lower():
            error_message = "FONT_ERROR"
        else:
            error_message = str(e)[:100]
    
    # إغلاق Word
    try:
        doc.Close(False)
        word_app.Quit()
    except:
        pass
    
    # إذا فشل الحفظ، انسخ من temp
    if not saved:
        if os.path.exists(output_file_path):
            os.remove(output_file_path)
        shutil.move(temp_file_path, output_file_path)
        
        if error_message == "FONT_ERROR":
            print("WARNING:FONT_RESTRICTED", flush=True)
    else:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
    
    print("SUCCESS", flush=True)

def main():
    print("START", flush=True)
    
    kill_word_processes()
    word_file_path, output_file_path = validate_input()
    
    print("STATUS:جاري إنشاء نسخة مؤقتة...", flush=True)
    temp_file_path = create_temp_copy(word_file_path)
    
    print("STATUS:جاري فتح الملف في Word...", flush=True)
    word_app, doc = open_word_document(temp_file_path)
    
    try:
        print("STATUS:جاري تحديث تخطيط الصفحات...", flush=True)
        process_document(doc)
        
        print("STATUS:جاري حفظ الملف...", flush=True)
        save_and_close(doc, word_app, temp_file_path, output_file_path)
        
    except Exception as e:
        print(f"ERROR:{e}", flush=True)
        try:
            doc.Close(False)
            word_app.Quit()
        except:
            pass
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
        sys.exit(1)

if __name__ == "__main__":
    main()
