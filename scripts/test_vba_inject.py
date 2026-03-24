"""
test_vba_inject.py - اختبار حقن VBA مباشرة في المستند
=====================================================
يتطلب: Trust access to VBA project object model
"""
import win32com.client as win32
import os, sys, io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

VBA_CODE = """
Sub ShamelaMapFN()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim fnCount As Long
    fnCount = doc.Footnotes.Count
    If fnCount = 0 Then
        doc.CustomDocumentProperties.Add Name:="ShamelaFNResult", _
            LinkToContent:=False, Type:=msoPropertyTypeString, Value:="No footnotes"
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
        Set fn = doc.Footnotes(i)
        Set fnRange = fn.Range
        
        refPage = fn.Reference.Information(wdActiveEndPageNumber)
        currentPage = -1
        
        For Each para In fnRange.Paragraphs
            page = para.Range.Information(wdActiveEndPageNumber)
            
            If page <> currentPage Then
                Dim bmName As String
                bmName = "ShamelaFN_" & i & "_P" & page
                
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
        
        If currentPage > refPage Then
            multiPageCount = multiPageCount + 1
        End If
    Next i
    
    Dim result As String
    result = "Found " & multiPageCount & " multi-page footnotes, added " & bookmarkCount & " bookmarks"
    
    On Error Resume Next
    doc.CustomDocumentProperties("ShamelaFNResult").Delete
    On Error GoTo 0
    
    doc.CustomDocumentProperties.Add Name:="ShamelaFNResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=result
End Sub
"""

def test():
    book_path = r'C:\Users\HP\Documents\57pحوار هادئ مع الصوفية.docx'
    
    if not os.path.exists(book_path):
        print(f"ERROR: Book not found: {book_path}")
        return
    
    word = win32.DispatchEx('Word.Application')
    word.Visible = True
    word.DisplayAlerts = 0
    
    doc = None
    module = None
    
    try:
        print("Opening document...")
        doc = word.Documents.Open(book_path, ReadOnly=False, AddToRecentFiles=False)
        doc.Repaginate()
        print(f"Footnotes: {doc.Footnotes.Count}")
        print(f"Pages: {doc.ComputeStatistics(2)}")
        
        # حقن VBA مباشرة في المستند
        print("Injecting VBA code into document...")
        vb_proj = doc.VBProject
        module = vb_proj.VBComponents.Add(1)  # vbext_ct_StdModule
        module.Name = "ShamelaHelper"
        module.CodeModule.AddFromString(VBA_CODE.strip())
        print(f"Module added: {module.Name}")
        
        # تشغيل الماكرو
        print("Running macro...")
        word.Run("ShamelaHelper.ShamelaMapFN")
        print("Macro completed!")
        
        # قراءة النتيجة
        try:
            result = doc.CustomDocumentProperties("ShamelaFNResult").Value
            print(f"Result: {result}")
            doc.CustomDocumentProperties("ShamelaFNResult").Delete()
        except:
            print("No result property found")
        
        # إزالة الماكرو
        print("Cleaning up VBA module...")
        vb_proj.VBComponents.Remove(module)
        module = None
        print("VBA module removed")
        
        # حفظ مؤقت للتحقق من الـ bookmarks
        temp_path = os.path.join(os.path.dirname(book_path), '.temp_processing', '_test_vba.docx')
        os.makedirs(os.path.dirname(temp_path), exist_ok=True)
        doc.SaveAs2(temp_path)
        print(f"Saved to: {temp_path}")
        
        doc.Close(False)
        doc = None
        
        # التحقق من وجود ShamelaFN في footnotes.xml
        import zipfile
        z = zipfile.ZipFile(temp_path, 'r')
        fn_xml = z.read('word/footnotes.xml').decode('utf-8')
        doc_xml = z.read('word/document.xml').decode('utf-8')
        fn_count = fn_xml.count('ShamelaFN')
        doc_count = doc_xml.count('ShamelaFN')
        print(f"\nShamelaFN in footnotes.xml: {fn_count}")
        print(f"ShamelaFN in document.xml: {doc_count}")
        
        if fn_count > 0:
            # عرض أول bookmark
            import re
            bms = re.findall(r'w:name="(ShamelaFN_[^"]+)"', fn_xml)
            print(f"Sample bookmarks: {bms[:10]}")
        
        z.close()
        
        # تنظيف
        os.remove(temp_path)
        print("\nTest file cleaned up.")
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if module and doc:
            try:
                doc.VBProject.VBComponents.Remove(module)
            except:
                pass
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
    test()
