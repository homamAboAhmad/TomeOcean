import sys
import io
import glob
import zipfile
import os
from xml.etree import ElementTree as ET

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

files = glob.glob('C:/Users/HP/Documents/المكتبة/*رجال الموطأ.docx')
if not files:
    print("No files found.")
    sys.exit(0)

f = files[0]
print(f"Reading file: {f}")

with zipfile.ZipFile(f, 'r') as z:
    xml = z.read('word/document.xml')
    root = ET.fromstring(xml)
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    
    tbls = root.findall('.//w:tbl', ns)
    if not tbls:
        print("No tables found.")
        sys.exit(0)
        
    tbl = tbls[0]
    
    print('--- Header Row ---')
    trs = tbl.findall('.//w:tr', ns)
    if not trs:
        print("No rows found.")
        sys.exit(0)
        
    tr = trs[0]
    for i, tc in enumerate(tr.findall('.//w:tc', ns)):
        tcW = tc.find('.//w:tcPr/w:tcW', ns)
        tcW_val = tcW.attrib if tcW is not None else 'None'
        print(f'Col {i}: tcW={tcW_val}')
        
        ps = tc.findall('.//w:p', ns)
        for j, p in enumerate(ps):
            texts = [t.text for r in p.findall('.//w:r', ns) for t in r.findall('.//w:t', ns) if t.text]
            text_str = "".join(texts)
            print(f'  p[{j}] text: "{text_str}"')
            
            pPr = p.find('.//w:pPr', ns)
            if pPr is not None:
                spacing = pPr.find('.//w:spacing', ns)
                if spacing is not None:
                    print(f'      spacing: {spacing.attrib}')
