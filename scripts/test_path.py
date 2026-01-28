import os
import sys

path = "C:\\Users\\HP\\Documents\\المكتبة"
print(f"Testing access to: {path}")

try:
    if os.path.exists(path):
        print("Path exists!")
        files = os.listdir(path)
        print(f"Found {len(files)} files.")
    else:
        print("Path does not exist (according to python).")
except Exception as e:
    print(f"Error accessing path: {e}")

input("Press Enter to exit...")
