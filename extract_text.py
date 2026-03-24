import re
import sys

# use the original docx from the test directory
xml_path = r"d:\ImportantProjects\golden_shamela\temp_docx_extract23116\word\document.xml"
try:
    with open(xml_path, 'r', encoding='utf-8') as f:
        content = f.read()
except FileNotFoundError:
    print(f"File not found: {xml_path}")
    sys.exit(1)

paragraphs = re.findall(r'<w:p\b[^>]*>.*?</w:p>', content, re.DOTALL)
found = False

with open(r"d:\ImportantProjects\golden_shamela\extract_text_output.xml", 'w', encoding='utf-8') as out_f:
    for p in paragraphs:
        if 'ني ج' in p or 'الفتنة' in p or 'چ' in p or '﴿' in p or '﴾' in p:
            out_f.write("Found paragraph:\n")
            # Pretty print by adding newlines after >
            pretty_p = p.replace('><', '>\n<')
            out_f.write(pretty_p + "\n")
            out_f.write("-" * 40 + "\n")
            found = True

    if not found:
        out_f.write("Could not find the specified text in any paragraph.\n")
