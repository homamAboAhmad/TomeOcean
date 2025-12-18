
import os
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables
from fontTools.ttLib.tables.otBase import OTTableReader, OTTableWriter

# Mapping logic standard for Arabic Presentation Forms-B
# Base Char: [Isolated, Initial, Medial, Final]
# We use standard unicode points.
ARABIC_FORMS = {
    0x0621: [0xFE80, None, None, None],     # HAMZA
    0x0622: [0xFE81, None, None, 0xFE82],   # ALEF WITH MADDA ABOVE
    0x0623: [0xFE83, None, None, 0xFE84],   # ALEF WITH HAMZA ABOVE
    0x0624: [0xFE85, None, None, 0xFE86],   # WAW WITH HAMZA ABOVE
    0x0625: [0xFE87, None, None, 0xFE88],   # ALEF WITH HAMZA BELOW
    0x0626: [0xFE89, 0xFE8B, 0xFE8C, 0xFE8A], # YEH WITH HAMZA ABOVE
    0x0627: [0xFE8D, None, None, 0xFE8E],   # ALEF
    0x0628: [0xFE8F, 0xFE91, 0xFE92, 0xFE90], # BEH
    0x0629: [0xFE93, None, None, 0xFE94],   # TEH MARBUTA
    0x062A: [0xFE95, 0xFE97, 0xFE98, 0xFE96], # TEH
    0x062B: [0xFE99, 0xFE9B, 0xFE9C, 0xFE9A], # THEH
    0x062C: [0xFE9D, 0xFE9F, 0xFEA0, 0xFE9E], # JEIM
    0x062D: [0xFEA1, 0xFEA3, 0xFEA4, 0xFEA2], # HAH
    0x062E: [0xFEA5, 0xFEA7, 0xFEA8, 0xFEA6], # KHAH
    0x062F: [0xFEA9, None, None, 0xFEAA],   # DAL
    0x0630: [0xFEAB, None, None, 0xFEAC],   # THAL
    0x0631: [0xFEAD, None, None, 0xFEAE],   # REH
    0x0632: [0xFEAF, None, None, 0xFEB0],   # ZAIN
    0x0633: [0xFEB1, 0xFEB3, 0xFEB4, 0xFEB2], # SEEN
    0x0634: [0xFEB5, 0xFEB7, 0xFEB8, 0xFEB6], # SHEEN
    0x0635: [0xFEB9, 0xFEBB, 0xFEBC, 0xFEBA], # SAD
    0x0636: [0xFEBD, 0xFEBF, 0xFEC0, 0xFEBE], # DAD
    0x0637: [0xFEC1, 0xFEC3, 0xFEC4, 0xFEC2], # TAH
    0x0638: [0xFEC5, 0xFEC7, 0xFEC8, 0xFEC6], # ZAH
    0x0639: [0xFEC9, 0xFECB, 0xFECC, 0xFECA], # AIN
    0x063A: [0xFECD, 0xFECF, 0xFED0, 0xFECE], # GHAIN
    0x0641: [0xFED1, 0xFED3, 0xFED4, 0xFED2], # FEH
    0x0642: [0xFED5, 0xFED7, 0xFED8, 0xFED6], # QAF
    0x0643: [0xFED9, 0xFEDB, 0xFEDC, 0xFEDA], # KAF
    0x0644: [0xFEDD, 0xFEDF, 0xFEE0, 0xFEDE], # LAM
    0x0645: [0xFEE1, 0xFEE3, 0xFEE4, 0xFEE2], # MEEM
    0x0646: [0xFEE5, 0xFEE7, 0xFEE8, 0xFEE6], # NOON
    0x0647: [0xFEE9, 0xFEEB, 0xFEEC, 0xFEEA], # HEH
    0x0648: [0xFEED, None, None, 0xFEEE],   # WAW
    0x0649: [0xFEEF, None, None, 0xFEF0],   # ALEF MAKSURA
    0x064A: [0xFEF1, 0xFEF3, 0xFEF4, 0xFEF2], # YEH
}


def fix_font(font_path):
    print(f"Processing: {font_path}")
    try:
        font = TTFont(font_path)
    except Exception as e:
        print(f"Failed to load {font_path}: {e}")
        return

    cmap = font.getBestCmap()
    if not cmap:
        print("No cmap found.")
        return

    # Check if font supports Presentation Forms B
    # We try to find glyph names for standard Unicode points
    
    # We need to build standard lookup maps:
    # isol: Base -> Isolated
    # init: Base -> Initial
    # medi: Base -> Medial
    # fina: Base -> Final
    
    isol_map = {}
    init_map = {}
    medi_map = {}
    fina_map = {}
    
    for base_code, forms in ARABIC_FORMS.items():
        base_glyph = cmap.get(base_code)
        if not base_glyph:
            continue
            
        # Forms: [Iso, Init, Medi, Fina]
        # Codes are integers
        
        # Check Isol
        if forms[0] and forms[0] in cmap:
            isol_map[base_glyph] = cmap[forms[0]]
            
        # Check Init
        if forms[1] and forms[1] in cmap:
            init_map[base_glyph] = cmap[forms[1]]
            
        # Check Medi
        if forms[2] and forms[2] in cmap:
            medi_map[base_glyph] = cmap[forms[2]]
            
        # Check Fina
        if forms[3] and forms[3] in cmap:
            fina_map[base_glyph] = cmap[forms[3]]

    if not init_map and not medi_map and not fina_map:
        print(f"Skipping {font_path}: Presentation form glyphs not found in cmap (Standard Unicode range).")
        # In a real heavy-duty script, we'd look for PUA (Private Use Area) hacks too, 
        # but for 'Legacy Windows Fonts' they typically use the FE70-FEFF range.
        return

    print(f"Found {len(init_map)} initial, {len(medi_map)} medial, {len(fina_map)} final mappings.")

    # Convert mappings to fontTools Feature Table structure involves creating a GSUB table
    # This is quite verbose with fontTools raw API. 
    # Use featLib (feature file syntax) which is easier!
    
    from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
    
    features_text = "languagesystem DFLT dflt;\nlanguagesystem arab dflt;\n\n"
    
    # Define features
    
    # feature init
    features_text += "feature init {\n"
    features_text += "  script arab;\n"
    for base, target in init_map.items():
        features_text += f"  sub {base} by {target};\n"
    features_text += "} init;\n\n"
    
    # feature medi
    features_text += "feature medi {\n"
    features_text += "  script arab;\n"
    for base, target in medi_map.items():
        features_text += f"  sub {base} by {target};\n"
    features_text += "} medi;\n\n"
    
    # feature fina
    features_text += "feature fina {\n"
    features_text += "  script arab;\n"
    for base, target in fina_map.items():
        features_text += f"  sub {base} by {target};\n"
    features_text += "} fina;\n\n"

    # feature isol (optional but good)
    features_text += "feature isol {\n"
    features_text += "  script arab;\n"
    for base, target in isol_map.items():
        features_text += f"  sub {base} by {target};\n"
    features_text += "} isol;\n\n"
    
    # Apply
    # print("Compiling features...")
    try:
        addOpenTypeFeaturesFromString(font, features_text)
    except Exception as e:
        print(f"Error compiling features: {e}")
        return

    # Save
    root, ext = os.path.splitext(font_path)
    # We overwrite the original? No, let's create a '_fixed' version first to test
    # But user won't easily see it unless we swap it.
    # Let's verify first.
    
    out_path = root + "_fixed" + ext
    print(f"Saving to {out_path}")
    font.save(out_path)
    print("Done.")

# Target files
fonts_dir = "d:/ImportantProjects/golden_shamela/assets/fonts"
targets = [
    "Tholoth Rounded.ttf",
    "AL-Qairwan.otf",
    "AGA-Arabesque.otf",
    "AGA Arabesque_old.ttf"
]

for t in targets:
    p = os.path.join(fonts_dir, t)
    if os.path.exists(p):
        fix_font(p)
    else:
        print(f"Not found: {p}")
