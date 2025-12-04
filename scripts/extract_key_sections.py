#!/usr/bin/env python3
"""
Extract key sections from the ECMA Office Open XML PDF reference
Focusing on WordprocessingML core sections
"""

import fitz  # PyMuPDF
import sys
import os
import re

def extract_key_sections(pdf_path, output_file=None):
    """Extract key WordprocessingML sections"""
    doc = fitz.open(pdf_path)
    
    print(f"PDF has {len(doc)} pages")
    
    # Key sections to extract (section numbers and keywords)
    key_sections = {
        '17.2': 'Main Document Story',
        '17.3': 'Paragraphs and Rich Formatting',
        '17.4': 'Tables',
        '17.6': 'Sections',
        '17.7': 'Styles',
        '17.8': 'Fonts',
        '17.9': 'Numbering',
        '17.10': 'Headers and Footers',
        '17.11': 'Footnotes and Endnotes',
        '17.12': 'Glossary Document',
        '20.4': 'DrawingML - WordprocessingML Drawing',
        'L.1': 'Introduction to WordprocessingML',
    }
    
    all_text = []
    found_sections = {}
    
    # Search through pages
    for page_num in range(len(doc)):
        page = doc[page_num]
        text = page.get_text()
        
        # Check for section headers
        for section_num, section_name in key_sections.items():
            # Look for section number patterns like "17.2", "17.3", etc.
            pattern = rf'\b{re.escape(section_num)}\b'
            if re.search(pattern, text, re.IGNORECASE):
                if section_num not in found_sections:
                    found_sections[section_num] = {
                        'name': section_name,
                        'pages': [],
                        'content': []
                    }
                found_sections[section_num]['pages'].append(page_num + 1)
                found_sections[section_num]['content'].append(text)
                all_text.append(f"\n{'='*80}\n")
                all_text.append(f"SECTION {section_num}: {section_name} (Page {page_num + 1})\n")
                all_text.append(f"{'='*80}\n")
                all_text.append(text)
                all_text.append("\n")
    
    # Summary
    summary = "\n" + "="*80 + "\n"
    summary += "EXTRACTED SECTIONS SUMMARY\n"
    summary += "="*80 + "\n"
    for section_num, info in found_sections.items():
        summary += f"{section_num}: {info['name']} - Pages: {info['pages'][:5]}{'...' if len(info['pages']) > 5 else ''}\n"
    summary += "\n" + "="*80 + "\n"
    
    result = summary + "".join(all_text)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(result)
        print(f"Extracted text saved to {output_file}")
        print(f"Found {len(found_sections)} key sections")
    else:
        print(result)
    
    doc.close()
    return result, found_sections

if __name__ == "__main__":
    pdf_path = r"D:\ImportantProjects\golden_shamela\WordXmlDoumentation\Ecma Office Open XML Part 1 - Fundamentals And Markup Language Reference.pdf"
    output_path = r"D:\ImportantProjects\golden_shamela\WordXmlDoumentation\key_sections.txt"
    
    if not os.path.exists(pdf_path):
        print(f"PDF file not found: {pdf_path}")
        sys.exit(1)
    
    extract_key_sections(pdf_path, output_path)

