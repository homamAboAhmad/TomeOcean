import os
import sys
import subprocess
import re

def run_pagination_test(target_dir):
    print(f"Scanning directory: {target_dir}")
    
    docx_files = []
    for root, dirs, files in os.walk(target_dir):
        for f in files:
            if f.endswith(".docx") and not f.startswith("~$"):
                docx_files.append(os.path.join(root, f))
    
    print(f"Found {len(docx_files)} files.")
    
    results = []
    
    for file_path in docx_files[:3]:
        print(f"\nTesting: {os.path.basename(file_path)}")
        try:
            output_folder = "test_output"
            if not os.path.exists(output_folder):
                os.makedirs(output_folder)
                
            cmd = [sys.executable, "scripts/pageRender.py", output_folder, file_path]
            
            result = subprocess.run(cmd, capture_output=True)
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
                    status = "✅ EXACT MATCH"
                else:
                    status = f"❌ DIFF: {diff}"
            else:
                status = "❌ PARSE ERROR"
            
            results.append({
                "file": os.path.basename(file_path),
                "original": initial_pages,
                "result": final_pages,
                "status": status
            })
            
            print(f"  -> Original: {initial_pages}, Result: {final_pages} => {status}")
            
        except Exception as e:
            print(f"  -> Error: {e}")

    print("\n" + "="*60)
    print("FINAL PAGINATION TEST REPORT")
    print("="*60)
    for r in results:
        print(f"{r['file'][:40]:<40} | {str(r['original']):<6} | {str(r['result']):<6} | {r['status']}")
    print("="*60)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        target = r"C:\Users\nkxa2\Documents\البحر المحيط"
    else:
        target = sys.argv[1]
    run_pagination_test(target)
