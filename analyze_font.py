from fontTools.ttLib import TTFont

font = TTFont(r'D:\ImportantProjects\golden_shamela\assets\fonts\Tholoth Rounded.ttf')
cmap = font['cmap'].getBestCmap()
codes = sorted(cmap.keys())

print("PUA range:", hex(min(codes)), "-", hex(max(codes)))
print("Offset from 0xF200:", hex(min(codes) - 0xF200))
print()

# This is a Symbol font - all chars are in PUA (U+F200-U+F2FF)
# The offset is 0xF200, meaning PUA code = ASCII code + 0xF200
# So glyph at U+F241 corresponds to ASCII 0x41 = 'A'
# Word uses a special "symbol encoding" where it maps characters
# through an internal table

# Let's see what the actual glyphs look like by checking all cmap subtables
print("=== All cmap subtables ===")
for table in font['cmap'].tables:
    print(f"  Platform: {table.platformID}, Encoding: {table.platEncID}, Format: {table.format}")
    if hasattr(table, 'cmap'):
        sample = dict(list(table.cmap.items())[:10])
        print(f"  Sample: {sample}")
        print(f"  Total entries: {len(table.cmap)}")

print()
print("=== OS/2 table ===")
os2 = font['OS/2']
print(f"  usFirstCharIndex: {hex(os2.usFirstCharIndex)}")
print(f"  usLastCharIndex: {hex(os2.usLastCharIndex)}")

# Check if there's a (1,0) cmap - Mac Roman encoding
# This is what Word uses for symbol fonts
print()
print("=== Looking for platform 1 (Mac) or platform 3 encoding 0 (Symbol) ===")
for table in font['cmap'].tables:
    if table.platformID == 3 and table.platEncID == 0:
        print("Found Windows Symbol cmap!")
        entries = sorted(table.cmap.items())
        print(f"  Range: {hex(entries[0][0])} - {hex(entries[-1][0])}")
        print(f"  Total: {len(entries)}")
        # Show Arabic-position glyphs (if mapped at ASCII positions)
        # In symbol fonts, Word maps Arabic chars to positions 0xC0-0xFF typically
        print("  Chars at 0xC0-0xFF range (where Arabic usually maps):")
        for code, glyph in entries:
            if 0xF2C0 <= code <= 0xF2FF:
                ascii_pos = code - 0xF200
                print(f"    U+{code:04X} (pos {ascii_pos}/{hex(ascii_pos)}) -> {glyph}")
    if table.platformID == 1 and table.platEncID == 0:
        print("Found Mac Roman cmap!")
        entries = sorted(table.cmap.items())
        print(f"  Range: {hex(entries[0][0])} - {hex(entries[-1][0])}")
        # Show all entries
        for code, glyph in entries:
            print(f"    {hex(code)} ({chr(code) if 32 <= code < 127 else '?'}) -> {glyph}")
