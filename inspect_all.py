"""
فحص كل ملفات XML في المستند
"""
import zipfile
import xml.etree.ElementTree as ET
import sys
import re

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def inspect_all_xml(docx_path):
    print(f"Inspecting: {docx_path}\n")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_files = [f for f in z.namelist() if f.endswith('.xml') and 'word/' in f]
        
        total_paras = 0
        
        for xml_file in sorted(xml_files):
            try:
                content = z.read(xml_file)
                root = ET.fromstring(content)
                paras = list(root.iter(f"{{{NS['w']}}}p"))
                
                if paras:
                    print(f"{xml_file}: {len(paras)} paragraphs")
                    total_paras += len(paras)
                    
                    # Check for PG markers
                    text_content = content.decode('utf-8', errors='ignore')
                    markers = re.findall(r'\{PG:(\d+)\}', text_content)
                    if markers:
                        pages = [int(m) for m in markers]
                        print(f"  -> Markers: {len(markers)}, Pages: {min(pages)}-{max(pages)}")
                        
            except Exception as e:
                pass
        
        print(f"\nTotal paragraphs in all word/*.xml: {total_paras}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Check original
        print("=== ORIGINAL FILE ===")
        inspect_all_xml(sys.argv[1])
        
        # Check processed file
        final_path = sys.argv[1].replace('.docx', '_FINAL.docx')
        print("\n\n=== PROCESSED FILE ===")
        try:
            inspect_all_xml(final_path)
        except:
            print("Processed file not found")
