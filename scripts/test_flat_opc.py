import win32com.client as win32
import os
import xml.etree.ElementTree as ET

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'

print('Starting Word COM for diagnostics...')
word = win32.DispatchEx('Word.Application')
word.Visible = False

try:
    doc = word.Documents.Open(book, ReadOnly=True, Visible=False)
    xml_content = doc.WordOpenXML
    doc.Close(False)

    print("--- RAW XML START (First 1000 chars) ---")
    print(xml_content[:1000])
    print("--- RAW XML END ---")

    root = ET.fromstring(xml_content.encode('utf-8'))
    print(f"\nRoot tag: {root.tag}")
    
    # Let's just find tags that end with 'part' ignoring namespace
    for elem in root.iter():
        if elem.tag.endswith('part'):
            print(f"Found part tag: {elem.tag}, attributes: {elem.attrib}")
            break # just print the first one

except Exception as e:
    print(f'Error: {e}')
finally:
    word.Quit()
