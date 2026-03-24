import win32com.client as win32
import os

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'

print('Starting Word COM...')
word = win32.DispatchEx('Word.Application')
word.Visible = False
word.DisplayAlerts = 0

try:
    doc = word.Documents.Open(book, ReadOnly=True, Visible=False)
    
    success_count = 0
    for p in range(1, 4):
        try:
            r = doc.GoTo(What=1, Which=1, Count=p)
            r.Collapse(Direction=1)
            doc.Bookmarks.Add(f'TestAPI_{p}', r)
            success_count += 1
        except Exception as ex:
            print(f'Failed on page {p}: {ex}')
            
    print(f'Successfully added {success_count} bookmarks via COM in Read-Only memory.')
    
    # Extract XML directly without saving
    xml_content = doc.WordOpenXML
    
    import re
    bookmarks = re.findall(r'<w:bookmarkStart[^>]*name=\"TestAPI_(\d+)\"', xml_content)
    print(f'\nTest bookmarks found in memory XML ({len(bookmarks)}): {bookmarks}')
    
    doc.Close(False)
except Exception as e:
    print(f'Error via COM: {e}')
finally:
    word.Quit()
    print('Word closed.')
