import zipfile, glob, sys, os
sys.stdout.reconfigure(encoding='utf-8')
files = glob.glob(r'C:\Users\HP\Documents\ex13*.docx')
print(f"Found: {files}")
f = files[0]
z = zipfile.ZipFile(f)
content = z.read('word/styles.xml').decode('utf-8')
z.close()
with open(r'd:\ImportantProjects\golden_shamela\temp_styles.xml', 'w', encoding='utf-8') as out:
    out.write(content)
print("Done")
