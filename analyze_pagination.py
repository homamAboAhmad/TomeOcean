
import zipfile
import xml.etree.ElementTree as ET
import sys

# Namespaces
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
}

def analyze_deep(docx_path):
    print(f"Deep Analysis: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    
    # 1. تحليل تفصيلي لـ w:br
    br_types = {}
    for br in root.iter(f"{{{NS['w']}}}br"):
        t = br.get(f"{{{NS['w']}}}type", "textWrapping") # default is textWrapping
        c = br.get(f"{{{NS['w']}}}clear", "none")
        key = f"Type: {t}, Clear: {c}"
        br_types[key] = br_types.get(key, 0) + 1

    print("\n--- Break Types ---")
    for k, v in br_types.items():
        print(f"{k}: {v}")

    # 2. تحليل التقارب (Proximity)
    # هل هناك حالات كثيرة حيث br وبعده مباشرة lastRendered؟
    print("\n--- Proximity Analysis ---")
    body = root.find(f"{{{NS['w']}}}body")
    
    nearby_count = 0
    same_run_count = 0
    
    for para in body.iter(f"{{{NS['w']}}}p"):
        #Flatten runs content tags
        tags_sequence = []
        for child in para.iter():
            if child.tag == f"{{{NS['w']}}}br" and child.get(f"{{{NS['w']}}}type") == "page":
               tags_sequence.append('manual')
            elif child.tag == f"{{{NS['w']}}}lastRenderedPageBreak":
               tags_sequence.append('lastRendered')
        
        # Check sequence
        for i in range(len(tags_sequence) - 1):
            if tags_sequence[i] == 'manual' and tags_sequence[i+1] == 'lastRendered':
                nearby_count += 1
    
    print(f"Manual followed immediately by LastRendered in same para: {nearby_count}")

    # 3. تحليل الجداول
    print("\n--- Table Analysis ---")
    table_manuals = 0
    table_lastRendered = 0
    for tbl in body.iter(f"{{{NS['w']}}}tbl"):
        for br in tbl.iter(f"{{{NS['w']}}}br"):
            if br.get(f"{{{NS['w']}}}type") == "page":
                table_manuals += 1
        for lr in tbl.iter(f"{{{NS['w']}}}lastRenderedPageBreak"):
            table_lastRendered += 1
            
    print(f"Manual breaks inside tables: {table_manuals}")
    print(f"LastRendered breaks inside tables: {table_lastRendered}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        analyze_deep(sys.argv[1])
