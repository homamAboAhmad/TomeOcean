import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(encoding='utf-8')

tree = ET.parse(r'd:\ImportantProjects\golden_shamela\temp_styles.xml')
root = tree.getroot()
ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

# Find heading 1
for style in root.findall('.//w:style', ns):
    sid = style.get(f'{{{W}}}styleId')
    name_el = style.find('w:name', ns)
    name = name_el.get(f'{{{W}}}val') if name_el is not None else '?'
    if 'heading 1' in name.lower() or sid == '1':
        print(f"\n=== HEADING 1: ID='{sid}' name='{name}' ===")
        print(ET.tostring(style, encoding='unicode'))

# Also find style a0 (Normal - basedOn for heading 2)
for style in root.findall('.//w:style', ns):
    sid = style.get(f'{{{W}}}styleId')
    name_el = style.find('w:name', ns)
    name = name_el.get(f'{{{W}}}val') if name_el is not None else '?'
    if sid == 'a0':
        print(f"\n=== STYLE a0: ID='{sid}' name='{name}' ===")
        print(ET.tostring(style, encoding='unicode'))
