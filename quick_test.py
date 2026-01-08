import sys
import subprocess
import re

file_path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\nkxa2\Documents\البحر المحيط\رحلة الحروف.docx"

print(f"اختبار: {file_path}")
print("="*60)

cmd = [sys.executable, "scripts/pageRender.py", "test_output", file_path]
result = subprocess.run(cmd, capture_output=True)

try:
    output = result.stdout.decode('utf-8')
except:
    output = result.stdout.decode('cp1256', errors='replace')

print(output)
print("="*60)

match_initial = re.search(r"STATUS_INITIAL_PAGES:(\d+)", output)
match_final = re.search(r"عدد الصفحات الكلي:\s*(\d+)", output)

if match_initial and match_final:
    initial = int(match_initial.group(1))
    final = int(match_final.group(1))
    
    if initial == final:
        print(f"\n✅ نجح! Word: {initial}, النتيجة: {final} (تطابق تام)")
    else:
        print(f"\n❌ فشل! Word: {initial}, النتيجة: {final} (فرق: {abs(initial - final)})")
else:
    print("\n❌ خطأ في القراءة")
