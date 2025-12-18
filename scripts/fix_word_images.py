import os
import zipfile
import io
import sys
from PIL import Image
import shutil

def convert_emf_to_png(emf_bytes):
    """
    Try to convert EMF bytes to PNG bytes using Pillow.
    """
    try:
        # Create a temporary file for the EMF data
        # Pillow on Windows handles EMF better from file path
        temp_emf = "temp_image.emf"
        temp_png = "temp_image.png"
        
        # Write bytes to temp file
        with open(temp_emf, "wb") as f:
            f.write(emf_bytes)
            
        try:
            # Try opening and saving
            with Image.open(temp_emf) as img:
                # print(f"    Image info: {img.format} {img.size} {img.mode}")
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
            print(f"    Pillow conversion failed: {e}")
            if os.path.exists(temp_emf): os.remove(temp_emf)
            if os.path.exists(temp_png): os.remove(temp_png)
            return None

    except Exception as e:
        print(f"Error converting EMF to PNG: {e}")
        return None

def process_docx(docx_path):
    print(f"Processing: {docx_path}")
    print("Version: 2.0 (Pillow Only)") # للتأكد من النسخة
    
    temp_dir = "temp_docx_extract" + str(os.getpid()) # Unique temp dir
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    
    # Debug folder for images
    debug_dir = os.path.join(os.path.dirname(docx_path), "debug_images")
    if not os.path.exists(debug_dir):
        os.makedirs(debug_dir)
        print(f"Debug images will be saved to: {debug_dir}")
    
    try:
        # 1. Extract Docx
        with zipfile.ZipFile(docx_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
            
        media_path = os.path.join(temp_dir, "word", "media")
        if not os.path.exists(media_path):
            print("No media folder found.")
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
                print(f"Found EMF image: {filename}")
                
                with open(file_path, "rb") as f:
                    emf_bytes = f.read()
                
                # Always use Pillow for conversion (Reliable)
                print(f"  -> Converting {filename} to PNG...")
                png_bytes = convert_emf_to_png(emf_bytes)
                
                if png_bytes:
                    # Overwrite the file with PNG data
                    with open(file_path, "wb") as f:
                        f.write(png_bytes)
                    print(f"  -> Replaced {filename} with PNG data.")
                    changes_made = True
                    
                    # Save debug image
                    debug_path = os.path.join(debug_dir, f"{filename}_converted.png")
                    with open(debug_path, "wb") as f:
                        f.write(png_bytes)
                    print(f"  -> Debug image saved to {debug_path}")
                    
                else:
                    print(f"  -> Failed to convert {filename}")

        # 3. Re-zip if changes made
        if changes_made:
            print("Saving changes...")
            
            with zipfile.ZipFile(docx_path, 'w', zipfile.ZIP_DEFLATED) as zip_out:
                for root, dirs, files in os.walk(temp_dir):
                    for file in files:
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, temp_dir)
                        zip_out.write(full_path, rel_path)
            print("Done!")
        else:
            print("No EMF images converted.")

    except Exception as e:
        print(f"Error processing docx: {e}")
    finally:
        if os.path.exists(temp_dir):
            try:
                shutil.rmtree(temp_dir)
            except:
                pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_word_images.py <docx_path>")
    else:
        process_docx(sys.argv[1])
