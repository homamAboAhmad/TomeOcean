"""
تشخيص wdVerticalPositionRelativeToPage لكل فقرات FN9
"""
import win32com.client as win32
import os, sys, io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

DIAG_VBA = r"""
Sub DiagVPos()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim result As String
    
    ' === FN9 ===
    Dim fn As Footnote
    Set fn = doc.Footnotes(9)
    result = "FN9: ref_page=" & fn.Reference.Information(wdActiveEndPageNumber) & ", paras=" & fn.Range.Paragraphs.Count & vbLf
    
    Dim para As Paragraph
    Dim j As Long
    Dim prevPos As Long
    Dim pageNum As Long
    Dim refPage As Long
    
    refPage = fn.Reference.Information(wdActiveEndPageNumber)
    pageNum = refPage
    prevPos = -1
    j = 0
    
    For Each para In fn.Range.Paragraphs
        Dim vPos As Long
        On Error Resume Next
        vPos = para.Range.Information(wdVerticalPositionRelativeToPage)
        On Error GoTo 0
        
        If prevPos > 0 And vPos < prevPos - 50 Then
            pageNum = pageNum + 1
            result = result & ">>> PAGE BREAK before P" & j & ": vPos dropped " & prevPos & " -> " & vPos & " (now page " & pageNum & ")" & vbLf
        End If
        
        result = result & "  P" & j & ": vPos=" & vPos & " (page " & pageNum & ")" & vbLf
        prevPos = vPos
        j = j + 1
    Next para
    
    result = result & "TOTAL pages: " & (pageNum - refPage + 1) & " (pages " & refPage & " to " & pageNum & ")" & vbLf
    
    ' === FN14 ===
    result = result & vbLf & "=== FN14 ===" & vbLf
    Set fn = doc.Footnotes(14)
    refPage = fn.Reference.Information(wdActiveEndPageNumber)
    pageNum = refPage
    prevPos = -1
    j = 0
    result = result & "FN14: ref_page=" & refPage & ", paras=" & fn.Range.Paragraphs.Count & vbLf
    
    For Each para In fn.Range.Paragraphs
        On Error Resume Next
        vPos = para.Range.Information(wdVerticalPositionRelativeToPage)
        On Error GoTo 0
        
        If prevPos > 0 And vPos < prevPos - 50 Then
            pageNum = pageNum + 1
            result = result & ">>> PAGE BREAK before P" & j & ": " & prevPos & " -> " & vPos & " (page " & pageNum & ")" & vbLf
        End If
        
        result = result & "  P" & j & ": vPos=" & vPos & " (page " & pageNum & ")" & vbLf
        prevPos = vPos
        j = j + 1
    Next para
    
    result = result & "TOTAL pages: " & (pageNum - refPage + 1) & " (pages " & refPage & " to " & pageNum & ")" & vbLf
    
    On Error Resume Next
    doc.CustomDocumentProperties("DiagResult").Delete
    On Error GoTo 0
    doc.CustomDocumentProperties.Add Name:="DiagResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=result
End Sub
"""

book_path = r'C:\Users\HP\Documents\57pحوار هادئ مع الصوفية.docx'
word = win32.DispatchEx('Word.Application')
word.Visible = True
word.DisplayAlerts = 0

doc = word.Documents.Open(book_path, ReadOnly=False, AddToRecentFiles=False)
word.ActiveWindow.View.Type = 3
doc.Repaginate()

vb_proj = doc.VBProject
mod = vb_proj.VBComponents.Add(1)
mod.Name = "DiagVP"
mod.CodeModule.AddFromString(DIAG_VBA.strip())

print("Running vertical position diagnostic on FN9 and FN14...")
word.Run("DiagVP.DiagVPos")

result = doc.CustomDocumentProperties("DiagResult").Value
print("\n" + result)

doc.CustomDocumentProperties("DiagResult").Delete()
vb_proj.VBComponents.Remove(mod)
doc.Close(False)
word.Quit()
print("Done")
