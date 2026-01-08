
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def debug_breaks_map(docx_path):
    print(f"Mapping Breaks: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    # قائمة لتخزين كل الفواصل مع مواقعها
    all_breaks = []
    
    para_index = 0
    for element in body:
        if element.tag == f"{{{NS['w']}}}p":
            para_index += 1
            
            # فحص هذا الباراغراف
            p_breaks = []
            
            # فحص lastRendered
            if element.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                p_breaks.append("LAST_RENDERED")
            
            # فحص manual
            for br in element.findall(f".//{{{NS['w']}}}br"):
                if br.get(f"{{{NS['w']}}}type") == "page":
                    p_breaks.append("MANUAL")
            
            if p_breaks:
                all_breaks.append(f"Para {para_index}: {', '.join(p_breaks)}")

        elif element.tag == f"{{{NS['w']}}}tbl":
            # فحص الجدول
            para_index += 1 # نعتبر الجدول كتلة واحدة للتبسيط
            t_breaks = []
            if element.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                t_breaks.append("TBL_LAST_RENDERED")
            for br in element.findall(f".//{{{NS['w']}}}br"):
                if br.get(f"{{{NS['w']}}}type") == "page":
                    t_breaks.append("TBL_MANUAL")
            
            if t_breaks:
                all_breaks.append(f"Table {para_index}: {', '.join(t_breaks)}")

    # طباعة أول 50 وآخر 50
    print("\n--- First 50 Breaks ---")
    for b in all_breaks[:50]:
        print(b)
        
    print("\n...\n")
    
    print("--- Last 50 Breaks ---")
    for b in all_breaks[-50:]:
        print(b)
        
    print(f"\nTotal Breaks Found: {len(all_breaks)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        debug_breaks_map(sys.argv[1])
