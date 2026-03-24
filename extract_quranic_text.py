import re
import sys
import zipfile

# use the original docx from the test directory
docx_path = r"d:\ImportantProjects\golden_shamela\sa\sa.docx"
try:
    with zipfile.ZipFile(docx_path, 'r') as docx:
        content = docx.read('word/document.xml').decode('utf-8')
except FileNotFoundError:
    print(f"File not found: {docx_path}")
    sys.exit(1)

paragraphs = re.findall(r'<w:p\b[^>]*>.*?</w:p>', content, re.DOTALL)
found = False
for p in paragraphs:
    if 'ني ج' in p or 'الفتنة' in p or 'چ' in p or '﴿' in p or '﴾' in p:
        print("Found paragraph:")
        # Pretty print by adding newlines after >
        pretty_p = p.replace('><', '>\n<')
        print(pretty_p)
        print("-" * 40)
        found = True

if not found:
    print("Could not find the specified text in any paragraph.")
