import win32com.client as win32
import os

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'
if not os.path.exists(book):
    print('File not found.')
else:
    print('Starting Word COM...')
    word = win32.DispatchEx('Word.Application')
    word.Visible = False
    try:
        doc = word.Documents.Open(book, ReadOnly=False, Visible=False)
        doc.Repaginate()
        total_pages = doc.ComputeStatistics(2)
        print(f'Total pages: {total_pages}')
        
        # Try to add bookmarks directly via COM
        success_count = 0
        for p in range(1, min(10, total_pages + 1)):
            try:
                r = doc.GoTo(What=1, Which=1, Count=p)   
                r.Collapse(Direction=1) # wdCollapseStart
                doc.Bookmarks.Add(f'TestShamelaPage_{p}', r)
                success_count += 1
            except Exception as ex:
                print(f'Failed on page {p}: {ex}')       
        print(f'Successfully added {success_count} bookmarks via COM.')
        
        doc.Save()
        doc.Close(False)
    except Exception as e:
        print(f'Error: {e}')
    finally:
        word.Quit()
        print('Word closed.')

import zipfile, re
with zipfile.ZipFile(book, 'r') as z:
    with z.open('word/document.xml') as f:
        content = f.read().decode('utf-8')
        bookmarks = re.findall(r'<w:bookmarkStart[^>]*name=\"TestShamelaPage_(\d+)\"', content)
        print(f'Bookmarks found in XML after save: {bookmarks}')
