
from fontTools.ttLib import TTFont

def inspect_glyph_names(font_path):
    print(f"Inspecting: {font_path}")
    try:
        font = TTFont(font_path)
    except:
        return

    cmap = font.getBestCmap() # {code: name}
    if not cmap:
        return
        
    # Check PUA range
    pua_codes = [c for c in sorted(cmap.keys()) if 0xE000 <= c <= 0xF8FF]
    
    print(f"PUA Range Sample ({len(pua_codes)} glyphs):")
    for c in pua_codes[:20]:
        print(f"  {hex(c)} -> {cmap[c]}")
        
    print("...")
inspect_glyph_names("d:/ImportantProjects/golden_shamela/assets/fonts/Tholoth Rounded.ttf")
