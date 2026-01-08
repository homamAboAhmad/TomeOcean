import win32com.client as win32
import sys

def check_last_page(docx_path):
    word = win32.Dispatch("Word.Application")
    try:
        word.Visible = False
    except:
        pass
    
    doc = word.Documents.Open(docx_path)
    
    # Force pagination
    word.ActiveWindow.View.Type = 3
    doc.Repaginate()
    
    total_pages = doc.ComputeStatistics(2)
    print(f"Total Pages: {total_pages}")
    
    # Get content on last page
    print(f"\nContent on Page {total_pages}:")
    print("="*60)
    
    for i, para in enumerate(doc.Paragraphs):
        try:
            para_range = para.Range
            para_range.Collapse(1)
            page_num = para_range.Information(3)
            
            if page_num == total_pages:
                text = para.Range.Text.strip()
                if text:
                    print(f"Para #{i}: {repr(text[:100])}")
        except:
            pass
    
    doc.Close(False)
    word.Quit()

if __name__ == "__main__":
    check_last_page(sys.argv[1])
