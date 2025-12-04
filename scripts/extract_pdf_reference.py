#!/usr/bin/env python3
"""
Script to extract text from the ECMA Office Open XML PDF reference
Focusing on Word-related sections: footnotes, images, paragraphs, runs, etc.
"""

import fitz  # PyMuPDF
import sys
import os

def extract_pdf_sections(pdf_path, output_file=None):
    """Extract relevant sections from the PDF"""
    doc = fitz.open(pdf_path)
    
    print(f"PDF has {len(doc)} pages")
    
    # Keywords to search for relevant sections
    keywords = [
        'footnote', 'footnoteReference', 'w:footnote',
        'image', 'drawing', 'wp:anchor', 'wp:position',
        'paragraph', 'w:p', 'w:pPr',
        'run', 'w:r', 'w:rPr',
        'sectPr', 'section', 'page break',
        'relativeFrom', 'positionH', 'positionV',
        'w:drawing', 'wp:extent'
    ]
    
    relevant_pages = []
    all_text = []
    
    # Search through pages
    for page_num in range(len(doc)):
        page = doc[page_num]
        text = page.get_text().lower()
        
        # Check if page contains relevant keywords
        for keyword in keywords:
            if keyword.lower() in text:
                relevant_pages.append(page_num + 1)
                page_text = page.get_text()
                all_text.append(f"\n{'='*80}\n")
                all_text.append(f"PAGE {page_num + 1}\n")
                all_text.append(f"{'='*80}\n")
                all_text.append(page_text)
                all_text.append("\n")
                break
    
    # Also extract table of contents if available
    toc = doc.get_toc()
    if toc:
        all_text.insert(0, "\nTABLE OF CONTENTS:\n" + "="*80 + "\n")
        for item in toc:
            all_text.insert(1, f"Level {item[0]}: {item[1]} (Page {item[2]})\n")
        all_text.insert(2, "\n" + "="*80 + "\n\n")
    
    result = "".join(all_text)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(result)
        print(f"Extracted text saved to {output_file}")
        print(f"Found {len(relevant_pages)} relevant pages: {relevant_pages[:20]}...")
    else:
        print(result)
    
    doc.close()
    return result, relevant_pages

if __name__ == "__main__":
    pdf_path = r"D:\ImportantProjects\golden_shamela\WordXmlDoumentation\Ecma Office Open XML Part 1 - Fundamentals And Markup Language Reference.pdf"
    output_path = r"D:\ImportantProjects\golden_shamela\WordXmlDoumentation\extracted_reference.txt"
    
    if not os.path.exists(pdf_path):
        print(f"PDF file not found: {pdf_path}")
        sys.exit(1)
    
    extract_pdf_sections(pdf_path, output_path)

