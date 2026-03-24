import win32com.client as win32
import os
import shutil
import stat
import zipfile
import re

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'
writable_book = r'd:\ImportantProjects\golden_shamela\writable_test.docx'

if not os.path.exists(book):
    print('File not found.')
    exit(1)

print('Copying to writable file...')
shutil.copy2(book, writable_book)
os.chmod(writable_book, stat.S_IWRITE)

print('Starting Word COM...')
word = win32.DispatchEx('Word.Application')
word.Visible = False
word.DisplayAlerts = 0

try:
    doc = word.Documents.Open(writable_book, ReadOnly=False, Visible=False)
    doc.Repaginate()
    total_pages = doc.ComputeStatistics(2)
    print(f'Total pages computed by Word COM: {total_pages}')
    
    success_count = 0
    for p in range(1, min(20, total_pages + 1)):
        try:
            r = doc.GoTo(What=1, Which=1, Count=p)
            r.Collapse(Direction=1)
            doc.Bookmarks.Add(f'TestShamelaPage_{p}', r)
            success_count += 1
        except Exception as ex:
            print(f'Failed on page {p}: {ex}')
            
    print(f'Successfully added {success_count} bookmarks via COM.')
    
    doc.Save()
    print('Saved successfully.')
    doc.Close(False)
except Exception as e:
    print(f'Error via COM: {e}')
finally:
    word.Quit()
    print('Word closed.')

# Check XML
with zipfile.ZipFile(writable_book, 'r') as z:
    with z.open('word/document.xml') as f:
        content = f.read().decode('utf-8')
        
        bookmarks = re.findall(r'<w:bookmarkStart[^>]*name=\"TestShamelaPage_(\d+)\"', content)
        print(f'\nTest bookmarks found in XML ({len(bookmarks)}): {bookmarks}')
        
        sham_bookmarks = re.findall(r'<w:bookmarkStart[^>]*name=\"ShamelaPage_(\d+)\"', content)
        print(f'ShamelaPage bookmarks found in XML ({len(sham_bookmarks)}): {sham_bookmarks}')
        
        last_breaks = re.findall(r'<w:lastRenderedPageBreak/>', content)
        print(f'lastRenderedPageBreak tags found: {len(last_breaks)}')
