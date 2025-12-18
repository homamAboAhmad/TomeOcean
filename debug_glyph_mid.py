
from fontTools.ttLib import TTFont

def inspect_glyph_names_range(font_path, start, end):
    print(f"Inspecting: {font_path}")
    font = TTFont(font_path)
    cmap = font.getBestCmap() # {code: name}
    
    for c in range(start, end+1):
        if c in cmap:
            print(f"  {hex(c)} -> {cmap[c]}")

inspect_glyph_names_range("d:/ImportantProjects/golden_shamela/assets/fonts/Tholoth Rounded.ttf", 0xF241, 0xF25A)
