import win32com.client as win32
import os
import xml.etree.ElementTree as ET

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'

print('Starting Word COM for diagnostics...')
word = win32.DispatchEx('Word.Application')
word.Visible = False

try:
    doc = word.Documents.Open(book, ReadOnly=True, Visible=False)
    flat_opc_xml = doc.WordOpenXML
    doc.Close(False)

    root = ET.fromstring(flat_opc_xml.encode('utf-8'))
    pkg_ns = {'pkg': 'http://schemas.microsoft.com/office/2006/xmlPackage'}
    
    for part in root.findall('.//pkg:part', pkg_ns):
        if part.attrib.get('{http://schemas.microsoft.com/office/2006/xmlPackage}name') == '/word/document.xml':
            xmlData = part.find('.//pkg:xmlData', pkg_ns)
            if xmlData is not None and len(xmlData) > 0:
                doc_root = xmlData[0]
                document_xml_str = ET.tostring(doc_root, encoding='utf-8', xml_declaration=True).decode('utf-8')
                print("EXTRACTED DOCUMENT.XML START (first 1000):")
                print(document_xml_str[:1000])
            break
except Exception as e:
    print(f'Error: {e}')
finally:
    word.Quit()
