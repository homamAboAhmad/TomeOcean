
# Alternative File Listing

PowerShell is struggling with paths (likely encoding or environment issues).
If `Get-ChildItem` fails, I will use a simple Python one-liner to list the `.docx` files in `C:\Users\nkxa2\Documents`.

```python
import os
root = r"C:\Users\nkxa2\Documents"
for dirpath, dirnames, filenames in os.walk(root):
    for f in filenames:
        if f.endswith(".docx") and not f.startswith("~$"):
            print(os.path.join(dirpath, f))
```
