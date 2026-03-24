import sys
import re

xml_path = r"d:\ImportantProjects\golden_shamela\ex3_withPNM\word\document.xml"
with open(xml_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find all occurrences of "تعالى"
matches = re.finditer(r'تعالى.*?</w:t>', content)
count = 0
with open(r"d:\ImportantProjects\golden_shamela\context_search.txt", 'w', encoding='utf-8') as out:
    for m in matches:
        start = m.end()
        # Look at the next 500 characters
        context = content[start:start+500]
        out.write(f"Match {count}:\n{context}\n")
        out.write("-" * 40 + "\n")
        count += 1
        if count > 20: break
