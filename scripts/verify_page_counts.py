import os
import sys
import subprocess
import re
import glob

# Configuration
# Assuming script is in d:\ImportantProjects\golden_shamela\scripts\
# We need to find pageRender.py in the same directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PAGE_RENDER_SCRIPT = os.path.join(SCRIPT_DIR, "pageRender.py")

# Target Directory
BOOKS_DIR = r"C:\Users\HP\Documents\ex3_parts"
OUTPUT_DIR = os.path.join(BOOKS_DIR, "page_verification_output")

def verify_books():
    if not os.path.exists(BOOKS_DIR):
        print(f"Error: Directory not found: {BOOKS_DIR}")
        return

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    docx_files = glob.glob(os.path.join(BOOKS_DIR, "*.docx"))
    
    # Filter out temp files or output files
    docx_files = [f for f in docx_files if not os.path.basename(f).startswith("~$")]
    
    print(f"Found {len(docx_files)} books to verify in {BOOKS_DIR}")
    print("-" * 80)
    print(f"{'Book Name':<40} | {'Real (Word)':<12} | {'Appeared (XML)':<14} | {'Diff':<6}")
    print("-" * 80)

    results = []

    for i, docx_path in enumerate(docx_files):
        book_name = os.path.basename(docx_path)
        
        # Run pageRender.py
        # Command: python pageRender.py "OUTPUT_DIR" "DOCX_PATH" --stage full
        cmd = [sys.executable, PAGE_RENDER_SCRIPT, OUTPUT_DIR, docx_path, "--stage", "full"]
        
        try:
            # Run process and capture output
            result = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True, 
                encoding='utf-8',
                errors='replace' # Handle potential encoding issues in logs
            )
            
            output = result.stdout
            
            # Extract Real Pages (Word)
            # Regex: STATUS:Total Pages: (\d+)
            real_match = re.search(r"STATUS:Total Pages:\s*(\d+)", output)
            real_pages = int(real_match.group(1)) if real_match else 0
            
            # Extract Appeared Pages (XML)
            # Regex: STATUS:Injected .* Last Page: (\d+)
            xml_match = re.search(r"STATUS:Injected .* Last Page:\s*(\d+)", output)
            appeared_pages = int(xml_match.group(1)) if xml_match else 0
            
            diff = appeared_pages - real_pages
            
            results.append({
                'name': book_name,
                'real': real_pages,
                'appeared': appeared_pages,
                'diff': diff
            })
            
            print(f"{book_name:<40} | {real_pages:<12} | {appeared_pages:<14} | {diff:<6}")
            
        except Exception as e:
            print(f"{book_name:<40} | ERROR: {str(e)}")

    print("-" * 80)
    print("Summary:")
    perfect = sum(1 for r in results if r['diff'] == 0)
    expanded = sum(1 for r in results if r['diff'] > 0)
    compressed = sum(1 for r in results if r['diff'] < 0)
    print(f"Total: {len(results)}")
    print(f"Perfect Matches: {perfect}")
    print(f"Expanded (Appeared > Real): {expanded}")
    print(f"Compressed (Appeared < Real): {compressed}")

if __name__ == "__main__":
    verify_books()
