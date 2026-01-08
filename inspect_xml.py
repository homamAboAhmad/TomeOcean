import zipfile
import xml.etree.ElementTree as ET
import sys

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def inspect_pagination_xml(docx_path):
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    print(f"Inspecting: {docx_path}")
    print("="*60)
    
    para_count = 0
    for para in body:
        if para.tag == f"{{{NS['w']}}}p":
            para_count += 1
    
    print(f"Total Paragraphs: {para_count}")
    
    # Check for page break before property in pPr
    pagebreak_before_count = 0
    for para in body:
        if para.tag == f"{{{NS['w']}}}p":
            pPr = para.find(f"{{{NS['w']}}}pPr")
            if pPr is not None:
                pageBreakBefore = pPr.find(f"{{{NS['w']}}}pageBreakBefore")
                if pageBreakBefore is not None:
                    pagebreak_before_count += 1
                    print(f"  Found pageBreakBefore in paragraph")
    
    print(f"Paragraphs with pageBreakBefore: {pagebreak_before_count}")
    
    # Check last few paragraphs
    print("\nLast 5 Paragraphs:")
    paras = [p for p in body if p.tag == f"{{{NS['w']}}}p"]
    for i, para in enumerate(paras[-5:]):
        actual_idx = len(paras) - 5 + i
        
        # Get text
        text_parts = []
        for t in para.findall(f".//{{{NS['w']}}}t"):
            if t.text:
                text_parts.append(t.text)
        text = ''.join(text_parts)[:50]
        
        # Check for breaks
        has_last_rendered = para.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None
        has_explicit_br = False
        for br in para.findall(f".//{{{NS['w']}}}br"):
            if br.get(f"{{{NS['w']}}}type") == "page":
                has_explicit_br = True
        
        # Check for section break
        pPr = para.find(f"{{{NS['w']}}}pPr")
        has_sect_break = False
        if pPr is not None:
            sectPr = pPr.find(f"{{{NS['w']}}}sectPr")
            if sectPr is not None:
                has_sect_break = True
        
        # Check for pageBreakBefore
        has_pb_before = False
        if pPr is not None:
            if pPr.find(f"{{{NS['w']}}}pageBreakBefore")is not None:
                has_pb_before = True
        
        markers = []
        if has_last_rendered:
            markers.append("lastRendered")
        if has_explicit_br:
            markers.append("explicit_br")
        if has_sect_break:
            markers.append("sectBreak")
        if has_pb_before:
            markers.append("pbBefore")
        
        marker_str = ", ".join(markers) if markers else "none"
        print(f"  Para #{actual_idx}: [{marker_str}] {repr(text)}")
    
    # Check final body sectPr
    final_sect = body.find(f"{{{NS['w']}}}sectPr")
    if final_sect is not None:
        print(f"\nFinal body/sectPr exists: YES")
        type_elem = final_sect.find(f"{{{NS['w']}}}type")
        if type_elem is not None:
            val_attr = f"{{{NS['w']}}}val"
            print(f"  Type: {type_elem.get(val_attr)}")
        else:
            print(f"  Type: (not specified - defaults to nextPage)")
    else:
        print(f"\nFinal body/sectPr exists: NO")

if __name__ == "__main__":
    inspect_pagination_xml(sys.argv[1])
