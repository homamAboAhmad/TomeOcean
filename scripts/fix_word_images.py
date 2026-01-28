import os
import zipfile
import io
import sys
from PIL import Image
import shutil
import datetime

# GLOBAL LOG FILE PATH
LOG_FILE = None

def setup_logging(docx_path):
    global LOG_FILE
    try:
        # Fallback to local log first to ensure we catch argv issues
        LOG_FILE = "debug_fixer.txt"
        
        # Initialize/Clear log
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"\n\n--- Session Start: {datetime.datetime.now()} ---\n")
            f.write(f"Raw Args: {sys.argv}\n")
            f.write(f"Target (passed): {docx_path}\n")
            f.write(f"CWD: {os.getcwd()}\n")
    except:
        pass

def safe_print(msg):
    """Log to file ONLY. No console output to avoid encoding crashes."""
    global LOG_FILE
    if LOG_FILE:
        try:
            with open(LOG_FILE, "a", encoding="utf-8") as f:
                f.write(str(msg) + "\n")
        except:
            pass

def convert_emf_to_png(emf_bytes):
    """
    Try to convert EMF bytes to PNG bytes using Pillow.
    """
    try:
        # Create a temporary file for the EMF data
        # Pillow on Windows handles EMF better from file path
        temp_emf = f"temp_image_{os.getpid()}.emf"
        temp_png = f"temp_image_{os.getpid()}.png"
        
        # Write bytes to temp file
        with open(temp_emf, "wb") as f:
            f.write(emf_bytes)
            
        try:
            # Try opening and saving
            with Image.open(temp_emf) as img:
                img.save(temp_png, "PNG")
            
            # Read back the PNG
            if os.path.exists(temp_png):
                with open(temp_png, "rb") as f:
                    png_bytes = f.read()
                
                # Cleanup
                if os.path.exists(temp_emf): os.remove(temp_emf)
                if os.path.exists(temp_png): os.remove(temp_png)
                
                return png_bytes
            
        except Exception as e:
            safe_print(f"    Pillow conversion failed: {e}")
            if os.path.exists(temp_emf): os.remove(temp_emf)
            if os.path.exists(temp_png): os.remove(temp_png)
            return None

    except Exception as e:
        safe_print(f"Error converting EMF to PNG: {e}")
        return None

def process_docx(docx_path):
    setup_logging(docx_path)
    safe_print(f"Processing: {docx_path}")
    safe_print("Version: 3.0 (File Log Mode)") 
    
    temp_dir = "temp_docx_extract" + str(os.getpid()) # Unique temp dir
    if os.path.exists(temp_dir):
        try:
            shutil.rmtree(temp_dir)
        except:
            pass
    
    try:
        # 1. Extract Docx
        with zipfile.ZipFile(docx_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
            
        media_path = os.path.join(temp_dir, "word", "media")
        if not os.path.exists(media_path):
            safe_print("No media folder found.")
            return

        changes_made = False
        
        # 2. Iterate over images
        for filename in os.listdir(media_path):
            file_path = os.path.join(media_path, filename)
            
            # Check extension or magic bytes
            is_emf = False
            if filename.lower().endswith(".emf") or filename.lower().endswith(".wmf"):
                is_emf = True
            else:
                # Check magic bytes just in case
                try:
                    with open(file_path, "rb") as f:
                        header = f.read(4)
                        if header == b'\x01\x00\x00\x00': # EMF header
                            is_emf = True
                except:
                    pass
            
            if is_emf:
                safe_print(f"Found EMF image: {filename}")
                
                with open(file_path, "rb") as f:
                    emf_bytes = f.read()
                
                # Always use Pillow for conversion (Reliable)
                safe_print(f"  -> Converting {filename} to PNG...")
                png_bytes = convert_emf_to_png(emf_bytes)
                
                if png_bytes:
                    # Overwrite the file with PNG data
                    with open(file_path, "wb") as f:
                        f.write(png_bytes)
                    safe_print(f"  -> Replaced {filename} with PNG data.")
                    changes_made = True
                else:
                    safe_print(f"  -> Failed to convert {filename}")

        # 3. Re-zip if changes made
        if changes_made:
            safe_print("Saving changes...")
            
            with zipfile.ZipFile(docx_path, 'w', zipfile.ZIP_DEFLATED) as zip_out:
                for root, dirs, files in os.walk(temp_dir):
                    for file in files:
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, temp_dir)
                        # Ensure we write valid paths inside zip
                        # Use forward slashes for zip internal paths
                        arcname = os.path.relpath(full_path, temp_dir).replace("\\", "/")
                        zip_out.write(full_path, arcname)
            safe_print("Done!")
        else:
            safe_print("No EMF images converted.")

    except Exception as e:
        safe_print(f"Error processing docx: {e}")
        import traceback
        safe_print(traceback.format_exc())
    finally:
        if os.path.exists(temp_dir):
            try:
                shutil.rmtree(temp_dir)
            except:
                pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # No args, nothing to do
        pass
    else:
        process_docx(sys.argv[1])
