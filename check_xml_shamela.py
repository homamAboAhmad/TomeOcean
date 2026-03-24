import zipfile, re

book = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'
with zipfile.ZipFile(book, 'r') as z:
    with z.open('word/document.xml') as f:
        content = f.read().decode('utf-8')
        print(f'Length of document.xml: {len(content)}')
        
        # Check if there are ShamelaPage bookmarks instead
        bookmarks = re.findall(r'<w:bookmarkStart[^>]*name=\"ShamelaPage_(\d+)\"', content)
        if bookmarks:
            print(f'Found {len(bookmarks)} ShamelaPage bookmarks: {bookmarks[:10]}...')
        else:
            print('No ShamelaPage bookmarks found either.')
            
        # Let's see if the file is just one giant page
        sectPrs = re.findall(r'<w:sectPr', content)
        print(f'Found {len(sectPrs)} sectPr tags.')
