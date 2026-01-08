
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def check_hidden_breaks(docx_path):
    print(f"Checking for Hidden Breaks in: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    hidden_manual = 0
    hidden_lastRendered = 0
    
    # دالة لفحص ما إذا كان الـ run مخفياً
    def is_run_hidden(run_element):
        rPr = run_element.find(f"{{{NS['w']}}}rPr")
        if rPr is not None:
            vanish = rPr.find(f"{{{NS['w']}}}vanish")
            if vanish is not None:
                # <w:vanish> tag existence usually implies True, or val="true"/"1"/"on"
                val = vanish.get(f"{{{NS['w']}}}val")
                if val is None or val.lower() in ['true', '1', 'on']:
                    return True
        return False

    for run in body.iter(f"{{{NS['w']}}}r"):
        if is_run_hidden(run):
            # فحص هل داخله فواصل
            for br in run.findall(f".//{{{NS['w']}}}br"):
                if br.get(f"{{{NS['w']}}}type") == "page":
                    hidden_manual += 1
                    
            if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                hidden_lastRendered += 1

    print("-" * 30)
    print(f"Hidden Manual Breaks: {hidden_manual}")
    print(f"Hidden LastRendered Breaks: {hidden_lastRendered}")
    print("-" * 30)
    print(f"Total Potential Excess from Hidden: {hidden_manual + hidden_lastRendered}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        check_hidden_breaks(sys.argv[1])
