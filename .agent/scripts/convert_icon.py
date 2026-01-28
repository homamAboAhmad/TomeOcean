from PIL import Image
import os

src = r"d:\ImportantProjects\golden_shamela\assets\icons\logo.png"
dst = r"d:\ImportantProjects\golden_shamela\windows\runner\resources\app_icon.ico"

try:
    if not os.path.exists(src):
        print(f"Error: Source file not found at {src}")
        exit(1)
        
    img = Image.open(src)
    # Save as ICO with multiple sizes for best scaling
    img.save(dst, format='ICO', sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    print(f"Success! Icon saved to {dst}")
except Exception as e:
    print(f"Error converting icon: {e}")
