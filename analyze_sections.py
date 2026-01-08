
import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def analyze_sections(docx_path):
    print(f"Analyzing Section Breaks: {docx_path}")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    section_count = 0
    
    for i, p in enumerate(body.iter(f"{{{NS['w']}}}p")):
        pPr = p.find(f"{{{NS['w']}}}pPr")
        if pPr is not None:
            sectPr = pPr.find(f"{{{NS['w']}}}sectPr")
            if sectPr is not None:
                section_count += 1
                
                # خصائص القسم
                s_type = sectPr.find(f"{{{NS['w']}}}type")
                val = s_type.get(f"{{{NS['w']}}}val") if s_type is not None else "nextPage (Implicit)"
                
                print(f"Para {i}: Section Break Found. Type: {val}")
                
                # هل يوجد lastRenderedPageBreak في هذه الفقرة؟
                has_last = p.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None
                if has_last:
                    print(f"   -> WARNING: Contains lastRenderedPageBreak too!")

                # هل يوجد Manual Break؟
                has_manual = False
                for br in p.findall(f".//{{{NS['w']}}}br"):
                    if br.get(f"{{{NS['w']}}}type") == "page":
                        has_manual = True
                
                if has_manual:
                    print(f"   -> WARNING: Contains Manual Page Break too!")

    # Final SectPr (at body level)
    final_sect = body.find(f"{{{NS['w']}}}sectPr")
    if final_sect is not None:
        print("Final Body Section Property Found.")

    print(f"Total Section Breaks in Paragraphs: {section_count}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        analyze_sections(sys.argv[1])
