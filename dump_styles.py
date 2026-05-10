import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(encoding='utf-8')

tree = ET.parse(r'd:\ImportantProjects\golden_shamela\temp_styles.xml')
root = tree.getroot()

ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

for style in root.findall('.//w:style', ns):
    sid = style.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}styleId')
    stype = style.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}type')
    name_el = style.find('w:name', ns)
    name = name_el.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val') if name_el is not None else '?'
    
    # Print full XML for heading styles (1, 2, 3) and their basedOn
    if sid in ['1', '2', '3', 'a', 'a0', 'a1', 'a2', 'a3', 'a4', 'Normal']:
        print(f"\n=== Style ID='{sid}' type='{stype}' name='{name}' ===")
        print(ET.tostring(style, encoding='unicode'))
    else:
        print(f"Style ID='{sid}' type='{stype}' name='{name}'")
