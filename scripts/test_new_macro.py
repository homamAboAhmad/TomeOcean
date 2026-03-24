"""
test_new_macro.py - Verify ShamelaPrepareDoc macro
"""
import win32com.client as win32
import os

dotm_path = r'd:\ImportantProjects\golden_shamela\scripts\shamela_helper.dotm'
book_path = r'C:\Users\HP\Documents\57pحوار هادئ مع الصوفية.docx'

word = win32.DispatchEx('Word.Application')
word.Visible = True # Keep visible for debugging if needed
word.DisplayAlerts = 0

try:
    print(f'Opening: {book_path}')
    doc = word.Documents.Open(book_path, ReadOnly=True, AddToRecentFiles=False)
    
    print('Attaching template...')
    doc.AttachedTemplate = dotm_path
    doc.UpdateStylesOnOpen = False
    
    print('Running ShamelaPrepareDoc...')
    try:
        word.Run('ShamelaPrepareDoc')
        print('Macro completed successfully.')
    except Exception as e:
        # Try fully qualified name if simple name fails
        print(f'Simple run failed: {e}. Trying fully qualified...')
        word.Run('shamela_helper.dotm!ShamelaHelper.ShamelaPrepareDoc')
        print('Macro completed successfully (fully qualified).')
        
    # Check result property
    try:
        res = doc.CustomDocumentProperties("ShamelaResult").Value
        print(f'Result Property: {res}')
    except:
        print('Result property not found.')

    # Check for bookmarks
    print(f'Total Bookmarks: {doc.Bookmarks.Count}')
    
    # Check for a few expected bookmarks
    expected = ['ShamelaPage_1', 'ShamelaPage_5', 'ShamelaFN_1_P3']
    for name in expected:
        if doc.Bookmarks.Exists(name):
            print(f'Bookmark {name}: Found')
        else:
            print(f'Bookmark {name}: NOT FOUND')

    doc.Close(False)

except Exception as e:
    print(f'FAILED: {e}')
finally:
    word.Quit()
