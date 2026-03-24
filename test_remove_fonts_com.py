import win32com.client as win32
import os
import shutil
import stat
import zipfile
import re
from lxml import etree as ET

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'
writable_book = r'd:\ImportantProjects\golden_shamela\writable_test.docx'

if not os.path.exists(book):
    print('File not found.')
    exit(1)

print('Copying to writable file...')
shutil.copy2(book, writable_book)
os.chmod(writable_book, stat.S_IWRITE)

# Remove embedded fonts to avoid Read-Only lock
print('Removing embedded fonts from fontTable.xml...')
temp_dir = writable_book + '_extract'
os.makedirs(temp_dir, exist_ok=True)
with zipfile.ZipFile(writable_book, 'r') as z:
    z.extractall(temp_dir)

font_table_path = os.path.join(temp_dir, 'word', 'fontTable.xml')
if os.path.exists(font_table_path):
    NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    ET.register_namespace('w', NS['w'])
    try:
        tree = ET.parse(font_table_path)
        root = tree.getroot()
        fonts_modified = False
        for font in root.findall('.//w:font', NS):
            for embed in list(font):
                if embed.tag in [f'{{{NS["w"]}}}embedRegular', f'{{{NS["w"]}}}embedBold', f'{{{NS["w"]}}}embedItalic', f'{{{NS["w"]}}}embedBoldItalic']:
                    font.remove(embed)
                    fonts_modified = True
        
        if fonts_modified:
            tree.write(font_table_path, encoding='utf-8', xml_declaration=True)
            print('Removed embedded font tags.')
            
            # Rezip the docx
            os.remove(writable_book)
            with zipfile.ZipFile(writable_book, 'w', zipfile.ZIP_DEFLATED) as z:
                for root_dir, _, files in os.walk(temp_dir):
                    for file in files:
                        file_path = os.path.join(root_dir, file)
                        arcname = os.path.relpath(file_path, temp_dir)
                        z.write(file_path, arcname)
    except Exception as e:
        print(f'Error processing fontTable.xml: {e}')

shutil.rmtree(temp_dir, ignore_errors=True)

print('Starting Word COM...')
word = win32.DispatchEx('Word.Application')
word.Visible = False
word.DisplayAlerts = 0
word.AutomationSecurity = 1

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
            pass
            
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
