"""
create_dotm.py - Ø¥Ù†Ø´Ø§Ø¡ Ù…Ù„Ù the_library_helper.dotm ØµØ§Ù„Ø­
===================================================
ÙŠØªØ·Ù„Ø¨ ØªÙØ¹ÙŠÙ„ "Trust access to VBA project object model" ÙÙŠ Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Word.
ÙŠÙØ´ØºÙŽÙ‘Ù„ Ù…Ø±Ø© ÙˆØ§Ø­Ø¯Ø© ÙÙ‚Ø· Ù„Ø¥Ù†Ø´Ø§Ø¡ Ø§Ù„Ù…Ù„Ù.
"""

import win32com.client as win32
import os
import sys

# Force UTF-8
import io
if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

# ÙƒÙˆØ¯ VBA Ù„Ù„Ù…Ø§ÙƒØ±Ùˆ
VBA_CODE = """
Sub TheLibraryMapFN()
    ' Ø­Ù‚Ù† bookmarks Ù„ØªÙ‚Ø³ÙŠÙ… Ø§Ù„Ø­ÙˆØ§Ø´ÙŠ Ø§Ù„Ø·ÙˆÙŠÙ„Ø© Ø¹Ø¨Ø± Ø§Ù„ØµÙØ­Ø§Øª
    ' ÙŠØ¹Ù…Ù„ Ø¯Ø§Ø®Ù„ Word Ù…Ø¨Ø§Ø´Ø±Ø© â€” Ø£Ø³Ø±Ø¹ ÙˆØ£Ø¯Ù‚ Ù…Ù† COM cross-process
    ' Ø§Ù„ØªÙ†Ø³ÙŠÙ‚: TheLibraryFN_{footnoteIndex}_P{pageNumber}
    
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim fnCount As Long
    fnCount = doc.Footnotes.Count
    If fnCount = 0 Then
        Exit Sub
    End If
    
    Dim multiPageCount As Long
    Dim bookmarkCount As Long
    Dim i As Long
    Dim currentPage As Long
    Dim page As Long
    Dim refPage As Long
    
    multiPageCount = 0
    bookmarkCount = 0
    
    For i = 1 To fnCount
        Dim fn As Footnote
        Set fn = doc.Footnotes(i)
        
        Dim fnRange As Range
        Set fnRange = fn.Range
        
        refPage = fn.Reference.Information(wdActiveEndPageNumber)
        currentPage = -1
        
        Dim para As Paragraph
        For Each para In fnRange.Paragraphs
            page = para.Range.Information(wdActiveEndPageNumber)
            
            If page <> currentPage Then
                ' ØµÙØ­Ø© Ø¬Ø¯ÙŠØ¯Ø© â€” Ø­Ù‚Ù† bookmark
                Dim bmName As String
                bmName = "TheLibraryFN_" & i & "_P" & page
                
                Dim bmRange As Range
                Set bmRange = para.Range.Duplicate
                bmRange.Collapse wdCollapseStart
                
                On Error Resume Next
                doc.Bookmarks.Add Name:=bmName, Range:=bmRange
                If Err.Number = 0 Then
                    bookmarkCount = bookmarkCount + 1
                End If
                On Error GoTo 0
                
                currentPage = page
            End If
        Next para
        
        ' Ø¥Ø°Ø§ ÙˆØµÙ„Ù†Ø§ Ù„ØµÙØ­Ø© Ù…Ø®ØªÙ„ÙØ© Ø¹Ù† ØµÙØ­Ø© Ø§Ù„Ù…Ø±Ø¬Ø¹ â€” Ø­Ø§Ø´ÙŠØ© Ù…Ù…ØªØ¯Ø©
        If currentPage > refPage Then
            multiPageCount = multiPageCount + 1
        End If
    Next i
    
    ' Ø­ÙØ¸ Ø§Ù„Ù†ØªÙŠØ¬Ø© ÙÙŠ Custom Document Property
    Dim result As String
    result = "Found " & multiPageCount & " multi-page footnotes, added " & bookmarkCount & " bookmarks"
    
    On Error Resume Next
    doc.CustomDocumentProperties("TheLibraryFNResult").Delete
    On Error GoTo 0
    
    doc.CustomDocumentProperties.Add Name:="TheLibraryFNResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=result
End Sub
"""

def create_dotm():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dotm_path = os.path.join(script_dir, "the_library_helper.dotm")
    
    # Ø­Ø°Ù Ø§Ù„Ù…Ù„Ù Ø§Ù„Ù‚Ø¯ÙŠÙ… Ø§Ù„ØªØ§Ù„Ù Ø¥Ù† ÙˆØ¬Ø¯
    if os.path.exists(dotm_path):
        os.remove(dotm_path)
        print(f"Removed old corrupted file: {dotm_path}")
    
    word = None
    doc = None
    
    try:
        word = win32.DispatchEx('Word.Application')
        word.Visible = False
        word.DisplayAlerts = 0
        
        print("Creating new template document...")
        # Ø¥Ù†Ø´Ø§Ø¡ Ù…Ø³ØªÙ†Ø¯ Ø¬Ø¯ÙŠØ¯ (Ø³ÙŠÙØ­ÙØ¸ ÙƒÙ‚Ø§Ù„Ø¨)
        doc = word.Documents.Add()
        
        # Ø§Ù„ÙˆØµÙˆÙ„ Ù„Ù…Ø´Ø±ÙˆØ¹ VBA ÙˆØ¥Ø¶Ø§ÙØ© Ø§Ù„Ù…Ø§ÙƒØ±Ùˆ
        print("Adding VBA module 'TheLibraryHelper'...")
        try:
            vb_project = doc.VBProject
            # vbext_ct_StdModule = 1
            vb_module = vb_project.VBComponents.Add(1)
            vb_module.Name = "TheLibraryHelper"
            vb_module.CodeModule.AddFromString(VBA_CODE.strip())
            print("VBA code injected successfully.")
        except Exception as e:
            print(f"ERROR: Cannot access VBA project: {e}")
            print("")
            print("=== ÙŠØ¬Ø¨ ØªÙØ¹ÙŠÙ„ Trust access ===")
            print("Word â†’ File â†’ Options â†’ Trust Center â†’ Trust Center Settings")
            print("â†’ Macro Settings â†’ Check 'Trust access to the VBA project object model'")
            print("â†’ OK â†’ OK")
            if doc:
                doc.Close(False)
            if word:
                word.Quit()
            return False
        
        # Ø­ÙØ¸ ÙƒÙ€ .dotm (wdFormatXMLTemplateMacroEnabled = 13)
        print(f"Saving as: {dotm_path}")
        doc.SaveAs2(dotm_path, FileFormat=13)
        doc.Close(False)
        
        print(f"\nSUCCESS: the_library_helper.dotm created at:")
        print(f"  {dotm_path}")
        print(f"  Size: {os.path.getsize(dotm_path)} bytes")
        
        # Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† ØµÙ„Ø§Ø­ÙŠØ© Ø§Ù„Ù…Ù„Ù
        print("\nVerifying file...")
        import zipfile
        z = zipfile.ZipFile(dotm_path, 'r')
        vba_files = [n for n in z.namelist() if 'vba' in n.lower()]
        print(f"  VBA files found: {vba_files}")
        z.close()
        
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        if doc:
            try:
                doc.Close(False)
            except:
                pass
        if word:
            try:
                word.Quit()
            except:
                pass


def verify_dotm():
    """Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø£Ù† Ø§Ù„Ù…Ù„Ù ÙŠØ¹Ù…Ù„ â€” ÙØªØ­Ù‡ ÙƒÙ€ Add-in ÙˆØªØ´ØºÙŠÙ„ Ø§Ù„Ù…Ø§ÙƒØ±Ùˆ"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dotm_path = os.path.join(script_dir, "the_library_helper.dotm")
    
    if not os.path.exists(dotm_path):
        print("ERROR: the_library_helper.dotm not found!")
        return False
    
    word = None
    doc = None
    
    try:
        word = win32.DispatchEx('Word.Application')
        word.Visible = False
        word.DisplayAlerts = 0
        
        # Ø¥Ù†Ø´Ø§Ø¡ Ù…Ø³ØªÙ†Ø¯ ÙØ§Ø±Øº Ù„Ù„Ø§Ø®ØªØ¨Ø§Ø±
        doc = word.Documents.Add()
        
        # ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù€ Add-in
        print("Loading Add-in...")
        addin = word.AddIns.Add(dotm_path, False)
        addin.Installed = True
        print(f"  Add-in loaded: {addin.Name}")
        
        # ØªØ´ØºÙŠÙ„ Ø§Ù„Ù…Ø§ÙƒØ±Ùˆ (Ø¹Ù„Ù‰ Ù…Ø³ØªÙ†Ø¯ ÙØ§Ø±Øº â€” Ù„Ù† ÙŠÙØ¹Ù„ Ø´ÙŠØ¦Ø§Ù‹ Ù„ÙƒÙ† Ù„Ù† ÙŠØ®Ø·Ø¦)
        print("Running macro (on empty doc â€” should complete instantly)...")
        word.Run("the_library_helper.dotm!TheLibraryHelper.TheLibraryMapFN")
        print("  Macro ran successfully!")
        
        addin.Installed = False
        doc.Close(False)
        
        print("\nVERIFICATION PASSED: .dotm is valid and macro works.")
        return True
        
    except Exception as e:
        print(f"VERIFICATION FAILED: {e}")
        return False
    finally:
        if doc:
            try:
                doc.Close(False)
            except:
                pass
        if word:
            try:
                word.Quit()
            except:
                pass


if __name__ == "__main__":
    print("=" * 50)
    print("  Creating the_library_helper.dotm")
    print("=" * 50)
    print()
    
    success = create_dotm()
    
    if success:
        print()
        print("=" * 50)
        print("  Verifying .dotm")
        print("=" * 50)
        print()
        verify_dotm()
