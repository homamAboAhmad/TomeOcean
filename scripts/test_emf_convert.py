"""
سكريبت بسيط لاختبار تحويل صورة EMF إلى PNG
الاستخدام: python test_emf_convert.py image.emf
"""
import sys
import os
from PIL import Image
import io

def extract_embedded_image(emf_bytes):
    """محاولة استخراج PNG أو JPEG مضمنة داخل EMF"""
    # PNG: 89 50 4E 47
    png_idx = emf_bytes.find(b'\x89\x50\x4E\x47')
    if png_idx != -1:
        print(f"  Found PNG at offset {png_idx}")
        return emf_bytes[png_idx:], "png"
        
    # JPEG: FF D8 FF
    jpg_idx = emf_bytes.find(b'\xFF\xD8\xFF')
    if jpg_idx != -1:
        print(f"  Found JPEG at offset {jpg_idx}")
        return emf_bytes[jpg_idx:], "jpg"
        
    return None, None

def convert_with_pillow(emf_path):
    """محاولة التحويل باستخدام Pillow"""
    try:
        with Image.open(emf_path) as img:
            output_path = emf_path.replace(".emf", "_converted.png")
            img.save(output_path, "PNG")
            print(f"  Pillow conversion successful -> {output_path}")
            return True
    except Exception as e:
        print(f"  Pillow conversion failed: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_emf_convert.py <emf_file>")
        print("Example: python test_emf_convert.py image.emf")
        return
    
    emf_path = sys.argv[1]
    
    if not os.path.exists(emf_path):
        print(f"File not found: {emf_path}")
        return
    
    print(f"Testing EMF conversion for: {emf_path}")
    print(f"File size: {os.path.getsize(emf_path)} bytes")
    
    # قراءة الملف
    with open(emf_path, "rb") as f:
        emf_bytes = f.read()
    
    # طباعة أول 16 بايت
    print(f"First 16 bytes: {list(emf_bytes[:16])}")
    
    # التحقق من Header
    if emf_bytes[:4] == b'\x01\x00\x00\x00':
        print("Header: EMF (01 00 00 00)")
    elif emf_bytes[:4] == b'\xD7\xCD\xC6\x9A':
        print("Header: WMF (D7 CD C6 9A)")
    elif emf_bytes[:4] == b'\x89\x50\x4E\x47':
        print("Header: PNG! (Already a PNG file)")
        return
    elif emf_bytes[:3] == b'\xFF\xD8\xFF':
        print("Header: Looks like JPEG (FF D8 FF)")
        print(f"  4th byte: {hex(emf_bytes[3])} (standard is E0 or E1)")
        # محاولة فتحها بـ Pillow للتأكد
        print("\nTrying to open with Pillow...")
        try:
            with Image.open(emf_path) as img:
                print(f"  Format: {img.format}")
                print(f"  Size: {img.size}")
                print(f"  Mode: {img.mode}")
                output_path = emf_path.replace(".emf", "_verified.png")
                img.save(output_path, "PNG")
                print(f"  Saved as PNG -> {output_path}")
        except Exception as e:
            print(f"  Failed to open: {e}")
            print("\n  This might be corrupted or a non-standard format.")
            print("  Trying to extract embedded image anyway...")
            extracted, img_type = extract_embedded_image(emf_bytes)
            if extracted:
                output_path = emf_path.replace(".emf", f"_extracted.{img_type}")
                with open(output_path, "wb") as f:
                    f.write(extracted)
                print(f"  Extracted -> {output_path}")
        return
    else:
        print(f"Header: Unknown ({emf_bytes[:4].hex()})")
    
    # محاولة 1: استخراج صورة مضمنة
    print("\nMethod 1: Extracting embedded image...")
    extracted, img_type = extract_embedded_image(emf_bytes)
    if extracted:
        output_path = emf_path.replace(".emf", f"_extracted.{img_type}")
        with open(output_path, "wb") as f:
            f.write(extracted)
        print(f"  Extracted {img_type.upper()} -> {output_path}")
        print(f"  Extracted size: {len(extracted)} bytes")
    else:
        print("  No embedded PNG/JPEG found")
    
    # محاولة 2: تحويل باستخدام Pillow
    print("\nMethod 2: Converting with Pillow...")
    convert_with_pillow(emf_path)
    
    print("\nDone!")

if __name__ == "__main__":
    main()

