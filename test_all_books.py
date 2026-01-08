import os
import sys
import subprocess
import re

def run_pagination_test(target_dir, exclude_folders=None):
    if exclude_folders is None:
        exclude_folders = []
    
    print(f"فحص المجلد: {target_dir}")
    print(f"استثناء المجلدات: {', '.join(exclude_folders) if exclude_folders else 'لا يوجد'}")
    print("="*60)
    
    docx_files = []
    for root, dirs, files in os.walk(target_dir):
        # تجاهل المجلدات المستثناة
        dirs[:] = [d for d in dirs if d not in exclude_folders]
        
        for f in files:
            if f.endswith(".docx") and not f.startswith("~$"):
                docx_files.append(os.path.join(root, f))
    
    print(f"تم العثور على {len(docx_files)} ملفات\n")
    
    results = []
    errors = []
    
    for idx, file_path in enumerate(docx_files, 1):
        filename = os.path.basename(file_path)
        print(f"[{idx}/{len(docx_files)}] اختبار: {filename}")
        try:
            output_folder = "test_output"
            if not os.path.exists(output_folder):
                os.makedirs(output_folder)
                
            cmd = [sys.executable, "scripts/pageRender.py", output_folder, file_path]
            
            result = subprocess.run(cmd, capture_output=True, timeout=600)  # 10 دقائق
            try:
                output = result.stdout.decode('utf-8')
            except:
                output = result.stdout.decode('cp1256', errors='replace')
            
            initial_pages = "N/A"
            final_pages = "N/A"
            
            match_initial = re.search(r"STATUS_INITIAL_PAGES:(\d+)", output)
            if match_initial:
                initial_pages = int(match_initial.group(1))
            
            match_final = re.search(r"عدد الصفحات الكلي:\s*(\d+)", output)
            if match_final:
                final_pages = int(match_final.group(1))
            
            status = "UNKNOWN"
            if initial_pages != "N/A" and final_pages != "N/A":
                diff = abs(initial_pages - final_pages)
                if diff == 0:
                    status = "✅ تطابق تام"
                else:
                    status = f"❌ فرق: {diff}"
                    errors.append({
                        "file": filename,
                        "word": initial_pages,
                        "result": final_pages,
                        "diff": diff
                    })
            else:
                status = "❌ خطأ في القراءة"
                errors.append({
                    "file": filename,
                    "error": "Failed to parse"
                })
            
            results.append({
                "file": filename,
                "original": initial_pages,
                "result": final_pages,
                "status": status
            })
            
            print(f"  Word: {initial_pages}, النتيجة: {final_pages} => {status}\n")
            
        except subprocess.TimeoutExpired:
            print(f"  ⏱️ انتهت المهلة (>10 دقائق)\n")
            results.append({
                "file": filename,
                "original": "TIMEOUT",
                "result": "TIMEOUT",
                "status": "⏱️ انتهت المهلة"
            })
            errors.append({"file": filename, "error": "Timeout"})
        except Exception as e:
            print(f"  خطأ: {e}\n")
            results.append({
                "file": filename,
                "original": "ERR",
                "result": "ERR",
                "status": f"خطأ: {e}"
            })
            errors.append({"file": filename, "error": str(e)})

    print("\n" + "="*60)
    print("تقرير الاختبار النهائي")
    print("="*60)
    print(f"{'اسم الملف':<40} | {'Word':<6} | {'نتيجة':<6} | {'حالة'}")
    print("-" * 80)
    for r in results:
        print(f"{r['file'][:40]:<40} | {str(r['original']):<6} | {str(r['result']):<6} | {r['status']}")
    print("="*60)
    
    exact_matches = sum(1 for r in results if r['status'] == "✅ تطابق تام")
    total = len(results)
    success_rate = (100*exact_matches//total) if total > 0 else 0
    
    print(f"\nمعدل النجاح: {exact_matches}/{total} ({success_rate}%)")
    
    if errors:
        print(f"\n⚠️  عدد الأخطاء: {len(errors)}")
        print("\nقائمة الأخطاء:")
        for err in errors[:10]:  # Show first 10 errors
            print(f"  - {err.get('file', 'Unknown')}: {err.get('error', err.get('diff', 'Unknown'))}")
        if len(errors) > 10:
            print(f"  ... و {len(errors) - 10} أخطاء أخرى")

if __name__ == "__main__":
    target = r"C:\Users\nkxa2\Documents"
    exclude = ["البحر المحيط"]
    run_pagination_test(target, exclude)
