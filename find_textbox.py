"""
البحث عن فقرات داخل Text Boxes (txbxContent)
"""
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'wps': 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
    'mc': 'http://schemas.openxmlformats.org/markup-compatibility/2006'
}

def find_textbox_paragraphs(docx_path):
    print(f"Searching for text box paragraphs: {docx_path}\n")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        content = z.read('word/document.xml').decode('utf-8')
        
        # البحث عن txbxContent في النص الخام
        import re
        
        # عد txbxContent
        txbx_matches = re.findall(r'<w:txbxContent[^>]*>', content)
        print(f"Found {len(txbx_matches)} <w:txbxContent> elements")
        
        # عد الفقرات داخل txbxContent
        # نستخدم regex لاستخراج محتوى كل txbxContent
        txbx_contents = re.findall(r'<w:txbxContent[^>]*>(.*?)</w:txbxContent>', content, re.DOTALL)
        
        total_p_in_txbx = 0
        for i, txbx in enumerate(txbx_contents):
            p_count = len(re.findall(r'<w:p[ >]', txbx))
            if p_count > 0:
                print(f"  TextBox {i+1}: {p_count} paragraphs")
                total_p_in_txbx += p_count
        
        print(f"\nTotal paragraphs in TextBoxes: {total_p_in_txbx}")
        
        # عد الفقرات العادية (خارج txbxContent)
        root = ET.fromstring(content.encode('utf-8'))
        body = root.find(f"{{{NS['w']}}}body")
        all_p = len(list(body.iter(f"{{{NS['w']}}}p")))
        
        print(f"\nTotal <w:p> via iter(): {all_p}")
        print(f"Regular body paragraphs: {all_p - total_p_in_txbx}")
        print(f"TextBox paragraphs: {total_p_in_txbx}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        find_textbox_paragraphs(sys.argv[1])
