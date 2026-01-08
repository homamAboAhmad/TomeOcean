import sys
import subprocess
import re
import time

file_path = sys.argv[1] if len(sys.argv) > 1 else None

if not file_path:
    print("الاستخدام: python test_ex7.py <path_to_docx>")
    sys.exit(1)

print(f"اختبار: {file_path}")
print("="*60)
print("⏱️  المهلة: 10 دقائق")
print("="*60)

start_time = time.time()

cmd = [sys.executable, "scripts/pageRender.py", "test_output", file_path]
result = subprocess.run(cmd, capture_output=True, timeout=600)

elapsed = time.time() - start_time
minutes = int(elapsed // 60)
seconds = int(elapsed % 60)

try:
    output = result.stdout.decode('utf-8')
except:
    output = result.stdout.decode('cp1256', errors='replace')

print(output)
print("="*60)
print(f"⏱️  الوقت المستغرق: {minutes} دقيقة و {seconds} ثانية")
print("="*60)

# Check if it's XML fallback mode
is_xml_fallback = "سيتم استخدام حساب XML كبديل" in output or "سيتم تخطي Word COM" in output
is_success = "SUCCESS" in output

match_initial = re.search(r"STATUS_INITIAL_PAGES:(\d+)", output)
match_final = re.search(r"عدد الصفحات الكلي:\s*(\d+)", output)

if is_xml_fallback:
    print("\n⚠️  تم استخدام XML Fallback (Word COM فشل أو تم تخطيه)")
    if match_final and is_success:
        final = int(match_final.group(1))
        print(f"✅ نجحت المعالجة!")
        print(f"📊 النتيجة (من XML): {final} صفحة")
        print(f"ℹ️  ملاحظة: لم يتم التحقق من Word لأن الملف كبير جداً أو Word فشل")
    else:
        print("❌ فشلت المعالجة")
elif match_initial and match_final:
    initial = int(match_initial.group(1))
    final = int(match_final.group(1))
    
    if initial == final:
        print(f"\n✅ تطابق تام! Word: {initial}, النتيجة: {final}")
    else:
        print(f"\n❌ عدم تطابق! Word: {initial}, النتيجة: {final} (فرق: {abs(initial - final)})")
else:
    print("\n❌ خطأ في القراءة أو معالجة الملف")
