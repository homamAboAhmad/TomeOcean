
from fontTools.ttLib import TTFont

def inspect_cmap(font_path):
    print(f"Inspecting: {font_path}")
    try:
        font = TTFont(font_path)
    except:
        return

    cmap = font.getBestCmap()
    if not cmap:
        print("No cmap.")
        return
        
    # Collect ranges
    codes = sorted(cmap.keys())
    if not codes:
        print("Empty cmap.")
        return
        
    print(f"Total mapped glyphs: {len(codes)}")
    
    # Print standardized ranges
    # Presentation Forms A: FB50–FDFF
    # Presentation Forms B: FE70–FEFF
    # Arabic: 0600-06FF
    
    ranges = {
        "Arabic": (0x0600, 0x06FF),
        "Pres A": (0xFB50, 0xFDFF),
        "Pres B": (0xFE70, 0xFEFF),
        "PUA": (0xE000, 0xF8FF)
    }
    
    for name, (start, end) in ranges.items():
        count = sum(1 for c in codes if start <= c <= end)
        print(f"  {name} ({hex(start)}-{hex(end)}): {count} glyphs")
        
    # Check a specific sample
    # Beh Initial: U+FE91
    if 0xFE91 in cmap:
        print(f"  Has BEH Initial (U+FE91): Yes -> {cmap[0xFE91]}")
    else:
        print(f"  Has BEH Initial (U+FE91): No")
        
    # Check PUA sample
    pua_samples = [c for c in codes if 0xE000 <= c <= 0xF8FF][:5]
    if pua_samples:
        print(f"  PUA Samples: {[hex(c) for c in pua_samples]}")

fonts_dir = "d:/ImportantProjects/golden_shamela/assets/fonts"
targets = ["Tholoth Rounded.ttf", "AL-Qairwan.otf"]

for t in targets:
    import os
    p = os.path.join(fonts_dir, t)
    if os.path.exists(p):
        inspect_cmap(p)
